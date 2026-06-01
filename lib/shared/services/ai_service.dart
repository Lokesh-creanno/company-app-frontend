import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../../core/ai_config.dart';

// ─── Result models ────────────────────────────────────────────────────────────

class AiTaskResult {
  final String title;
  final String type;      // task | meeting | milestone | content | project
  final DateTime? date;
  final String priority;  // low | medium | high | urgent
  final String description;
  final bool isAiGenerated;

  const AiTaskResult({
    required this.title,
    this.type = 'task',
    this.date,
    this.priority = 'medium',
    this.description = '',
    this.isAiGenerated = true,
  });
}

class AiTimelineTask {
  final String title;
  final String type;
  final int daysBeforeEvent;
  final String priority;
  final String description;

  const AiTimelineTask({
    required this.title,
    required this.type,
    required this.daysBeforeEvent,
    required this.priority,
    required this.description,
  });

  DateTime dateFrom(DateTime eventDate) =>
      eventDate.subtract(Duration(days: daysBeforeEvent));
}

class AiInsight {
  final String emoji;
  final String text;
  final String? actionLabel;

  const AiInsight({
    required this.emoji,
    required this.text,
    this.actionLabel,
  });
}

class AiReceiptData {
  final String merchantName;
  final double amount;
  final String category;
  final DateTime? date;
  final String description;

  const AiReceiptData({
    required this.merchantName,
    required this.amount,
    required this.category,
    this.date,
    required this.description,
  });
}

// ─── AI Service ───────────────────────────────────────────────────────────────

class AiService {
  static GenerativeModel? _model;

  static GenerativeModel get _m {
    _model ??= GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AiConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.25,
        maxOutputTokens: 600,
      ),
    );
    return _model!;
  }

  // ── 1. Parse Natural Language → Structured Task ───────────────────────────
  /// "Client call with Aurelia Jewels next Tuesday urgent" →
  ///   {title: "Client Call — Aurelia Jewels", type: meeting, date: ..., priority: urgent}
  static Future<AiTaskResult> parseTask(String input) async {
    if (!AiConfig.isReady || input.trim().isEmpty) {
      return AiTaskResult(title: input.trim());
    }

    final today  = DateTime.now();
    final prompt = '''You are a task parser for an Indian event/marketing agency called CREANNO.
Parse this task input into structured fields: "$input"

Today: ${DateFormat('d MMMM yyyy (EEEE)').format(today)}

Respond with ONLY this JSON (no markdown, no explanation):
{"title":"concise task title max 60 chars","type":"task|meeting|milestone|content|project","date":"YYYY-MM-DD or null","priority":"low|medium|high|urgent","description":"1-2 sentence elaboration of what needs to be done"}

TYPE rules (pick ONE):
  meeting    → call/meeting/review/sync/briefing/presentation/standup
  milestone  → launch/go-live/deadline/release/submit/handoff
  content    → post/reel/caption/copy/blog/video/story/creative/design
  project    → campaign/project/initiative/phase/sprint
  task       → everything else

PRIORITY rules:
  urgent  → urgent/asap/critical/today/tonight/right now
  high    → important/priority/high/needed soon
  low     → minor/low/someday/optional
  medium  → everything else

DATE rules (calculate from today ${DateFormat('yyyy-MM-dd').format(today)}):
  "tomorrow"      → ${DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 1)))}
  "next Monday"   → calculate next occurrence of Monday
  "in 3 days"     → calculate
  no date mention → null''';

    try {
      final resp = await _m.generateContent([Content.text(prompt)]);
      final raw  = _clean(resp.text ?? '{}');
      final json = jsonDecode(raw) as Map<String, dynamic>;

      DateTime? date;
      final ds = json['date']?.toString() ?? '';
      if (ds.isNotEmpty && ds != 'null') {
        try { date = DateTime.parse(ds); } catch (_) {}
      }

      return AiTaskResult(
        title:       (json['title']?.toString() ?? input).trim(),
        type:        _validType(json['type']?.toString()),
        date:        date,
        priority:    _validPriority(json['priority']?.toString()),
        description: json['description']?.toString() ?? '',
      );
    } catch (_) {
      return AiTaskResult(title: input.trim());
    }
  }

  // ── 2. Generate Full Event Timeline ──────────────────────────────────────
  /// "Diwali Campaign" + Oct 28 → 7–8 backward timeline tasks
  static Future<List<AiTimelineTask>> generateEventTimeline(
      String eventName, DateTime eventDate) async {
    if (!AiConfig.isReady) return [];

    final prompt = '''You are a project manager at an Indian digital marketing & events agency.
Generate a backward project timeline for this event:

Event: "$eventName"
Event Date: ${DateFormat('d MMMM yyyy (EEEE)').format(eventDate)}

Return ONLY a JSON array of 7–8 tasks (no markdown):
[{"title":"short task title max 55 chars","type":"task|meeting|milestone|content","daysBeforeEvent":N,"priority":"low|medium|high|urgent","description":"what needs to be done in 1 sentence"}]

Rules:
- Spread from 28 days before down to 0 (event day)
- Must include: kickoff meeting (28d), content planning (21d), first design drafts (14d), client approval (7d), content scheduling (3d), final checks (1d), go-live milestone (0d)
- Last task MUST be: daysBeforeEvent: 0, type: "milestone", title: "🚀 [Event Name] — Go Live!"
- Make tasks realistic for Indian digital marketing/event agency
- Do NOT repeat daysBeforeEvent values''';

    try {
      final resp  = await _m.generateContent([Content.text(prompt)]);
      final raw   = _clean(resp.text ?? '[]');
      final list  = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return AiTimelineTask(
          title:           m['title']?.toString() ?? '',
          type:            _validType(m['type']?.toString()),
          daysBeforeEvent: (m['daysBeforeEvent'] as num?)?.toInt() ?? 0,
          priority:        _validPriority(m['priority']?.toString()),
          description:     m['description']?.toString() ?? '',
        );
      }).toList()
        ..sort((a, b) => b.daysBeforeEvent.compareTo(a.daysBeforeEvent));
    } catch (_) {
      return [];
    }
  }

  // ── 3. AI Dashboard Insights ──────────────────────────────────────────────
  /// Generates 3 short, specific insights shown on the dashboard
  static Future<List<AiInsight>> generateDashboardInsights({
    required String userName,
    required int tasksDueToday,
    required int tasksDueTomorrow,
    required int pendingClaims,
    required double pendingClaimsAmount,
    required int attendanceDays,
    required int workingDays,
    required int teamCompleted,
    required int teamTotal,
  }) async {
    if (!AiConfig.isReady) {
      return _fallbackInsights(userName, tasksDueToday, pendingClaims);
    }

    final atPct  = workingDays > 0 ? (attendanceDays / workingDays * 100).round() : 0;
    final cmpPct = teamTotal > 0 ? (teamCompleted / teamTotal * 100).round() : 0;
    final fmt    = NumberFormat('#,##0');
    final hour   = DateTime.now().hour;
    final period = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';
    final first  = userName.split(' ').first;

    final prompt = '''You are an AI assistant for CREANNO (Indian event/marketing agency).
Generate exactly 3 short, punchy, number-driven insights for $first.

Data:
  Tasks due today: $tasksDueToday  |  tomorrow: $tasksDueTomorrow
  Pending expense claims: $pendingClaims  |  amount: Rs.${fmt.format(pendingClaimsAmount)}
  Attendance: $attendanceDays/$workingDays days ($atPct%)
  Team task completion: $teamCompleted/$teamTotal ($cmpPct%)
  Time of day: $period

Return ONLY JSON array of 3 objects (no markdown):
[{"emoji":"one emoji","text":"max 16 words, specific and direct — include actual numbers","actionLabel":"2-3 word CTA or null"}]

Rules: No generic phrases. Each insight must reference actual data. Be motivating but honest.''';

    try {
      final resp = await _m.generateContent([Content.text(prompt)]);
      final raw  = _clean(resp.text ?? '[]');
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return AiInsight(
          emoji:       m['emoji']?.toString() ?? '✨',
          text:        m['text']?.toString() ?? '',
          actionLabel: m['actionLabel']?.toString(),
        );
      }).toList();
    } catch (_) {
      return _fallbackInsights(userName, tasksDueToday, pendingClaims);
    }
  }

  // ── 4. Suggest Tasks for a Given Day ──────────────────────────────────────
  /// Returns 4 quick task title suggestions for an empty day
  static Future<List<String>> suggestTasksForDay({
    required DateTime date,
    String? nearestEvent,
    int existingCount = 0,
  }) async {
    if (!AiConfig.isReady) return _fallbackSuggestions(date);

    final prompt = '''Suggest 4 quick task titles for an Indian digital marketing/event agency.
Day: ${DateFormat('d MMMM yyyy (EEEE)').format(date)}
${nearestEvent != null ? 'Nearby event/campaign: $nearestEvent' : ''}
Tasks already on this day: $existingCount

Return ONLY a JSON array of 4 short strings (no markdown, max 50 chars each):
["title1","title2","title3","title4"]

Base suggestions on: day of week (Mon=planning, Fri=wrap-up/claims), Indian calendar events, agency work patterns.
Avoid repeating what's already scheduled if count > 0.''';

    try {
      final resp = await _m.generateContent([Content.text(prompt)]);
      final raw  = _clean(resp.text ?? '[]');
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return _fallbackSuggestions(date);
    }
  }

  // ── 5. Parse Receipt OCR Text → Structured Expense ───────────────────────
  /// After ML Kit extracts raw text from a bill photo, AI structures it
  static Future<AiReceiptData?> parseReceiptText(String ocrText) async {
    if (!AiConfig.isReady || ocrText.trim().length < 10) return null;

    final prompt = '''Extract expense details from this bill/receipt text:
"""
$ocrText
"""

Return ONLY JSON (no markdown):
{"merchantName":"shop/vendor name max 40 chars","amount":0.0,"category":"travel|food|accommodation|fuel|medical|training|office_supplies|client_entertainment|other","date":"YYYY-MM-DD or null","description":"1 sentence what was purchased"}

Rules:
  amount   → the GRAND TOTAL / TOTAL AMOUNT as a decimal number
  category → infer: restaurant/cafe/swiggy/zomato→food | petrol/fuel/hp/bharat→fuel | hotel/oyo/makemytrip→accommodation | uber/ola/train/flight→travel | pharmacy/hospital→medical | stationery/amazon/office→office_supplies | pub/bar/lounge→client_entertainment | else→other
  date     → from bill if visible, else null
  If total not found, set amount to 0.0''';

    try {
      final resp = await _m.generateContent([Content.text(prompt)]);
      final raw  = _clean(resp.text ?? '{}');
      final json = jsonDecode(raw) as Map<String, dynamic>;

      DateTime? date;
      final ds = json['date']?.toString() ?? '';
      if (ds.isNotEmpty && ds != 'null') {
        try { date = DateTime.parse(ds); } catch (_) {}
      }

      return AiReceiptData(
        merchantName: json['merchantName']?.toString() ?? '',
        amount:       (json['amount'] as num?)?.toDouble() ?? 0.0,
        category:     _validCategory(json['category']?.toString()),
        date:         date,
        description:  json['description']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _clean(String raw) =>
      raw.replaceAll('```json', '').replaceAll('```', '').trim();

  static String _validType(String? t) {
    const v = {'task', 'meeting', 'milestone', 'content', 'project'};
    return v.contains(t) ? t! : 'task';
  }

  static String _validPriority(String? p) {
    const v = {'low', 'medium', 'high', 'urgent'};
    return v.contains(p) ? p! : 'medium';
  }

  static String _validCategory(String? c) {
    const v = {
      'travel', 'food', 'accommodation', 'fuel', 'medical',
      'training', 'office_supplies', 'client_entertainment', 'other'
    };
    return v.contains(c) ? c! : 'other';
  }

  static List<AiInsight> _fallbackInsights(
      String name, int tasksDueToday, int claims) {
    final first = name.split(' ').first;
    return [
      AiInsight(
        emoji: '📋',
        text: '$tasksDueToday task${tasksDueToday == 1 ? '' : 's'} due today — have a great session, $first!',
        actionLabel: tasksDueToday > 0 ? 'View Tasks' : null,
      ),
      if (claims > 0)
        AiInsight(
          emoji: '🧾',
          text: '$claims expense claim${claims == 1 ? '' : 's'} awaiting submission',
          actionLabel: 'Submit Now',
        ),
      AiInsight(
        emoji: '🚀',
        text: 'Keep the momentum going — check your calendar for upcoming deadlines',
      ),
    ];
  }

  // ── 6. AI Error Analysis ──────────────────────────────────────────────────
  /// Analyses a Flutter/Dart error and suggests a fix
  static Future<Map<String, String>> analyzeError(String errorMessage, String stackSummary) async {
    if (!AiConfig.isReady) {
      return {
        'cause': 'AI analysis unavailable — add your free Gemini key in ai_config.dart',
        'fix':   'Check the error message and stack trace manually for clues.',
        'severity': 'unknown',
      };
    }

    final prompt = '''You are a Flutter/Dart expert analyzing an app error for CREANNO (a Flutter company management app).

Error Message:
"$errorMessage"

Stack Summary:
${stackSummary.isEmpty ? '(No stack trace available)' : stackSummary}

Respond ONLY with this JSON (no markdown):
{
  "cause": "1-2 sentences explaining why this error occurs",
  "fix": "2-3 actionable sentences on how to fix it",
  "severity": "critical|warning|info",
  "affectedArea": "which part of the app (e.g. Claims, Auth, Dashboard, Network)"
}

Keep explanations simple — the reader is a developer but may not be a Flutter expert.''';

    try {
      final resp = await _m.generateContent([Content.text(prompt)]);
      final raw  = _clean(resp.text ?? '{}');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'cause':        json['cause']?.toString() ?? 'Unknown cause',
        'fix':          json['fix']?.toString() ?? 'Review the error message.',
        'severity':     json['severity']?.toString() ?? 'warning',
        'affectedArea': json['affectedArea']?.toString() ?? 'App',
      };
    } catch (_) {
      return {
        'cause':    'Could not analyze — AI service unavailable.',
        'fix':      'Review the stack trace manually.',
        'severity': 'warning',
      };
    }
  }

  static List<String> _fallbackSuggestions(DateTime date) {
    final wd = date.weekday;
    if (wd == DateTime.monday) {
      return ['Plan the week ahead', 'Team standup meeting', 'Review client briefs', 'Update task priorities'];
    }
    if (wd == DateTime.friday) {
      return ['Weekly wrap-up report', 'Submit expense claims', 'Next week content calendar', 'Client status update'];
    }
    if (wd == DateTime.saturday || wd == DateTime.sunday) {
      return ['Review pending approvals', 'Plan next week', 'Content idea brainstorm', 'Portfolio update'];
    }
    return ['Content creation batch', 'Client follow-up call', 'Campaign performance review', 'Design feedback round'];
  }
}
