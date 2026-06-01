import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────
class AgencyCalendarScreen extends ConsumerWidget {
  const AgencyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _CalendarAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _MonthCalendarCard(),
                _AgencyProjectsStrip(),
                _AiContentWeekPanel(),
                _UpcomingDeadlinesPanel(),
                _DayEventsPanel(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: const _AddEventFAB(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A) APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _CalendarAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(calendarProvider).selectedDay;
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: AppColors.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Agency Calendar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          DateFormat('d MMM yyyy').format(selectedDay),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plan campaigns · track deadlines · ship content',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A) MONTH CALENDAR
// ─────────────────────────────────────────────────────────────────────────────
class _MonthCalendarCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends ConsumerState<_MonthCalendarCard> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final calState = ref.watch(calendarProvider);
    final selectedDay = calState.selectedDay;
    final events = calState.events;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Header row ───────────────────────────────────────────────
            Row(
              children: [
                _IconBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_viewMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
              ],
            ),
            const SizedBox(height: 14),

            // ── Weekday headers ───────────────────────────────────────────
            Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),

            // ── Day grid ─────────────────────────────────────────────────
            _buildGrid(context, today, selectedDay, events),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    DateTime today,
    DateTime selectedDay,
    Map<DateTime, List<CalendarEvent>> events,
  ) {
    final firstDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sun=0
    final daysInMonth = DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNumber = cellIndex - firstWeekday + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 46));
            }

            final cellDate = DateTime(_viewMonth.year, _viewMonth.month, dayNumber);
            final isToday = cellDate == today;
            final isSelected = cellDate == selectedDay;
            final cellEvents = events[cellDate] ?? [];
            final eventColors = cellEvents.take(3).map((e) => e.color).toList();

            return Expanded(
              child: GestureDetector(
                onTap: () => ref.read(calendarProvider.notifier).selectDay(cellDate),
                child: _DayCell(
                  day: dayNumber,
                  isToday: isToday,
                  isSelected: isSelected,
                  eventColors: eventColors,
                  isCurrentMonth: true,
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final List<Color> eventColors;
  final bool isCurrentMonth;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.eventColors,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.all(2),
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isToday
                      ? Colors.white
                      : isSelected
                          ? AppColors.primary
                          : isCurrentMonth
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                ),
              ),
            ),
          ),
          if (eventColors.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: eventColors
                  .map(
                    (c) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B) AGENCY YEARLY PROJECTS STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _AgencyProjectsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(calendarProvider).agencyProjects;
    final selectedDay = ref.watch(calendarProvider).selectedDay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'This Year — Agency Projects',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                ),
                const Spacer(),
                Text(
                  DateFormat('yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: projects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = projects[i];
                return _ProjectPill(
                  project: p,
                  onTap: () {
                    // Add to selected day
                    final event = CalendarEvent(
                      id: 'proj_${p.id}_${selectedDay.millisecondsSinceEpoch}',
                      title: p.name,
                      type: 'project',
                      date: selectedDay,
                      color: p.color,
                      description: p.description,
                      assignee: 'All Teams',
                      priority: 'high',
                    );
                    ref.read(calendarProvider.notifier).addEvent(event);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${p.name} added to ${DateFormat('d MMM').format(selectedDay)}'),
                        backgroundColor: p.color,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPill extends StatelessWidget {
  final AgencyProject project;
  final VoidCallback onTap;
  const _ProjectPill({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: project.color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: project.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        project.month,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: project.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C) AI CONTENT WEEK PANEL
// ─────────────────────────────────────────────────────────────────────────────

// Static AI drafts per weekday
const _aiDrafts = {
  1: "Behind-the-scenes at the agency — show the creative process",
  2: "Client success story spotlight with before/after results",
  3: "Industry insight: Top 3 design trends this season",
  4: "Trending reel idea: festival/season themed content",
  5: "Team Feature Friday — introduce a team member",
  6: "Weekend creative tip for followers",
  7: "Week wrap-up + sneak peek of what's next week",
};

const _dayLabels = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

class _AiContentWeekPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AiContentWeekPanel> createState() => _AiContentWeekPanelState();
}

class _AiContentWeekPanelState extends ConsumerState<_AiContentWeekPanel> {
  int _selectedWeekday = DateTime.now().weekday; // 1=Mon … 7=Sun

  // Get Monday of current week
  DateTime _weekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _weekStart();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.accent.withOpacity(0.25), width: 1.2),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFAF8FF),
              const Color(0xFFF3EEFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '✨ AI Content Calendar — This Week',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                            letterSpacing: -0.2,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Day chips ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (i) {
                    final wd = i + 1; // 1=Mon
                    final date = weekStart.add(Duration(days: i));
                    final isSelected = _selectedWeekday == wd;
                    final isToday = date ==
                        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedWeekday = wd);
                        ref.read(calendarProvider.notifier).selectDay(date);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [AppColors.accent, AppColors.primary],
                                )
                              : null,
                          color: isSelected ? null : (isToday ? AppColors.primary.withOpacity(0.08) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : isToday
                                    ? AppColors.primary.withOpacity(0.4)
                                    : AppColors.border,
                            width: 1,
                          ),
                          boxShadow: isSelected ? AppShadows.glow(AppColors.accent, intensity: 0.2) : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayLabels[wd]!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── Draft card ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_dayLabels[_selectedWeekday]} Content Draft',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _aiDrafts[_selectedWeekday] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap a day to preview its draft',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('AI drafts refreshed!'),
                          backgroundColor: AppColors.accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppShadows.glow(AppColors.accent, intensity: 0.2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Regenerate ✨',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// D) UPCOMING DEADLINES
// ─────────────────────────────────────────────────────────────────────────────

class _DeadlineItem {
  final String project;
  final String client;
  final int daysRemaining;
  final Color color;
  const _DeadlineItem({
    required this.project,
    required this.client,
    required this.daysRemaining,
    required this.color,
  });
}

class _UpcomingDeadlinesPanel extends StatelessWidget {
  static final _deadlines = [
    _DeadlineItem(
      project: 'IPL Social Media Blitz — 20 Posts',
      client: 'SportEdge India',
      daysRemaining: 2,
      color: AppColors.error,
    ),
    _DeadlineItem(
      project: 'Summer Collection Video Ad',
      client: 'Zara India',
      daysRemaining: 5,
      color: AppColors.warning,
    ),
    _DeadlineItem(
      project: 'Brand Identity Refresh',
      client: 'GreenLeaf Organics',
      daysRemaining: 12,
      color: AppColors.success,
    ),
    _DeadlineItem(
      project: 'Q2 Performance Report Deck',
      client: 'Internal',
      daysRemaining: 18,
      color: AppColors.success,
    ),
  ];

  const _UpcomingDeadlinesPanel();

  Color _deadlineColor(int days) {
    if (days <= 3) return AppColors.error;
    if (days <= 7) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Upcoming Deadlines',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._deadlines.map((d) {
            final color = _deadlineColor(d.daysRemaining);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.card,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  children: [
                    // Colored left border
                    Container(
                      width: 5,
                      height: 62,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.project,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.business_outlined, size: 12, color: AppColors.textTertiary),
                                      const SizedBox(width: 4),
                                      Text(
                                        d.client,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: color.withOpacity(0.3), width: 1),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${d.daysRemaining}d',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    'left',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: color.withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// E) DAY EVENTS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _DayEventsPanel extends ConsumerWidget {
  const _DayEventsPanel();

  IconData _typeIcon(String type) {
    switch (type) {
      case 'meeting':
        return Icons.video_call_rounded;
      case 'milestone':
        return Icons.flag_rounded;
      case 'content':
        return Icons.article_rounded;
      case 'project':
        return Icons.folder_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.primary;
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calState = ref.watch(calendarProvider);
    final selectedDay = calState.selectedDay;
    final dayEvents = ref.read(calendarProvider.notifier).getEventsForDay(selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, d MMMM').format(selectedDay),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dayEvents.length} event${dayEvents.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (dayEvents.isEmpty) _emptyState(context),
          ...dayEvents.map((event) => _EventCard(
                event: event,
                typeIcon: _typeIcon(event.type),
                priorityColor: _priorityColor(event.priority),
              )),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded, size: 36, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),
          const Text(
            'No events today',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap + to add a task, meeting or content draft',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final IconData typeIcon;
  final Color priorityColor;

  const _EventCard({
    required this.event,
    required this.typeIcon,
    required this.priorityColor,
  });

  String get _initials {
    if (event.assignee == null || event.assignee!.isEmpty) return '?';
    final parts = event.assignee!.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return event.assignee![0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            // Type color bar
            Container(
              width: 5,
              height: 72,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            // Type icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: event.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: event.color, size: 16),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (event.isAiGenerated)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.accent, AppColors.primary],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (event.priority != null) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            event.priority!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: priorityColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: event.color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Assignee avatar
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [event.color, event.color.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// F) ADD EVENT FAB + BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddEventFAB extends ConsumerWidget {
  const _AddEventFAB();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        shape: BoxShape.circle,
        boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.35),
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddEventSheet(context, ref),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  void _showAddEventSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEventSheet(
        selectedDay: ref.read(calendarProvider).selectedDay,
        onAdd: (event) {
          ref.read(calendarProvider.notifier).addEvent(event);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Event added to calendar'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        },
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  final DateTime selectedDay;
  final void Function(CalendarEvent) onAdd;
  const _AddEventSheet({required this.selectedDay, required this.onAdd});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _titleCtrl = TextEditingController();
  String _type = 'task';
  late DateTime _date;

  static const _types = ['task', 'content', 'milestone', 'meeting'];
  static const _typeLabels = {
    'task': 'Task',
    'content': 'Content Draft',
    'milestone': 'Project Milestone',
    'meeting': 'Client Meeting',
  };
  static const _typeColors = {
    'task': AppColors.primary,
    'content': AppColors.accent,
    'milestone': AppColors.secondary,
    'meeting': AppColors.warning,
  };
  static const _typeIcons = {
    'task': Icons.task_alt_rounded,
    'content': Icons.article_rounded,
    'milestone': Icons.flag_rounded,
    'meeting': Icons.video_call_rounded,
  };

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDay;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final event = CalendarEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      type: _type,
      date: _date,
      color: _typeColors[_type]!,
    );
    widget.onAdd(event);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Add to Calendar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Event Title *',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 14),

          // Type selector
          Text(
            'Event Type',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final selected = _type == t;
              final color = _typeColors[t]!;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.12) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? color : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcons[t], size: 14, color: selected ? color : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        _typeLabels[t]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? color : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Date (pre-filled, read-only display)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add button
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.primaryGlow,
              ),
              child: const Center(
                child: Text(
                  'Add Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
