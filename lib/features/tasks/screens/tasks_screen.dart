import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/ai_service.dart';
import '../../../shared/widgets/aurora_background.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/calendar/models/calendar_event.dart';
import '../../../features/calendar/providers/calendar_provider.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';

// ─── API Tasks provider ───────────────────────────────────────────────────────
final tasksProvider = FutureProvider.autoDispose
    .family<List<dynamic>, String>((ref, status) async {
  final response = await api
      .get('/tasks/my', params: status.isNotEmpty ? {'status': status} : null);
  return response.data['data'] as List;
});

// ─── Helpers ─────────────────────────────────────────────────────────────────
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

Color _priorityColor(String? p) {
  switch (p) {
    case 'urgent': return AppColors.error;
    case 'high':   return AppColors.warning;
    case 'medium': return AppColors.primary;
    default:       return AppColors.textTertiary;
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'meeting':   return Icons.video_call_rounded;
    case 'milestone': return Icons.flag_rounded;
    case 'content':   return Icons.article_rounded;
    case 'project':   return Icons.folder_rounded;
    default:          return Icons.task_alt_rounded;
  }
}

// ─── Task filter provider (All / My Tasks) ────────────────────────────────────
final _taskFilterProvider = StateProvider<String>((ref) => 'all');

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _viewMonth;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _prevMonth() => setState(() {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
      });

  void _onDayTap(DateTime day) {
    ref.read(calendarProvider.notifier).selectDay(day);
    _slideCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final calState = ref.watch(calendarProvider);
    final selected = calState.selectedDay;
    ref.watch(authStateProvider); // ensure auth context is active

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Aurora background
          const Positioned.fill(child: AuroraBackground(intensity: 0.7)),

          // Main scroll content
          CustomScrollView(
            slivers: [
              // ── Glassmorphism App Bar ──────────────────────────────────────
              _CalendarTasksAppBar(
                viewMonth: _viewMonth,
                onPrev: _prevMonth,
                onNext: _nextMonth,
                onAiTimeline: AiConfig.aiEnabled
                    ? () => _showAiTimelineSheet(context)
                    : null,
              ),

              // ── Month Stats Bar ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _MonthStatsBar(
                  viewMonth: _viewMonth,
                  events: calState.events,
                ),
              ),

              // ── Month Calendar ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _MonthCalendarGrid(
                  viewMonth: _viewMonth,
                  selectedDay: selected,
                  events: calState.events,
                  onDayTap: _onDayTap,
                ),
              ),

              // ── Week strip (next 7 days) ───────────────────────────────────
              SliverToBoxAdapter(
                child: _WeekStrip(
                  selectedDay: selected,
                  events: calState.events,
                  onDayTap: _onDayTap,
                ),
              ),

              // ── Day tasks panel ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _DayTasksPanel(
                      selectedDay: selected,
                      events: calState.events,
                      onAddTap: () => _showAddSheet(context),
                      onSuggestionTap: (title) {
                        // Open add sheet with the suggestion pre-filled
                        final selectedDay = ref.read(calendarProvider).selectedDay;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _AddTaskSheet(
                            selectedDay: selectedDay,
                            initialTitle: title,
                            onAdd: (event) {
                              ref.read(calendarProvider.notifier).addEvent(event);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('✅  Task added to ${DateFormat("d MMM").format(event.date)}'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),

      // FAB
      floatingActionButton: _AddTaskFAB(
        onTap: () => _showAddSheet(context),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final selectedDay = ref.read(calendarProvider).selectedDay;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        selectedDay: selectedDay,
        onAdd: (event) {
          ref.read(calendarProvider.notifier).addEvent(event);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅  Task added to ${DateFormat("d MMM").format(event.date)}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
        },
      ),
    );
  }

  void _showAiTimelineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiTimelineSheet(
        onAddAll: (events) {
          for (final e in events) {
            ref.read(calendarProvider.notifier).addEvent(e);
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✨ ${events.length} AI tasks added to calendar'),
            backgroundColor: AppColors.auroraViolet,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ));
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  A) GLASS APP BAR
// ══════════════════════════════════════════════════════════════════════════════
class _CalendarTasksAppBar extends StatelessWidget {
  final DateTime viewMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onAiTimeline;

  const _CalendarTasksAppBar({
    required this.viewMonth,
    required this.onPrev,
    required this.onNext,
    this.onAiTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(colors: [
                      AppColors.auroraViolet.withOpacity(0.18),
                      AppColors.auroraIndigo.withOpacity(0.10),
                    ])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.75),
                      AppColors.lightSurfaceVar.withOpacity(0.65),
                    ]),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.09)
                      : AppColors.lightBorder.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  children: [
                    // Month prev/next
                    _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppGradients.aurora.createShader(b),
                            child: Text(
                              DateFormat('MMMM yyyy').format(viewMonth),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.calendar_month_rounded,
                                size: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Task Calendar',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
                    const SizedBox(width: 8),
                    // Today shortcut
                    GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.auroraViolet.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.auroraViolet.withOpacity(0.35),
                                  width: 1),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ✨ AI Timeline button
                    if (onAiTimeline != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onAiTimeline,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  AppColors.auroraCyan.withOpacity(0.22),
                                  AppColors.auroraViolet.withOpacity(0.22),
                                ]),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.auroraCyan.withOpacity(0.4),
                                    width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('✨', style: TextStyle(fontSize: 13)),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI',
                                    style: TextStyle(
                                      color: AppColors.auroraCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : AppColors.lightBorder.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Icon(icon,
            size: 20,
            color: isDark ? AppColors.primaryLight : AppColors.primary),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  B) MONTH STATS BAR
// ══════════════════════════════════════════════════════════════════════════════
class _MonthStatsBar extends StatelessWidget {
  final DateTime viewMonth;
  final Map<DateTime, List<CalendarEvent>> events;

  const _MonthStatsBar({required this.viewMonth, required this.events});

  @override
  Widget build(BuildContext context) {
    // Compute stats for view month
    int total = 0, tasks = 0, meetings = 0, milestones = 0;
    events.forEach((date, evs) {
      if (date.year == viewMonth.year && date.month == viewMonth.month) {
        total += evs.length;
        for (final e in evs) {
          if (e.type == 'task') tasks++;
          else if (e.type == 'meeting') meetings++;
          else if (e.type == 'milestone') milestones++;
        }
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          _StatChip(value: '$total',   label: 'Total',       color: AppColors.primary),
          const SizedBox(width: 8),
          _StatChip(value: '$tasks',      label: 'Tasks',    color: AppColors.auroraIndigo),
          const SizedBox(width: 8),
          _StatChip(value: '$meetings',   label: 'Meetings', color: AppColors.auroraCyan),
          const SizedBox(width: 8),
          _StatChip(value: '$milestones', label: 'Milestones', color: AppColors.warning),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatChip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? color.withOpacity(0.14)
                  : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25), width: 1),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  C) MONTH CALENDAR GRID
// ══════════════════════════════════════════════════════════════════════════════
class _MonthCalendarGrid extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> events;
  final void Function(DateTime) onDayTap;

  const _MonthCalendarGrid({
    required this.viewMonth,
    required this.selectedDay,
    required this.events,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today  = _dateOnly(DateTime.now());
    final firstDay = DateTime(viewMonth.year, viewMonth.month, 1);
    final startOffset = firstDay.weekday % 7; // Sun=0..Sat=6
    final daysInMonth = DateUtils.getDaysInMonth(viewMonth.year, viewMonth.month);
    final totalCells  = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: AppGlass.decoration(
              isDark: isDark,
              borderRadius: 24,
              shadows: AppGlass.violetGlow(intensity: isDark ? 0.12 : 0.07),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Weekday headers
                  Row(
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map((d) => Expanded(
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: d == 'Sun' || d == 'Sat'
                                      ? AppColors.primary.withOpacity(0.7)
                                      : isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),

                  // Day grid
                  ...List.generate(rows, (row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: List.generate(7, (col) {
                          final idx = row * 7 + col;
                          final dayNum = idx - startOffset + 1;

                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const Expanded(child: SizedBox(height: 52));
                          }

                          final cellDate = DateTime(viewMonth.year, viewMonth.month, dayNum);
                          final isToday    = cellDate == today;
                          final isSelected = cellDate == selectedDay;
                          final cellEvts   = events[cellDate] ?? [];
                          // Up to 3 priority-color dots
                          final dots = cellEvts.take(3).map((e) => e.color).toList();

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onDayTap(cellDate),
                              child: _DayCell(
                                day: dayNum,
                                isToday: isToday,
                                isSelected: isSelected,
                                dots: dots,
                                eventCount: cellEvts.length,
                                isWeekend: col == 0 || col == 6,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;
  final List<Color> dots;
  final int eventCount;
  final bool isWeekend;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.dots,
    required this.eventCount,
    required this.isWeekend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 54,
      margin: const EdgeInsets.all(1.5),
      decoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppColors.auroraViolet.withOpacity(isDark ? 0.35 : 0.18),
                  AppColors.auroraIndigo.withOpacity(isDark ? 0.25 : 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: AppColors.auroraViolet.withOpacity(0.55), width: 1.5),
              boxShadow: AppGlass.violetGlow(intensity: isDark ? 0.30 : 0.18),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day number
          Container(
            width: 30,
            height: 30,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.primary,
                    boxShadow: AppGlass.violetGlow(intensity: 0.35),
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
                          ? AppColors.primaryLight
                          : isWeekend
                              ? (isDark
                                  ? AppColors.primaryLight.withOpacity(0.6)
                                  : AppColors.primary.withOpacity(0.7))
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                ),
              ),
            ),
          ),

          // Event dots
          if (dots.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...dots.take(3).map((c) => Container(
                      width: 4.5,
                      height: 4.5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: c.withOpacity(0.5), blurRadius: 3)
                        ],
                      ),
                    )),
                if (eventCount > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+${eventCount - 3}',
                      style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary),
                    ),
                  ),
              ],
            ),
          ] else
            const SizedBox(height: 7.5),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  D) WEEK STRIP (next 7 days quick-jump)
// ══════════════════════════════════════════════════════════════════════════════
class _WeekStrip extends StatelessWidget {
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> events;
  final void Function(DateTime) onDayTap;

  const _WeekStrip({
    required this.selectedDay,
    required this.events,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _dateOnly(DateTime.now());

    // Show next 14 days
    final days = List.generate(14, (i) => today.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 10),
            child: Row(children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: AppGradients.aurora,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Upcoming — Next 2 Weeks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final day = days[i];
                final dayEvts = events[day] ?? [];
                final isSelected = day == selectedDay;
                final isToday = day == today;

                return GestureDetector(
                  onTap: () => onDayTap(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 54,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppGradients.primary
                          : null,
                      color: isSelected
                          ? null
                          : isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.white.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : isToday
                                ? AppColors.primary.withOpacity(0.5)
                                : isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : AppColors.lightBorder.withOpacity(0.6),
                        width: isToday && !isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? AppGlass.violetGlow(intensity: 0.35)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppColors.primary
                                    : isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppColors.primary
                                    : isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (dayEvts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.25)
                                  : AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${dayEvts.length}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 11),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  E) DAY TASKS PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _DayTasksPanel extends ConsumerWidget {
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarEvent>> events;
  final VoidCallback onAddTap;
  final void Function(String title)? onSuggestionTap;

  const _DayTasksPanel({
    required this.selectedDay,
    required this.events,
    required this.onAddTap,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dayEvts = events[selectedDay] ?? [];
    final isToday = selectedDay == _dateOnly(DateTime.now());
    final filter  = ref.watch(_taskFilterProvider);

    final filtered = filter == 'all'
        ? dayEvts
        : dayEvts.where((e) => e.type == filter).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppGradients.aurora.createShader(b),
                      child: Text(
                        isToday
                            ? 'Today\'s Schedule'
                            : DateFormat('EEEE, d MMMM').format(selectedDay),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dayEvts.length} item${dayEvts.length != 1 ? 's' : ''} scheduled',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Add task button
              GestureDetector(
                onTap: onAddTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppGlass.violetGlow(intensity: 0.35),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Add Task',
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
          const SizedBox(height: 12),

          // Type filter chips
          _TypeFilterChips(),
          const SizedBox(height: 14),

          // Task list
          if (filtered.isEmpty)
            _EmptyDayState(
              onAdd: onAddTap,
              date: selectedDay,
              onSuggestionTap: onSuggestionTap,
            )
          else
            ...filtered.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskEventCard(
                    event: entry.value,
                    index: entry.key,
                  ),
                )),
        ],
      ),
    );
  }
}

// ─── Type filter chips ────────────────────────────────────────────────────────
class _TypeFilterChips extends ConsumerWidget {
  static const _filters = [
    ('all', 'All', Icons.apps_rounded),
    ('task', 'Tasks', Icons.task_alt_rounded),
    ('meeting', 'Meetings', Icons.video_call_rounded),
    ('milestone', 'Milestones', Icons.flag_rounded),
    ('content', 'Content', Icons.article_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_taskFilterProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final active = current == f.$1;
          return GestureDetector(
            onTap: () => ref.read(_taskFilterProvider.notifier).state = f.$1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: active ? AppGradients.primary : null,
                color: active
                    ? null
                    : isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : isDark
                          ? Colors.white.withOpacity(0.10)
                          : AppColors.lightBorder.withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.$3,
                      size: 13,
                      color: active
                          ? Colors.white
                          : isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  const SizedBox(width: 5),
                  Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? Colors.white
                          : isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyDayState extends StatefulWidget {
  final VoidCallback onAdd;
  final DateTime date;
  final void Function(String title)? onSuggestionTap;
  const _EmptyDayState({
    required this.onAdd,
    required this.date,
    this.onSuggestionTap,
  });

  @override
  State<_EmptyDayState> createState() => _EmptyDayStateState();
}

class _EmptyDayStateState extends State<_EmptyDayState> {
  List<String> _suggestions = [];
  bool _loadingSuggestions   = false;

  @override
  void initState() {
    super.initState();
    if (AiConfig.aiEnabled) _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    final s = await AiService.suggestTasksForDay(date: widget.date);
    if (mounted) setState(() { _suggestions = s; _loadingSuggestions = false; });
  }

  // keep the old name to satisfy existing references
  VoidCallback get onAdd => widget.onAdd;
  DateTime get date => widget.date;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: AppGlass.decoration(isDark: isDark, borderRadius: 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.15),
                    AppColors.auroraCyan.withOpacity(0.08),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.auroraViolet.withOpacity(0.25), width: 1),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 36,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks on ${DateFormat("d MMM").format(date)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap below to schedule something',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: AppGradients.aurora,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppGlass.violetGlow(intensity: 0.3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Add Task or Event',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),

              // ── AI Suggestions ─────────────────────────────────────────────
              if (AiConfig.aiEnabled) ...[
                const SizedBox(height: 20),
                Row(children: [
                  Container(
                    width: 2, height: 12,
                    decoration: BoxDecoration(
                      gradient: AppGradients.aurora,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '✨ AI Suggestions',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.auroraCyan : AppColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                if (_loadingSuggestions)
                  const SizedBox(
                    height: 24,
                    child: Center(child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: AppColors.auroraCyan),
                    )),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((s) => GestureDetector(
                      onTap: () => widget.onSuggestionTap?.call(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.auroraCyan.withOpacity(isDark ? 0.18 : 0.10),
                            AppColors.auroraViolet.withOpacity(isDark ? 0.12 : 0.07),
                          ]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.auroraCyan.withOpacity(0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 11, color: AppColors.auroraCyan),
                            const SizedBox(width: 5),
                            Text(s,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Task event card ──────────────────────────────────────────────────────────
class _TaskEventCard extends StatelessWidget {
  final CalendarEvent event;
  final int index;
  const _TaskEventCard({required this.event, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pColor = event.priority != null
        ? _priorityColor(event.priority)
        : event.color;

    // Staggered reveal based on index (visual delay via opacity)
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(colors: [
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.03),
                  ])
                : LinearGradient(colors: [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.60),
                  ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.09)
                    : AppColors.lightBorder.withOpacity(0.5),
                width: 1),
            boxShadow: [
              BoxShadow(
                  color: event.color.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              // Priority / type color bar
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [event.color, event.color.withOpacity(0.5)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(18)),
                ),
              ),

              // Type icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      event.color.withOpacity(0.20),
                      event.color.withOpacity(0.08),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: event.color.withOpacity(0.25), width: 1),
                  ),
                  child: Icon(_typeIcon(event.type),
                      color: event.color, size: 18),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + AI badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (event.isAiGenerated)
                            Container(
                              margin: const EdgeInsets.only(left: 6, right: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppGradients.aurora,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('AI',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Priority dot
                          if (event.priority != null) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: pColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              event.priority!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: pColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: event.color.withOpacity(0.12),
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
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          event.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Assignee avatar + chevron
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    if (event.assignee != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [event.color, event.color.withOpacity(0.6)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: event.color.withOpacity(0.3),
                                blurRadius: 8)
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _initials(event.assignee!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  F) FAB
// ══════════════════════════════════════════════════════════════════════════════
class _AddTaskFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTaskFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.aurora,
        shape: BoxShape.circle,
        boxShadow: AppGlass.violetGlow(intensity: 0.45),
      ),
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  G) ADD TASK BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _AddTaskSheet extends StatefulWidget {
  final DateTime selectedDay;
  final void Function(CalendarEvent) onAdd;
  final String? initialTitle;
  const _AddTaskSheet({
    required this.selectedDay,
    required this.onAdd,
    this.initialTitle,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _assignCtrl = TextEditingController();
  final _aiInputCtrl = TextEditingController();
  String _type      = 'task';
  String _priority  = 'medium';
  late DateTime _date;

  // AI Create mode
  bool _aiMode    = false;
  bool _aiLoading = false;

  static const _types = [
    ('task',      'Task',       Icons.task_alt_rounded,    AppColors.primary),
    ('meeting',   'Meeting',    Icons.video_call_rounded,  AppColors.auroraCyan),
    ('milestone', 'Milestone',  Icons.flag_rounded,        AppColors.warning),
    ('content',   'Content',    Icons.article_rounded,     AppColors.accent),
  ];

  static const _priorities = [
    ('low',    'Low',    AppColors.success),
    ('medium', 'Medium', AppColors.primary),
    ('high',   'High',   AppColors.warning),
    ('urgent', 'Urgent', AppColors.error),
  ];

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDay;
    if (widget.initialTitle != null) {
      _titleCtrl.text = widget.initialTitle!;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assignCtrl.dispose();
    _aiInputCtrl.dispose();
    super.dispose();
  }

  // Apply AI result to form fields
  void _applyAiResult(AiTaskResult r) {
    setState(() {
      _titleCtrl.text = r.title;
      _descCtrl.text  = r.description;
      _type           = r.type;
      _priority       = r.priority;
      if (r.date != null) _date = r.date!;
      _aiMode         = false; // switch back to manual to review
    });
  }

  Future<void> _runAiParse() async {
    final input = _aiInputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _aiLoading = true);
    final result = await AiService.parseTask(input);
    if (mounted) {
      setState(() => _aiLoading = false);
      _applyAiResult(result);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Color get _typeColor {
    return _types.firstWhere((t) => t.$1 == _type,
        orElse: () => _types[0]).$4;
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final event = CalendarEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      type: _type,
      date: _dateOnly(_date),
      color: _typeColor,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      assignee: _assignCtrl.text.trim().isEmpty ? null : _assignCtrl.text.trim(),
      priority: _priority,
    );
    widget.onAdd(event);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(colors: [
                      AppColors.darkSurface.withOpacity(0.95),
                      AppColors.darkBg.withOpacity(0.90),
                    ])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.96),
                      AppColors.lightSurfaceVar.withOpacity(0.90),
                    ]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : AppColors.lightBorder.withOpacity(0.6),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                          color: isDark
                              ? Colors.white.withOpacity(0.18)
                              : AppColors.lightBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.aurora,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppGlass.violetGlow(intensity: 0.3),
                        ),
                        child: const Icon(Icons.add_task_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppGradients.aurora.createShader(b),
                          child: const Text('Add to Calendar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Text(
                          DateFormat('EEEE, d MMMM').format(_date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 16),

                    // ── AI / Manual Tab Toggle ─────────────────────────────
                    if (AiConfig.aiEnabled) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(children: [
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() => _aiMode = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_aiMode
                                    ? (isDark ? AppColors.darkSurface : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_aiMode ? [BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                )] : null,
                              ),
                              child: Center(child: Text('✏️  Manual',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: !_aiMode
                                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ))),
                            ),
                          )),
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() { _aiMode = true; _aiInputCtrl.clear(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: _aiMode ? LinearGradient(colors: [
                                  AppColors.auroraViolet.withOpacity(0.80),
                                  AppColors.auroraCyan.withOpacity(0.75),
                                ]) : null,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('✨  AI Create',
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: _aiMode ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ))),
                            ),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── AI Create Panel ────────────────────────────────────
                    if (_aiMode && AiConfig.aiEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.auroraViolet.withOpacity(0.08),
                            AppColors.auroraCyan.withOpacity(0.05),
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.auroraCyan.withOpacity(0.3), width: 1),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: const [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.auroraCyan),
                            SizedBox(width: 6),
                            Text('Describe your task in plain English',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.auroraCyan)),
                          ]),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _aiInputCtrl,
                            autofocus: true,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'e.g. "Client call with Aurelia Jewels next Tuesday urgent" or "Launch Diwali campaign on Oct 28"',
                              hintStyle: TextStyle(fontSize: 12,
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.auroraCyan.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.auroraCyan.withOpacity(0.6), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                              filled: true,
                              fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.7),
                            ),
                            onSubmitted: (_) => _runAiParse(),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _aiLoading ? null : _runAiParse,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ).copyWith(
                                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: AppGradients.aurora,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  child: _aiLoading
                                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                          SizedBox(width: 8),
                                          Text('Parsing with AI...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                        ])
                                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                                          SizedBox(width: 8),
                                          Text('✨ Parse & Fill Fields', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                        ]),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                    // ── Manual Fields ──────────────────────────────────────

                    // Title
                    TextField(
                      controller: _titleCtrl,
                      autofocus: widget.initialTitle == null,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Assignee
                    TextField(
                      controller: _assignCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Assignee / Team (optional)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type selector
                    _SectionLabel('Event Type'),
                    const SizedBox(height: 8),
                    Row(
                      children: _types.map((t) {
                        final sel = _type == t.$1;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _type = t.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: sel
                                    ? LinearGradient(
                                        colors: [t.$4.withOpacity(0.25), t.$4.withOpacity(0.10)],
                                      )
                                    : null,
                                color: sel
                                    ? null
                                    : isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : AppColors.lightSurfaceVar,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? t.$4 : (isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder),
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Column(children: [
                                Icon(t.$3, size: 16, color: sel ? t.$4 : AppColors.textSecondary),
                                const SizedBox(height: 4),
                                Text(
                                  t.$2,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? t.$4 : AppColors.textSecondary,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    _SectionLabel('Priority'),
                    const SizedBox(height: 8),
                    Row(
                      children: _priorities.map((p) {
                        final sel = _priority == p.$1;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _priority = p.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? p.$3.withOpacity(0.18) : (isDark ? Colors.white.withOpacity(0.05) : AppColors.lightSurfaceVar),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel ? p.$3 : (isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder),
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Column(children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.$2,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? p.$3 : AppColors.textSecondary,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Date picker
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : AppColors.lightSurfaceVar,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : AppColors.lightBorder,
                              width: 1.5),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('EEEE, d MMMM yyyy').format(_date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Submit
                    GestureDetector(
                      onTap: _submit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppGradients.aurora,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppGlass.violetGlow(intensity: 0.4),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_task_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Add to Calendar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ], // end else (manual fields)
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✨ AI TIMELINE GENERATOR SHEET
// ══════════════════════════════════════════════════════════════════════════════
class _AiTimelineSheet extends StatefulWidget {
  final void Function(List<CalendarEvent>) onAddAll;
  const _AiTimelineSheet({required this.onAddAll});

  @override
  State<_AiTimelineSheet> createState() => _AiTimelineSheetState();
}

class _AiTimelineSheetState extends State<_AiTimelineSheet> {
  final _eventNameCtrl = TextEditingController();
  DateTime _eventDate  = DateTime.now().add(const Duration(days: 14));
  bool _loading        = false;
  List<AiTimelineTask> _tasks = [];
  String? _errorMsg;

  @override
  void dispose() {
    _eventNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final name = _eventNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _loading = true; _tasks = []; _errorMsg = null; });
    try {
      final result = await AiService.generateEventTimeline(name, _eventDate);
      if (mounted) setState(() { _tasks = result; _loading = false; });
      if (result.isEmpty && mounted) {
        setState(() => _errorMsg = 'Could not generate timeline. Check your API key.');
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'Error: $e'; });
    }
  }

  void _addAll() {
    final typeColorMap = {
      'task': AppColors.primary,
      'meeting': AppColors.auroraCyan,
      'milestone': AppColors.warning,
      'content': AppColors.accent,
      'project': AppColors.auroraViolet,
    };
    final events = _tasks.map((t) {
      final date = _dateOnly(t.dateFrom(_eventDate));
      return CalendarEvent(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${t.daysBeforeEvent}',
        title: t.title,
        type: t.type,
        date: date,
        color: typeColorMap[t.type] ?? AppColors.primary,
        description: t.description,
        priority: t.priority,
        isAiGenerated: true,
      );
    }).toList();
    widget.onAddAll(events);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(colors: [
                      AppColors.darkSurface.withOpacity(0.97),
                      AppColors.darkBg.withOpacity(0.93),
                    ])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.97),
                      AppColors.lightSurfaceVar.withOpacity(0.92),
                    ]),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.auroraCyan.withOpacity(isDark ? 0.25 : 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(children: [
                    // Handle
                    Center(child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: AppGradients.aurora,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.auroraCyan.withOpacity(0.8),
                            AppColors.auroraViolet.withOpacity(0.8),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: AppColors.auroraCyan.withOpacity(0.3),
                            blurRadius: 12,
                          )],
                        ),
                        child: const Text('✨', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ShaderMask(
                          shaderCallback: (b) => AppGradients.aurora.createShader(b),
                          child: const Text('AI Event Timeline',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        Text('Auto-generate full project timeline',
                          style: TextStyle(fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      ]),
                    ]),
                    const SizedBox(height: 16),

                    // Event name input
                    TextField(
                      controller: _eventNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Event / Campaign Name *',
                        hintText: 'e.g. Diwali Campaign, Product Launch, Annual Day',
                        prefixIcon: const Icon(Icons.celebration_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onSubmitted: (_) => _generate(),
                    ),
                    const SizedBox(height: 12),

                    // Event date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _eventDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _eventDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : AppColors.lightSurfaceVar,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder),
                        ),
                        child: Row(children: [
                          const Icon(Icons.event_rounded, size: 16, color: AppColors.auroraCyan),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            'Event Date: ${DateFormat("d MMMM yyyy").format(_eventDate)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          )),
                          Icon(Icons.edit_calendar_rounded, size: 16,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppGradients.aurora,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: _loading
                                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    SizedBox(width: 10),
                                    Text('Generating Timeline...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ])
                                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Generate AI Timeline', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                  ]),
                          ),
                        ),
                      ),
                    ),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                  ]),
                ),

                // Generated tasks list
                if (_tasks.isNotEmpty) ...[
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final t = _tasks[i];
                        final taskDate = t.dateFrom(_eventDate);
                        final typeColorMap = {
                          'task': AppColors.primary,
                          'meeting': AppColors.auroraCyan,
                          'milestone': AppColors.warning,
                          'content': AppColors.accent,
                        };
                        final color = typeColorMap[t.type] ?? AppColors.primary;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withOpacity(0.2), width: 1),
                          ),
                          child: Row(children: [
                            Container(
                              width: 3, height: 46,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Text(DateFormat('d MMM').format(taskDate),
                                  style: const TextStyle(fontSize: 11, color: AppColors.auroraCyan, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(t.type.toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                                ),
                                const SizedBox(width: 6),
                                if (t.daysBeforeEvent > 0)
                                  Text('${t.daysBeforeEvent}d before',
                                    style: TextStyle(fontSize: 10,
                                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                              ]),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _priorityColor(t.priority).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(t.priority.toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                    color: _priorityColor(t.priority))),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  // Add all button
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20,
                        MediaQuery.of(context).viewInsets.bottom + 20),
                    child: GestureDetector(
                      onTap: _addAll,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: AppGradients.aurora,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppGlass.violetGlow(intensity: 0.4),
                        ),
                        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_to_photos_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Add All ${_tasks.length} Tasks to Calendar',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        ])),
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
