import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// ─── State ────────────────────────────────────────────────────────────────────
class CalendarState {
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> events;
  final List<AgencyProject> agencyProjects;

  const CalendarState({
    required this.selectedDay,
    required this.events,
    required this.agencyProjects,
  });

  CalendarState copyWith({
    DateTime? selectedDay,
    Map<DateTime, List<CalendarEvent>>? events,
    List<AgencyProject>? agencyProjects,
  }) {
    return CalendarState(
      selectedDay: selectedDay ?? this.selectedDay,
      events: events ?? this.events,
      agencyProjects: agencyProjects ?? this.agencyProjects,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(CalendarState(
          selectedDay: _dateOnly(DateTime.now()),
          events: _buildSampleEvents(),
          agencyProjects: _buildAgencyProjects(),
        ));

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: _dateOnly(day));
  }

  void addEvent(CalendarEvent event) {
    final key = _dateOnly(event.date);
    final existing = Map<DateTime, List<CalendarEvent>>.from(state.events);
    existing[key] = [...(existing[key] ?? []), event];
    state = state.copyWith(events: existing);
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return state.events[_dateOnly(day)] ?? [];
  }

  static Map<DateTime, List<CalendarEvent>> _buildSampleEvents() {
    final now = DateTime.now();
    final today = _dateOnly(now);

    // Helper: offset from today
    DateTime offset(int days) => today.add(Duration(days: days));

    final Map<DateTime, List<CalendarEvent>> events = {};

    void add(DateTime day, CalendarEvent e) {
      events[day] = [...(events[day] ?? []), e];
    }

    // ── This week tasks ────────────────────────────────────────────────────
    add(
      today,
      CalendarEvent(
        id: 'e1',
        title: 'Social Media Content Batch — Instagram',
        type: 'task',
        date: today,
        color: const Color(0xFF4F46E5),
        assignee: 'Priya S',
        priority: 'high',
        description: 'Prepare 10 posts for next week rollout',
      ),
    );
    add(
      today,
      CalendarEvent(
        id: 'e2',
        title: 'Client Call — Aurelia Jewels',
        type: 'meeting',
        date: today,
        color: const Color(0xFF06B6D4),
        assignee: 'Rahul M',
        priority: 'urgent',
        description: 'Q3 campaign review and new brief',
      ),
    );

    add(
      offset(1),
      CalendarEvent(
        id: 'e3',
        title: 'Design Review — Brand Identity Kit',
        type: 'task',
        date: offset(1),
        color: const Color(0xFF7C3AED),
        assignee: 'Ankit J',
        priority: 'medium',
      ),
    );
    add(
      offset(1),
      CalendarEvent(
        id: 'e4',
        title: 'AI Content Draft — LinkedIn Week 22',
        type: 'content',
        date: offset(1),
        color: const Color(0xFF7C3AED),
        isAiGenerated: true,
        assignee: 'Sneha K',
        description: 'Auto-generated content for approval',
      ),
    );

    add(
      offset(2),
      CalendarEvent(
        id: 'e5',
        title: 'Campaign Go-Live — Summer Collection',
        type: 'milestone',
        date: offset(2),
        color: const Color(0xFF06B6D4),
        assignee: 'Team',
        priority: 'urgent',
      ),
    );

    add(
      offset(3),
      CalendarEvent(
        id: 'e6',
        title: 'Photography Shoot — Lifestyle Brand',
        type: 'task',
        date: offset(3),
        color: const Color(0xFFD97706),
        assignee: 'Vikram T',
        priority: 'high',
      ),
    );

    add(
      offset(-1),
      CalendarEvent(
        id: 'e7',
        title: 'Monthly Report Submission',
        type: 'milestone',
        date: offset(-1),
        color: const Color(0xFF059669),
        assignee: 'Meera P',
        priority: 'medium',
      ),
    );

    add(
      offset(5),
      CalendarEvent(
        id: 'e8',
        title: 'Influencer Collab Brief — FashionForward',
        type: 'task',
        date: offset(5),
        color: const Color(0xFFE11D48),
        assignee: 'Riya S',
        priority: 'high',
      ),
    );

    // ── This month milestones ──────────────────────────────────────────────
    add(
      offset(7),
      CalendarEvent(
        id: 'e9',
        title: 'Mid-Sprint Review',
        type: 'meeting',
        date: offset(7),
        color: const Color(0xFF4F46E5),
        assignee: 'All',
        priority: 'medium',
      ),
    );

    add(
      offset(10),
      CalendarEvent(
        id: 'e10',
        title: 'Client Presentation — TechBridge Solutions',
        type: 'milestone',
        date: offset(10),
        color: const Color(0xFF7C3AED),
        assignee: 'Rahul M',
        priority: 'urgent',
      ),
    );

    add(
      offset(14),
      CalendarEvent(
        id: 'e11',
        title: 'Reel Series Launch — 10-part campaign',
        type: 'project',
        date: offset(14),
        color: const Color(0xFF06B6D4),
        assignee: 'Content Team',
        priority: 'high',
      ),
    );

    // ── October: Diwali Campaign ───────────────────────────────────────────
    final oct = DateTime(now.year, 10, 5);
    add(
      oct,
      CalendarEvent(
        id: 'e12',
        title: 'Diwali Campaign Kick-off',
        type: 'project',
        date: oct,
        color: const Color(0xFFD97706),
        assignee: 'All Teams',
        priority: 'urgent',
        description: 'Annual peak-season campaign planning begins',
      ),
    );
    add(
      DateTime(now.year, 10, 15),
      CalendarEvent(
        id: 'e13',
        title: 'Navratri Content Series — Day 1',
        type: 'content',
        date: DateTime(now.year, 10, 15),
        color: const Color(0xFFE11D48),
        assignee: 'Priya S',
        priority: 'high',
        isAiGenerated: true,
      ),
    );
    add(
      DateTime(now.year, 10, 28),
      CalendarEvent(
        id: 'e14',
        title: 'Diwali Campaign Go-Live',
        type: 'milestone',
        date: DateTime(now.year, 10, 28),
        color: const Color(0xFFD97706),
        assignee: 'All',
        priority: 'urgent',
      ),
    );

    // ── December: New Year Campaign ────────────────────────────────────────
    add(
      DateTime(now.year, 12, 10),
      CalendarEvent(
        id: 'e15',
        title: 'New Year Campaign Strategy Session',
        type: 'meeting',
        date: DateTime(now.year, 12, 10),
        color: const Color(0xFF4F46E5),
        assignee: 'Leadership',
        priority: 'high',
      ),
    );
    add(
      DateTime(now.year, 12, 20),
      CalendarEvent(
        id: 'e16',
        title: 'Christmas Campaign Go-Live',
        type: 'milestone',
        date: DateTime(now.year, 12, 20),
        color: const Color(0xFFE11D48),
        assignee: 'All',
        priority: 'urgent',
      ),
    );

    return events;
  }

  static List<AgencyProject> _buildAgencyProjects() {
    return [
      AgencyProject(
        id: 'p1',
        name: 'Republic Day Campaign',
        month: 'Jan',
        monthNumber: 1,
        color: const Color(0xFFD97706),
        description: 'Patriotic theme across all client channels',
      ),
      AgencyProject(
        id: 'p2',
        name: "Valentine's Day Campaign",
        month: 'Feb',
        monthNumber: 2,
        color: const Color(0xFFE11D48),
        description: 'Romance & gifting brand activations',
      ),
      AgencyProject(
        id: 'p3',
        name: 'Holi Campaign',
        month: 'Mar',
        monthNumber: 3,
        color: const Color(0xFF7C3AED),
        description: 'Vibrant color-themed content push',
      ),
      AgencyProject(
        id: 'p4',
        name: 'Summer Campaign + IPL',
        month: 'Apr–May',
        monthNumber: 4,
        color: const Color(0xFF06B6D4),
        description: 'Summer refresh + IPL digital activations',
      ),
      AgencyProject(
        id: 'p5',
        name: 'Mid-Year Review',
        month: 'Jun',
        monthNumber: 6,
        color: const Color(0xFF6B7280),
        description: 'H1 performance reviews & H2 planning',
      ),
      AgencyProject(
        id: 'p6',
        name: 'Independence Day Campaign',
        month: 'Aug',
        monthNumber: 8,
        color: const Color(0xFF059669),
        description: 'Patriotic pride campaigns for all clients',
      ),
      AgencyProject(
        id: 'p7',
        name: 'Ganesh Chaturthi',
        month: 'Sep',
        monthNumber: 9,
        color: const Color(0xFFD97706),
        description: 'Festival-led brand engagement',
      ),
      AgencyProject(
        id: 'p8',
        name: 'Navratri + Diwali — PEAK',
        month: 'Oct',
        monthNumber: 10,
        color: const Color(0xFFE11D48),
        description: '🎆 Peak season — all hands on deck',
      ),
      AgencyProject(
        id: 'p9',
        name: 'Post-Diwali + Brand Reviews',
        month: 'Nov',
        monthNumber: 11,
        color: const Color(0xFF4F46E5),
        description: 'Post-campaign analysis & annual planning',
      ),
      AgencyProject(
        id: 'p10',
        name: 'Christmas + New Year',
        month: 'Dec',
        monthNumber: 12,
        color: const Color(0xFFE11D48),
        description: 'Year-end campaigns & New Year countdown',
      ),
    ];
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>(
  (ref) => CalendarNotifier(),
);
