import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../../core/ai_config.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class AiAssignment {
  final String memberName;
  final String memberId;
  final String role;
  final double score;       // 0–100 match score
  final String availability; // "Available" | "Moderate" | "Overloaded"
  final String reason;
  final int currentTasks;

  const AiAssignment({
    required this.memberName,
    required this.memberId,
    required this.role,
    required this.score,
    required this.availability,
    required this.reason,
    required this.currentTasks,
  });
}

class AiScheduleBlock {
  final String startTime;   // "09:00 AM"
  final String endTime;     // "10:30 AM"
  final String title;
  final String type;        // focus | meeting | review | break | admin | planning
  final String priority;    // high | medium | low
  final String notes;
  final int durationMins;

  const AiScheduleBlock({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.type,
    required this.priority,
    required this.notes,
    required this.durationMins,
  });
}

class AiAlert {
  final String targetName;
  final String message;
  final String urgency;   // critical | warning | info
  final String category;  // task | attendance | claims | capacity | deadline
  final String emoji;
  final String? actionLabel;

  const AiAlert({
    required this.targetName,
    required this.message,
    required this.urgency,
    required this.category,
    required this.emoji,
    this.actionLabel,
  });
}

// ─── AI Scheduler Service ─────────────────────────────────────────────────────

class AiSchedulerService {
  static GenerativeModel? _model;

  static GenerativeModel get _m {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AiConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 1200,
      ),
    );
    return _model!;
  }

  static String _clean(String raw) =>
      raw.replaceAll('```json', '').replaceAll('```', '').trim();

  // ── 1. AI Task Auto-Assignment ─────────────────────────────────────────────
  /// Ranks team members by suitability for a given task
  static Future<List<AiAssignment>> suggestAssignment({
    required String taskTitle,
    required String taskType,
    required String priority,
    required String? deadline,
    required List<Map<String, dynamic>> teamMembers,
  }) async {
    if (!AiConfig.isReady || teamMembers.isEmpty) return [];

    final membersJson = teamMembers.map((m) => {
      'id':           m['id']?.toString() ?? '',
      'name':         '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim(),
      'role':         m['role']?.toString() ?? 'employee',
      'designation':  m['designation']?.toString() ?? '',
      'department':   m['department']?.toString() ?? '',
      'taskCount':    m['_taskCount'] ?? 0,
    }).toList();

    final prompt = '''You are an AI project manager for an Indian event/marketing agency (CREANNO).
Suggest the best team members to assign this task:

Task: "$taskTitle"
Type: $taskType
Priority: $priority
Deadline: ${deadline ?? 'Flexible'}

Team Members:
${jsonEncode(membersJson)}

Return ONLY a JSON array of ALL team members ranked by suitability (best first):
[{
  "id": "member id",
  "name": "member name",
  "role": "their role",
  "score": 85,
  "availability": "Available|Moderate|Overloaded",
  "reason": "Why they are best/good/ok for this — 1 sentence mentioning their role/skills",
  "currentTasks": 3
}]

Rules:
- score 80-100: excellent fit
- score 60-79: good fit
- score 40-59: possible
- score <40: not recommended
- Managers/seniors suit milestone/meeting tasks
- Content creators suit content tasks
- Junior members suit routine tasks
- Low taskCount = more available
- Return ALL members in the array''';

    try {
      final resp  = await _m.generateContent([Content.text(prompt)]);
      final raw   = _clean(resp.text ?? '[]');
      final list  = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return AiAssignment(
          memberName:   m['name']?.toString() ?? '',
          memberId:     m['id']?.toString() ?? '',
          role:         m['role']?.toString() ?? '',
          score:        (m['score'] as num?)?.toDouble() ?? 50,
          availability: m['availability']?.toString() ?? 'Available',
          reason:       m['reason']?.toString() ?? '',
          currentTasks: (m['currentTasks'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── 2. AI Daily Schedule Generation ──────────────────────────────────────
  /// Generates a time-blocked daily work plan for a team member
  static Future<List<AiScheduleBlock>> generateDailySchedule({
    required String memberName,
    required String role,
    required String designation,
    required DateTime date,
    required List<String> pendingTaskTitles,
    required int meetingCount,
    required String workStartTime, // "09:00"
  }) async {
    if (!AiConfig.isReady) return _fallbackSchedule(memberName, role, date);

    final dayName   = DateFormat('EEEE').format(date);
    final dateStr   = DateFormat('d MMMM yyyy').format(date);
    final isMonday  = date.weekday == DateTime.monday;
    final isFriday  = date.weekday == DateTime.friday;

    final tasksText = pendingTaskTitles.isEmpty
        ? 'No specific tasks listed — generate based on role'
        : pendingTaskTitles.take(8).join(', ');

    final prompt = '''You are a productivity coach for an Indian event/marketing agency (CREANNO).
Create a detailed time-blocked daily schedule for:

Team Member: $memberName
Role/Designation: $role — $designation
Day: $dayName, $dateStr
Work Start: $workStartTime AM
${isMonday ? 'Note: It is Monday — include weekly planning time' : ''}
${isFriday ? 'Note: It is Friday — include wrap-up and week review' : ''}
Pending Tasks: $tasksText
Meetings today: $meetingCount

Return ONLY a JSON array of 7-10 schedule blocks (no markdown):
[{
  "startTime": "09:00 AM",
  "endTime": "10:30 AM",
  "title": "block title",
  "type": "focus|meeting|review|break|admin|planning",
  "priority": "high|medium|low",
  "notes": "1 short sentence — what to accomplish in this block",
  "durationMins": 90
}]

Rules:
- Start at $workStartTime AM, end by 6:30 PM
- Include 1 lunch break (30 min) around 1:00 PM
- Include 2 short breaks (15 min each)
- Focus blocks: 90-120 min for deep work
- End of day: 30 min review & next-day planning
- Total schedule must be coherent and realistic for an agency professional
- Tasks should be spread across the day with high-priority items in morning''';

    try {
      final resp  = await _m.generateContent([Content.text(prompt)]);
      final raw   = _clean(resp.text ?? '[]');
      final list  = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return AiScheduleBlock(
          startTime:    m['startTime']?.toString() ?? '',
          endTime:      m['endTime']?.toString() ?? '',
          title:        m['title']?.toString() ?? '',
          type:         m['type']?.toString() ?? 'focus',
          priority:     m['priority']?.toString() ?? 'medium',
          notes:        m['notes']?.toString() ?? '',
          durationMins: (m['durationMins'] as num?)?.toInt() ?? 60,
        );
      }).toList();
    } catch (_) {
      return _fallbackSchedule(memberName, role, date);
    }
  }

  // ── 3. AI Smart Notifications / Alerts ────────────────────────────────────
  /// Generates actionable team alerts based on current state
  static Future<List<AiAlert>> generateSmartAlerts({
    required List<Map<String, dynamic>> teamMembers,
    required int totalPendingTasks,
    required int overdueTasks,
    required int pendingClaims,
    required int absentToday,
    required int teamSize,
    required List<String> upcomingDeadlines,
  }) async {
    if (!AiConfig.isReady) return _fallbackAlerts(overdueTasks, pendingClaims, absentToday);

    final names = teamMembers
        .take(8)
        .map((m) => '${m['firstName'] ?? ''} ${m['lastName'] ?? ''} (${m['designation'] ?? m['role'] ?? 'member'})')
        .join(', ');

    final deadlinesText = upcomingDeadlines.isEmpty
        ? 'None specified'
        : upcomingDeadlines.take(5).join(', ');

    final prompt = '''You are an AI operations manager for CREANNO (Indian event/marketing agency).
Generate actionable team alert notifications based on this data:

Team Members: $names
Total Team Size: $teamSize
Pending Tasks: $totalPendingTasks
Overdue Tasks: $overdueTasks
Pending Expense Claims: $pendingClaims
Absent Today: $absentToday/${teamSize}
Upcoming Deadlines: $deadlinesText
Today: ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}

Generate 5-8 specific, actionable notification alerts.
Return ONLY a JSON array (no markdown):
[{
  "targetName": "specific person name OR 'All Team' OR 'Admin'",
  "message": "specific actionable message — max 20 words, include numbers",
  "urgency": "critical|warning|info",
  "category": "task|attendance|claims|capacity|deadline|motivation",
  "emoji": "single relevant emoji",
  "actionLabel": "short 2-3 word action OR null"
}]

Rules:
- critical: overdue tasks, absent team members, urgent deadlines
- warning: capacity issues, pending claims >3 days, approaching deadlines
- info: performance positives, reminders, motivational
- Mix urgency levels — not all critical
- Be specific with numbers and names when data is available
- Include at least 1 motivational/positive alert''';

    try {
      final resp  = await _m.generateContent([Content.text(prompt)]);
      final raw   = _clean(resp.text ?? '[]');
      final list  = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return AiAlert(
          targetName:  m['targetName']?.toString() ?? 'Team',
          message:     m['message']?.toString() ?? '',
          urgency:     m['urgency']?.toString() ?? 'info',
          category:    m['category']?.toString() ?? 'task',
          emoji:       m['emoji']?.toString() ?? '📋',
          actionLabel: m['actionLabel']?.toString(),
        );
      }).toList();
    } catch (_) {
      return _fallbackAlerts(overdueTasks, pendingClaims, absentToday);
    }
  }

  // ── Fallbacks ──────────────────────────────────────────────────────────────
  static List<AiScheduleBlock> _fallbackSchedule(
      String name, String role, DateTime date) {
    return [
      const AiScheduleBlock(startTime: '09:00 AM', endTime: '09:30 AM', title: 'Morning Standup & Planning', type: 'planning', priority: 'high', notes: 'Review today\'s priorities and set goals', durationMins: 30),
      const AiScheduleBlock(startTime: '09:30 AM', endTime: '11:30 AM', title: 'Deep Focus Work — Priority Tasks', type: 'focus', priority: 'high', notes: 'Work on highest-priority pending tasks without interruption', durationMins: 120),
      const AiScheduleBlock(startTime: '11:30 AM', endTime: '12:00 PM', title: 'Emails & Communication', type: 'admin', priority: 'medium', notes: 'Reply to emails and team messages', durationMins: 30),
      const AiScheduleBlock(startTime: '12:00 PM', endTime: '12:30 PM', title: 'Lunch Break', type: 'break', priority: 'low', notes: 'Step away from desk', durationMins: 30),
      const AiScheduleBlock(startTime: '12:30 PM', endTime: '02:30 PM', title: 'Project Work', type: 'focus', priority: 'high', notes: 'Continue work on ongoing projects', durationMins: 120),
      const AiScheduleBlock(startTime: '02:30 PM', endTime: '03:00 PM', title: 'Team Check-in', type: 'meeting', priority: 'medium', notes: 'Sync with team on blockers and progress', durationMins: 30),
      const AiScheduleBlock(startTime: '03:00 PM', endTime: '05:00 PM', title: 'Deliverables & Reviews', type: 'review', priority: 'medium', notes: 'Review, polish and submit deliverables', durationMins: 120),
      const AiScheduleBlock(startTime: '05:00 PM', endTime: '05:30 PM', title: 'Day Wrap-up', type: 'admin', priority: 'low', notes: 'Update task status, plan tomorrow\'s priorities', durationMins: 30),
    ];
  }

  static List<AiAlert> _fallbackAlerts(int overdue, int claims, int absent) {
    return [
      if (overdue > 0)
        AiAlert(targetName: 'All Team', message: '$overdue tasks are overdue — review and reassign if needed', urgency: 'critical', category: 'task', emoji: '🚨', actionLabel: 'View Tasks'),
      if (claims > 0)
        AiAlert(targetName: 'Admin', message: '$claims expense claims pending approval', urgency: 'warning', category: 'claims', emoji: '🧾', actionLabel: 'Review Claims'),
      if (absent > 0)
        AiAlert(targetName: 'Admin', message: '$absent team member(s) absent today — check status', urgency: 'warning', category: 'attendance', emoji: '📍', actionLabel: 'Check Attendance'),
      const AiAlert(targetName: 'All Team', message: 'Great work this week — keep the momentum going!', urgency: 'info', category: 'motivation', emoji: '🚀'),
    ];
  }
}
