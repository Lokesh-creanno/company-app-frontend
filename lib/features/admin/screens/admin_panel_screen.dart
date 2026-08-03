import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';
import '../../../shared/services/error_log_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final adminOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final response = await api.get('/dashboard/admin');
    final raw = response.data['data'];
    if (raw is Map<String, dynamic>) {
      // API may return nested {overview: {...}} or flat {...}
      final nested = raw['overview'];
      if (nested is Map<String, dynamic>) return nested;
      return raw; // flat structure
    }
    return <String, dynamic>{};
  } catch (e) {
    // Return empty map so UI renders with defaults
    return <String, dynamic>{};
  }
});

final adminEmployeesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, search) async {
  final params = <String, dynamic>{};
  if (search.isNotEmpty) params['search'] = search;
  final response = await api.get('/employees', params: params);
  return response.data['data'] as List;
});

final adminAttendanceProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, date) async {
  final response = await api.get('/attendance/team', params: {'date': date});
  return response.data['data'] as List;
});

final adminClaimsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/reimbursements');
  return response.data['data'] as List;
});

final adminTasksProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/tasks/assigned');
  return response.data['data'] as List;
});

// ─── Admin Panel Screen ───────────────────────────────────────────────────────

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (icon: Icons.dashboard_rounded, label: 'Overview'),
    (icon: Icons.people_rounded, label: 'Team Members'),
    (icon: Icons.access_time_rounded, label: 'Attendance'),
    (icon: Icons.receipt_long_rounded, label: 'Claims'),
    (icon: Icons.task_alt_rounded, label: 'Tasks'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.hero,
              boxShadow: [BoxShadow(color: Color(0x404F46E5), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 16, isWide ? 32 : 20, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Admin Panel',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                            Text('Owner control center',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.72), fontSize: 12)),
                          ]),
                        ),
                        _RefreshButton(onTap: _refreshAll),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tab bar
                  TabBar(
                    controller: _tabCtrl,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 12),
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.55),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle:
                        const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: _tabs
                        .map((t) => Tab(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(t.icon, size: 16),
                                const SizedBox(width: 6),
                                Text(t.label),
                              ]),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _OverviewTab(isWide: isWide),
                _EmployeesTab(isWide: isWide),
                _AttendanceTab(isWide: isWide),
                _ClaimsTab(isWide: isWide),
                _TasksTab(isWide: isWide),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(adminOverviewProvider);
    ref.invalidate(adminEmployeesProvider);
    ref.invalidate(adminAttendanceProvider);
    ref.invalidate(adminClaimsProvider);
    ref.invalidate(adminTasksProvider);
  }
}

class _RefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});
  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  void _tap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _ctrl,
        child: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _tap,
          tooltip: 'Refresh all',
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerWidget {
  final bool isWide;
  const _OverviewTab({required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOverviewProvider);
    // Always show the dashboard — even if API fails, use empty defaults
    final ov = async.valueOrNull ?? {};
    return _AdminDashboard(overview: ov, isWide: isWide, isLoading: async.isLoading);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD  (replaces old _OverviewContent)
// ══════════════════════════════════════════════════════════════════════════════

class _AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> overview;
  final bool isWide;
  final bool isLoading;
  const _AdminDashboard({required this.overview, required this.isWide, required this.isLoading});

  int    _i(String k) => (overview[k] as num?)?.toInt() ?? 0;
  double _d(String k) => (overview[k] as num?)?.toDouble() ?? 0;
  String _fmt(dynamic val) {
    final a = double.tryParse(val?.toString() ?? '0') ?? 0;
    if (a >= 100000) return '${(a / 100000).toStringAsFixed(1)}L';
    if (a >= 1000)   return '${(a / 1000).toStringAsFixed(1)}K';
    return a.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad    = EdgeInsets.all(isWide ? 28.0 : 16.0);

    // Pull all values (graceful defaults if API empty)
    final totalMembers   = _i('totalEmployees');
    final presentToday   = _i('presentToday');
    final openTasks      = _i('openTasks') + _i('pendingTasks');
    final pendingClaims  = _i('pendingReimbursements');
    final completedTasks = _i('completedTasksThisMonth') + _i('completedTasks');
    final claimsAmount   = _d('reimbursementAmountThisMonth') + _d('approvedAmount');
    final absentToday    = totalMembers > 0 ? totalMembers - presentToday : 0;
    final attendancePct  = totalMembers > 0 ? (presentToday / totalMembers) : 0.0;
    final taskCompPct    = (openTasks + completedTasks) > 0
        ? (completedTasks / (openTasks + completedTasks)) : 0.0;

    return SingleChildScrollView(
      padding: pad,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Loading shimmer bar ──────────────────────────────────────────────
        if (isLoading)
          Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(AppColors.auroraCyan),
              ),
            ),
          ),

        // ── Error Monitor mini card ──────────────────────────────────────────
        _ErrorMonitorCard(isDark: isDark),
        const SizedBox(height: 20),

        // ── TODAY section ────────────────────────────────────────────────────
        _DashSection('Today at a Glance', Icons.today_rounded, isDark),
        const SizedBox(height: 12),
        _kpiGrid(isDark, isWide, [
          _KpiData('Team Size',     '$totalMembers', Icons.people_rounded,             AppColors.primary),
          _KpiData('Present',       '$presentToday', Icons.how_to_reg_rounded,         AppColors.success),
          _KpiData('Absent',        '$absentToday',  Icons.person_off_rounded,          AppColors.error),
          _KpiData('Pending Claims','$pendingClaims', Icons.receipt_long_rounded,       AppColors.warning),
        ], isDark),

        const SizedBox(height: 20),

        // ── AI Command Center banner (moved below KPIs) ──────────────────────
        if (AiConfig.aiEnabled) _AiHubBanner(),
        if (AiConfig.aiEnabled) const SizedBox(height: 20),

        // ── TASKS section ────────────────────────────────────────────────────
        _DashSection('Tasks Overview', Icons.task_alt_rounded, isDark),
        const SizedBox(height: 12),
        _GlassPanel(isDark: isDark, child: Column(children: [
          _MetricBar('Open Tasks',        openTasks,      openTasks + completedTasks, AppColors.warning, isDark),
          const SizedBox(height: 12),
          _MetricBar('Completed (Month)', completedTasks, openTasks + completedTasks, AppColors.success, isDark),
          const SizedBox(height: 12),
          _MetricBar('Attendance Rate',
            (attendancePct * 100).round(), 100, AppColors.auroraCyan, isDark,
            suffix: '%', showFraction: false),
          const SizedBox(height: 12),
          _MetricBar('Task Completion',
            (taskCompPct * 100).round(), 100, AppColors.auroraViolet, isDark,
            suffix: '%', showFraction: false),
        ])),

        const SizedBox(height: 20),

        // ── THIS MONTH highlights ────────────────────────────────────────────
        _DashSection('This Month', Icons.calendar_month_rounded, isDark),
        const SizedBox(height: 12),
        isWide
            ? Row(children: [
                Expanded(child: _HighlightCard('Tasks Done',    '$completedTasks', Icons.check_circle_rounded,  AppColors.success,  isDark)),
                const SizedBox(width: 12),
                Expanded(child: _HighlightCard('Claims Paid',   '₹${_fmt(claimsAmount)}', Icons.currency_rupee_rounded, AppColors.primary, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _HighlightCard('Active Team',   '$totalMembers', Icons.people_outline_rounded,  AppColors.accent,   isDark)),
              ])
            : Column(children: [
                _HighlightCard('Tasks Completed', '$completedTasks', Icons.check_circle_rounded, AppColors.success, isDark),
                const SizedBox(height: 10),
                _HighlightCard('Claims Approved', '₹${_fmt(claimsAmount)}', Icons.currency_rupee_rounded, AppColors.primary, isDark),
                const SizedBox(height: 10),
                _HighlightCard('Active Members', '$totalMembers', Icons.people_outline_rounded, AppColors.accent, isDark),
              ]),

        const SizedBox(height: 20),

        // ── QUICK ACTIONS ────────────────────────────────────────────────────
        _DashSection('Quick Actions', Icons.flash_on_rounded, isDark),
        const SizedBox(height: 12),
        _QuickActionsGrid(isDark: isDark, isWide: isWide),

        const SizedBox(height: 20),

        // ── PENDING APPROVALS ─────────────────────────────────────────────────
        _DashSection('Requires Attention', Icons.notification_important_rounded, isDark),
        const SizedBox(height: 12),
        _AttentionPanel(
          pendingClaims: pendingClaims,
          openTasks: openTasks,
          absentToday: absentToday,
          isDark: isDark,
        ),

        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _kpiGrid(bool isDark, bool wide, List<_KpiData> items, bool dk) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: wide ? 1.8 : 1.5,
      ),
      itemBuilder: (_, i) => _KpiCard(data: items[i], isDark: dk),
    );
  }
}

// ── KPI data model ────────────────────────────────────────────────────────────
class _KpiData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

// ── KPI glass card ────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final bool isDark;
  const _KpiCard({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)])
              : LinearGradient(colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.72)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: data.color.withOpacity(0.25), width: 1.5),
          boxShadow: [BoxShadow(color: data.color.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: Text(data.value,
              key: ValueKey(data.value),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: data.color, height: 1)),
          ),
          const SizedBox(height: 4),
          Text(data.label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        ]),
      ),
    ),
  );
}

// ── Metric progress bar ───────────────────────────────────────────────────────
class _MetricBar extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  final bool isDark;
  final String suffix;
  final bool showFraction;
  const _MetricBar(this.label, this.value, this.total, this.color, this.isDark,
      {this.suffix = '', this.showFraction = true});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
        Text(
          showFraction ? '$value / $total$suffix' : '$value$suffix',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 8,
          backgroundColor: color.withOpacity(0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

// ── Glass panel wrapper ────────────────────────────────────────────────────────
class _GlassPanel extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _GlassPanel({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)])
              : LinearGradient(colors: [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.70)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.18 : 0.05), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: child,
      ),
    ),
  );
}

// ── Highlight card (This Month) ───────────────────────────────────────────────
class _HighlightCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _HighlightCard(this.label, this.value, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [color.withOpacity(0.14), color.withOpacity(0.06)])
              : LinearGradient(colors: [Colors.white.withOpacity(0.90), color.withOpacity(0.06)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 12)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, height: 1)),
          ])),
        ]),
      ),
    ),
  );
}

// ── Dashboard section label ───────────────────────────────────────────────────
class _DashSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  const _DashSection(this.title, this.icon, this.isDark);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 3, height: 18,
      decoration: BoxDecoration(gradient: AppGradients.aurora, borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 10),
    Icon(icon, size: 16, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
    const SizedBox(width: 6),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, letterSpacing: -0.2)),
  ]);
}

// ── Quick Actions Grid ────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final bool isDark, isWide;
  const _QuickActionsGrid({required this.isDark, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (icon: Icons.person_add_rounded,       label: 'Add Member',    color: AppColors.primary,      route: '/admin'),
      (icon: Icons.task_alt_rounded,          label: 'Assign Task',   color: AppColors.auroraViolet, route: '/tasks'),
      (icon: Icons.receipt_long_rounded,      label: 'Review Claims', color: AppColors.warning,      route: '/reimbursements'),
      (icon: Icons.access_time_rounded,       label: 'Attendance',    color: AppColors.auroraCyan,   route: '/attendance'),
      (icon: Icons.auto_awesome_rounded,      label: 'AI Hub',        color: AppColors.auroraPink,   route: '/admin/ai-hub'),
      (icon: Icons.bug_report_rounded,        label: 'Error Log',     color: AppColors.error,        route: '/admin/error-console'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 6 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (ctx, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: () => context.go(a.route),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(colors: [a.color.withOpacity(0.14), a.color.withOpacity(0.06)])
                      : LinearGradient(colors: [Colors.white.withOpacity(0.90), a.color.withOpacity(0.06)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.color.withOpacity(0.25)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: a.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: a.color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(a.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Attention / Alerts Panel ──────────────────────────────────────────────────
class _AttentionPanel extends StatelessWidget {
  final int pendingClaims, openTasks, absentToday;
  final bool isDark;
  const _AttentionPanel({
    required this.pendingClaims, required this.openTasks,
    required this.absentToday, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      if (pendingClaims > 0) _AttnItem('$pendingClaims expense claim${pendingClaims == 1 ? '' : 's'} awaiting your approval', Icons.receipt_long_rounded, AppColors.warning, '/reimbursements'),
      if (openTasks > 0) _AttnItem('$openTasks open task${openTasks == 1 ? '' : 's'} in progress', Icons.task_alt_rounded, AppColors.primary, '/tasks'),
      if (absentToday > 0) _AttnItem('$absentToday team member${absentToday == 1 ? '' : 's'} absent today', Icons.person_off_rounded, AppColors.error, '/attendance'),
      if (pendingClaims == 0 && openTasks == 0 && absentToday == 0)
        _AttnItem('Everything looks good — no urgent items! 🎉', Icons.check_circle_rounded, AppColors.success, '/dashboard'),
    ];

    return _GlassPanel(isDark: isDark, child: Column(children: items.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return GestureDetector(
        onTap: () => context.go(item.route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: i < items.length - 1
                ? Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder.withOpacity(0.5)))
                : null,
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, color: item.color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(item.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
            Icon(Icons.chevron_right_rounded, size: 16,
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          ]),
        ),
      );
    }).toList()));
  }
}

class _AttnItem {
  final String label, route;
  final IconData icon;
  final Color color;
  const _AttnItem(this.label, this.icon, this.color, this.route);
}

// ── Error Monitor mini card ───────────────────────────────────────────────────
class _ErrorMonitorCard extends StatefulWidget {
  final bool isDark;
  const _ErrorMonitorCard({required this.isDark});

  @override
  State<_ErrorMonitorCard> createState() => _ErrorMonitorCardState();
}

class _ErrorMonitorCardState extends State<_ErrorMonitorCard> {
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final count = await ErrorLogService.getUnreadCount();
    if (mounted) setState(() => _errorCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final hasErrors = _errorCount > 0;
    return GestureDetector(
      onTap: () async {
        await context.push('/admin/error-console');
        _load(); // Refresh count after returning
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: hasErrors
                  ? LinearGradient(colors: [AppColors.error.withOpacity(widget.isDark ? 0.18 : 0.08), AppColors.warning.withOpacity(widget.isDark ? 0.10 : 0.05)])
                  : LinearGradient(colors: [AppColors.success.withOpacity(0.08), AppColors.success.withOpacity(0.04)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasErrors ? AppColors.error.withOpacity(0.30) : AppColors.success.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: hasErrors ? AppColors.error.withOpacity(0.14) : AppColors.success.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(hasErrors ? Icons.bug_report_rounded : Icons.shield_rounded,
                  color: hasErrors ? AppColors.error : AppColors.success, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Error Monitor',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: hasErrors ? AppColors.error : AppColors.success)),
                Text(hasErrors
                  ? '$_errorCount unread error${_errorCount == 1 ? '' : 's'} — tap to view'
                  : 'All clear — no new errors',
                  style: TextStyle(fontSize: 11,
                      color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ])),
              if (hasErrors)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('$_errorCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 12,
                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — EMPLOYEES
// ═══════════════════════════════════════════════════════════════════════════════

class _EmployeesTab extends ConsumerStatefulWidget {
  final bool isWide;
  const _EmployeesTab({required this.isWide});
  @override
  ConsumerState<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends ConsumerState<_EmployeesTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final empAsync = ref.watch(adminEmployeesProvider(_search));

    return Column(children: [
      // Search + Add bar
      Container(
        color: AppColors.surfaceOf(context),
        padding: EdgeInsets.all(widget.isWide ? 20 : 14),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, email, ID...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => _showAddEmployeeSheet(context),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(widget.isWide ? 'Add Member' : 'Add'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ]),
      ),

      Expanded(
        child: empAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(adminEmployeesProvider(_search))),
          data: (employees) {
            if (employees.isEmpty) {
              return _EmptyState(
                  icon: Icons.people_outline_rounded,
                  message: _search.isEmpty ? 'No team members yet' : 'No results found',
                  subtitle: _search.isEmpty ? 'Tap "Add Member" to add the first team member' : 'Try a different search term');
            }
            return widget.isWide
                ? _EmployeeGrid(employees: employees, onRefresh: () => ref.invalidate(adminEmployeesProvider('')))
                : _EmployeeList(employees: employees, onRefresh: () => ref.invalidate(adminEmployeesProvider('')));
          },
        ),
      ),
    ]);
  }

  void _showAddEmployeeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEmployeeSheet(onSaved: () {
        ref.invalidate(adminEmployeesProvider(''));
        setState(() { _searchCtrl.clear(); _search = ''; });
      }),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  final List<dynamic> employees;
  final VoidCallback onRefresh;
  const _EmployeeList({required this.employees, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(14),
    itemCount: employees.length,
    itemBuilder: (_, i) => _AdminEmployeeTile(emp: employees[i] as Map<String, dynamic>, onRefresh: onRefresh),
  );
}

class _EmployeeGrid extends StatelessWidget {
  final List<dynamic> employees;
  final VoidCallback onRefresh;
  const _EmployeeGrid({required this.employees, required this.onRefresh});

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: MediaQuery.of(context).size.width >= 1200 ? 4 : 3,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.1,
    ),
    itemCount: employees.length,
    itemBuilder: (_, i) => _AdminEmployeeCard(emp: employees[i] as Map<String, dynamic>, onRefresh: onRefresh),
  );
}

class _AdminEmployeeTile extends StatelessWidget {
  final Map<String, dynamic> emp;
  final VoidCallback onRefresh;
  const _AdminEmployeeTile({required this.emp, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final initials = '${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}'.toUpperCase();
    final isActive = emp['isActive'] == true;
    final roleColor = _roleColor(emp['role'] as String? ?? '');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        // Avatar
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.15)),
          child: Center(child: Text(initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${emp['firstName']} ${emp['lastName']}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimaryOf(context)))),
            if (!isActive) Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: const Text('INACTIVE', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(emp['designation'] ?? emp['department'] ?? '',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context))),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text((emp['role'] as String? ?? '').toUpperCase(),
                  style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(emp['employeeId'] ?? '',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ]),
        ])),
        // Actions
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textSecondaryOf(context), size: 20),
          onSelected: (v) => _onAction(context, v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_rounded, size: 16), SizedBox(width: 8), Text('View Details')])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
            PopupMenuItem(value: 'toggle', child: Row(children: [
              Icon(isActive ? Icons.person_off_rounded : Icons.person_rounded, size: 16),
              const SizedBox(width: 8),
              Text(isActive ? 'Deactivate' : 'Activate'),
            ])),
          ],
        ),
      ]),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppColors.error;
      case 'manager': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  void _onAction(BuildContext context, String action) {
    if (action == 'view' || action == 'edit') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EmployeeDetailSheet(emp: emp, editMode: action == 'edit', onSaved: onRefresh),
      );
    } else if (action == 'toggle') {
      _toggleActive(context);
    }
  }

  Future<void> _toggleActive(BuildContext context) async {
    final isActive = emp['isActive'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isActive ? 'Deactivate Member' : 'Activate Member'),
        content: Text(isActive
            ? 'Are you sure you want to deactivate ${emp['firstName']}? They will lose access to the app.'
            : 'Reactivate ${emp['firstName']}\'s account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: isActive ? AppColors.error : AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        if (isActive) {
          await api.delete('/employees/${emp['id']}/deactivate');
        } else {
          await api.put('/employees/${emp['id']}', data: {'isActive': true});
        }
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isActive ? 'Member deactivated' : 'Member activated'),
            backgroundColor: isActive ? AppColors.warning : AppColors.success,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }
}

class _AdminEmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final VoidCallback onRefresh;
  const _AdminEmployeeCard({required this.emp, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final initials = '${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}'.toUpperCase();
    final roleColor = emp['role'] == 'admin' ? AppColors.error : emp['role'] == 'manager' ? AppColors.warning : AppColors.primary;

    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EmployeeDetailSheet(emp: emp, editMode: false, onSaved: onRefresh),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle,
              boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.2)),
          child: Center(child: Text(initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
        ),
        const SizedBox(height: 10),
        Text('${emp['firstName']} ${emp['lastName']}',
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimaryOf(context))),
        const SizedBox(height: 3),
        Text(emp['designation'] ?? emp['department'] ?? '',
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text((emp['role'] as String? ?? '').toUpperCase(),
              style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
              color: emp['isActive'] == true ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(emp['isActive'] == true ? 'Active' : 'Inactive',
              style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        ]),
      ]),
    );
  }
}

// ─── Add Employee Bottom Sheet ────────────────────────────────────────────────

class _AddEmployeeSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddEmployeeSheet({required this.onSaved});
  @override
  ConsumerState<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<_AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deptCtrl  = TextEditingController();
  final _desgCtrl  = TextEditingController();
  String _role = 'employee';
  bool _saving = false;

  static const _roles = ['employee', 'manager', 'admin'];
  static const _departments = ['Engineering', 'Sales', 'Marketing', 'HR', 'Finance', 'Operations', 'Design', 'Support'];

  @override
  void dispose() {
    for (final c in [_firstCtrl, _lastCtrl, _emailCtrl, _phoneCtrl, _deptCtrl, _desgCtrl]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderOf(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderOf(context), width: 1)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Add New Employee',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimaryOf(context)))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _FormSection(title: 'Personal Information', children: [
                    Row(children: [
                      Expanded(child: _Field(ctrl: _firstCtrl, label: 'First Name', icon: Icons.person_rounded, required: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _Field(ctrl: _lastCtrl, label: 'Last Name', icon: Icons.person_rounded, required: true)),
                    ]),
                    const SizedBox(height: 14),
                    _Field(ctrl: _emailCtrl, label: 'Work Email', icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress, required: true,
                        validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email'),
                    const SizedBox(height: 14),
                    _Field(ctrl: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone),
                  ]),

                  const SizedBox(height: 20),
                  _FormSection(title: 'Role & Department', children: [
                    // Role picker
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryOf(context))),
                      const SizedBox(height: 8),
                      Row(children: _roles.map((r) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: r != _roles.last ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => setState(() => _role = r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: _role == r ? AppGradients.primary : null,
                                color: _role == r ? null : AppColors.surfaceVarOf(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _role == r ? AppColors.primary : AppColors.borderOf(context),
                                    width: _role == r ? 2 : 1.5),
                              ),
                              child: Text(r[0].toUpperCase() + r.substring(1),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: _role == r ? Colors.white : AppColors.textSecondaryOf(context))),
                            ),
                          ),
                        ),
                      )).toList()),
                    ]),
                    const SizedBox(height: 14),
                    // Department dropdown
                    DropdownButtonFormField<String>(
                      value: _deptCtrl.text.isEmpty ? null : _deptCtrl.text,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.business_rounded, color: Colors.white, size: 15),
                        ),
                      ),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (v) { if (v != null) _deptCtrl.text = v; },
                    ),
                    const SizedBox(height: 14),
                    _Field(ctrl: _desgCtrl, label: 'Designation / Job Title', icon: Icons.badge_rounded),
                  ]),

                  const SizedBox(height: 32),
                  GradientButton(
                    label: 'Create Employee',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await api.post('/employees', data: {
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'role': _role,
        'department': _deptCtrl.text.isEmpty ? null : _deptCtrl.text,
        'designation': _desgCtrl.text.trim().isEmpty ? null : _desgCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Team member added successfully!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Employee Detail / Edit Sheet ─────────────────────────────────────────────

class _EmployeeDetailSheet extends StatefulWidget {
  final Map<String, dynamic> emp;
  final bool editMode;
  final VoidCallback onSaved;
  const _EmployeeDetailSheet({required this.emp, required this.editMode, required this.onSaved});
  @override
  State<_EmployeeDetailSheet> createState() => _EmployeeDetailSheetState();
}

class _EmployeeDetailSheetState extends State<_EmployeeDetailSheet> {
  late bool _editing;
  late final _firstCtrl = TextEditingController(text: widget.emp['firstName'] as String? ?? '');
  late final _lastCtrl  = TextEditingController(text: widget.emp['lastName'] as String? ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.emp['phone'] as String? ?? '');
  late final _deptCtrl  = TextEditingController(text: widget.emp['department'] as String? ?? '');
  late final _desgCtrl  = TextEditingController(text: widget.emp['designation'] as String? ?? '');
  late String _role;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _editing = widget.editMode;
    _role = widget.emp['role'] as String? ?? 'employee';
  }

  @override
  void dispose() {
    for (final c in [_firstCtrl, _lastCtrl, _phoneCtrl, _deptCtrl, _desgCtrl]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final initials = '${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}'.toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderOf(context), borderRadius: BorderRadius.circular(2)))),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderOf(context)))),
            child: Row(children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
                  child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${emp['firstName']} ${emp['lastName']}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryOf(context))),
                Text(emp['employeeId'] as String? ?? '',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context))),
              ])),
              if (!_editing)
                IconButton(icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    onPressed: () => setState(() => _editing = true)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
                if (!_editing) ...[
                  _InfoRow(icon: Icons.email_rounded, label: 'Email', value: emp['email'] as String? ?? ''),
                  _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: emp['phone'] as String? ?? 'Not set'),
                  _InfoRow(icon: Icons.business_rounded, label: 'Department', value: emp['department'] as String? ?? 'Not set'),
                  _InfoRow(icon: Icons.badge_rounded, label: 'Designation', value: emp['designation'] as String? ?? 'Not set'),
                  _InfoRow(icon: Icons.shield_rounded, label: 'Role', value: (emp['role'] as String? ?? '').toUpperCase()),
                  _InfoRow(icon: Icons.calendar_today_rounded, label: 'Joined', value: emp['joiningDate'] as String? ?? 'Not set'),
                  _InfoRow(icon: Icons.circle, label: 'Status', value: emp['isActive'] == true ? 'Active' : 'Inactive'),
                ] else ...[
                  Row(children: [
                    Expanded(child: _Field(ctrl: _firstCtrl, label: 'First Name', icon: Icons.person_rounded, required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(ctrl: _lastCtrl, label: 'Last Name', icon: Icons.person_rounded, required: true)),
                  ]),
                  const SizedBox(height: 14),
                  _Field(ctrl: _phoneCtrl, label: 'Phone', icon: Icons.phone_rounded, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _Field(ctrl: _deptCtrl, label: 'Department', icon: Icons.business_rounded),
                  const SizedBox(height: 14),
                  _Field(ctrl: _desgCtrl, label: 'Designation', icon: Icons.badge_rounded),
                  const SizedBox(height: 14),
                  Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryOf(context))),
                  const SizedBox(height: 8),
                  Row(children: ['employee', 'manager', 'admin'].map((r) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: r != 'admin' ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _role = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _role == r ? AppGradients.primary : null,
                            color: _role == r ? null : AppColors.surfaceVarOf(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _role == r ? AppColors.primary : AppColors.borderOf(context), width: _role == r ? 2 : 1.5),
                          ),
                          child: Text(r[0].toUpperCase() + r.substring(1), textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: _role == r ? Colors.white : AppColors.textSecondaryOf(context))),
                        ),
                      ),
                    ),
                  )).toList()),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GradientButton(
                      label: 'Save Changes', icon: Icons.check_rounded,
                      isLoading: _saving, onPressed: _saving ? null : _save,
                    )),
                  ]),
                ],
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await api.put('/employees/${widget.emp['id']}', data: {
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'department': _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
        'designation': _desgCtrl.text.trim().isEmpty ? null : _desgCtrl.text.trim(),
        'role': _role,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Team member updated!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: AppColors.primary)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context), fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 14, color: AppColors.textPrimaryOf(context), fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — ATTENDANCE
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends ConsumerStatefulWidget {
  final bool isWide;
  const _AttendanceTab({required this.isWide});
  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _dateDisplay => DateFormat('d MMM yyyy, EEEE').format(_selectedDate);

  @override
  Widget build(BuildContext context) {
    final attAsync = ref.watch(adminAttendanceProvider(_dateStr));

    return Column(children: [
      // Date selector
      Container(
        color: AppColors.surfaceOf(context),
        padding: EdgeInsets.symmetric(horizontal: widget.isWide ? 24 : 16, vertical: 12),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(_dateDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _selectedDate.isBefore(DateTime.now())
                ? () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)))
                : null,
          ),
        ]),
      ),

      Expanded(
        child: attAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(adminAttendanceProvider(_dateStr))),
          data: (records) {
            if (records.isEmpty) {
              return _EmptyState(
                  icon: Icons.access_time_outlined,
                  message: 'No attendance records',
                  subtitle: 'No check-ins found for $_dateDisplay');
            }

            // Summary row — API returns { employee: {}, attendance: { checkInTime, status } }
            final present = records.where((r) {
              final att = r['attendance'] as Map<String, dynamic>?;
              return att?['checkInTime'] != null || att?['status'] == 'present';
            }).length;
            final absent  = records.length - present;

            return Column(children: [
              // Summary chips
              Container(
                color: AppColors.surfaceOf(context),
                padding: EdgeInsets.symmetric(horizontal: widget.isWide ? 24 : 16, vertical: 10),
                child: Row(children: [
                  _AttSummaryChip(label: 'Total', value: '${records.length}', color: AppColors.primary),
                  const SizedBox(width: 10),
                  _AttSummaryChip(label: 'Present', value: '$present', color: AppColors.success),
                  const SizedBox(width: 10),
                  _AttSummaryChip(label: 'Absent', value: '$absent', color: AppColors.error),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(widget.isWide ? 20 : 12),
                  itemCount: records.length,
                  itemBuilder: (_, i) => _AttendanceRecordTile(record: records[i] as Map<String, dynamic>),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _selectedDate = d);
  }
}

class _AttSummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttSummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _AttendanceRecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  const _AttendanceRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final emp = record['employee'] as Map<String, dynamic>? ?? record;
    final att = record['attendance'] as Map<String, dynamic>? ?? record;
    final initials = '${emp['firstName']?[0] ?? '?'}${emp['lastName']?[0] ?? ''}'.toUpperCase();
    final checkIn  = att['checkInTime'] as String?;
    final checkOut = att['checkOutTime'] as String?;
    final hours    = att['workingHours'];

    String _formatTime(String? iso) {
      if (iso == null) return '—';
      try { return DateFormat('h:mm a').format(DateTime.parse(iso).toLocal()); } catch (_) { return iso; }
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 42, height: 42,
            decoration: BoxDecoration(
                gradient: checkIn != null ? AppGradients.primary : null,
                color: checkIn == null ? AppColors.surfaceVarOf(context) : null,
                shape: BoxShape.circle),
            child: Center(child: Text(initials,
                style: TextStyle(color: checkIn != null ? Colors.white : AppColors.textTertiary,
                    fontWeight: FontWeight.w800, fontSize: 14)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimaryOf(context))),
          Text(emp['department'] as String? ?? emp['designation'] as String? ?? '',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context))),
        ])),
        if (checkIn != null) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.login_rounded, size: 13, color: AppColors.success),
              const SizedBox(width: 4),
              Text(_formatTime(checkIn), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
            ]),
            if (checkOut != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.logout_rounded, size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Text(_formatTime(checkOut), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
              ]),
            ],
            if (hours != null) ...[
              const SizedBox(height: 2),
              Text('${double.tryParse(hours.toString())?.toStringAsFixed(1) ?? hours}h',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context), fontWeight: FontWeight.w600)),
            ],
          ]),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('Absent', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — CLAIMS (Reimbursements)
// ═══════════════════════════════════════════════════════════════════════════════

class _ClaimsTab extends ConsumerStatefulWidget {
  final bool isWide;
  const _ClaimsTab({required this.isWide});
  @override
  ConsumerState<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends ConsumerState<_ClaimsTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(adminClaimsProvider);

    return Column(children: [
      // Filter chips
      Container(
        color: AppColors.surfaceOf(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: ['all', 'pending', 'approved', 'rejected'].map((f) {
            final selected = _filter == f;
            final color = f == 'pending' ? AppColors.warning
                : f == 'approved' ? AppColors.success
                : f == 'rejected' ? AppColors.error
                : AppColors.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f[0].toUpperCase() + f.substring(1),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : color)),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                backgroundColor: color.withOpacity(0.1),
                selectedColor: color,
                checkmarkColor: Colors.white,
                side: BorderSide(color: color.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            );
          }).toList()),
        ),
      ),

      Expanded(
        child: claimsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(adminClaimsProvider)),
          data: (all) {
            final claims = _filter == 'all' ? all : all.where((c) => c['status'] == _filter).toList();
            if (claims.isEmpty) {
              return _EmptyState(icon: Icons.receipt_long_outlined,
                  message: 'No ${_filter == 'all' ? '' : _filter} claims', subtitle: 'Nothing to show here');
            }
            // Summary totals
            final total = all.fold<double>(0, (s, c) => s + (double.tryParse(c['amount'].toString()) ?? 0));
            final pending = all.where((c) => c['status'] == 'pending').fold<double>(0, (s, c) => s + (double.tryParse(c['amount'].toString()) ?? 0));

            final pendingClaims = all.where((c) => c['status'] == 'pending').toList();
            return Column(children: [
              if (_filter == 'all') Container(
                color: AppColors.surfaceOf(context),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _AttSummaryChip(label: 'Total', value: '₹${_fmtAmt(total)}', color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _AttSummaryChip(label: 'Pending', value: '₹${_fmtAmt(pending)}', color: AppColors.warning)),
                  ]),
                  // Bulk Approve button (shown only when there are pending claims)
                  if (pendingClaims.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _bulkApprovePending(context, pendingClaims),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: Text('Approve All Pending (${pendingClaims.length})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(widget.isWide ? 20 : 12),
                  itemCount: claims.length,
                  itemBuilder: (_, i) => _ClaimTile(
                    claim: claims[i] as Map<String, dynamic>,
                    onRefresh: () => ref.invalidate(adminClaimsProvider),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Future<void> _bulkApprovePending(BuildContext context, List<dynamic> pending) async {
    final totalAmt = pending.fold<double>(0, (s, c) => s + (double.tryParse(c['amount'].toString()) ?? 0));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.done_all_rounded, color: AppColors.success)),
          const SizedBox(width: 12),
          const Text('Approve All Pending'),
        ]),
        content: Text(
            'Approve ${pending.length} pending claim(s) totalling '
            '₹${NumberFormat('#,##0.00').format(totalAmt)}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve All (${pending.length})'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Approve all concurrently
    int succeeded = 0;
    await Future.wait(pending.map((c) async {
      try {
        await api.patch('/reimbursements/${c['id']}/status', data: {'status': 'approved'});
        succeeded++;
      } catch (_) {}
    }));

    ref.invalidate(adminClaimsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $succeeded of ${pending.length} claims approved!'),
        backgroundColor: AppColors.success,
      ));
    }
  }
}

class _ClaimTile extends StatefulWidget {
  final Map<String, dynamic> claim;
  final VoidCallback onRefresh;
  const _ClaimTile({required this.claim, required this.onRefresh});
  @override
  State<_ClaimTile> createState() => _ClaimTileState();
}

class _ClaimTileState extends State<_ClaimTile> {
  bool _loading = false;

  String _formatDate(String? d) {
    if (d == null) return '';
    try { return DateFormat('d MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  // Short 8-char reference from UUID
  String _claimRef(String? id) => (id ?? '').length >= 8
      ? 'CR-${id!.substring(0, 8).toUpperCase()}'
      : 'CR-????';

  Future<void> _approve() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        final c = widget.claim;
        final emp = c['employee'] as Map<String, dynamic>? ?? {};
        final amount = double.tryParse(c['amount']?.toString() ?? '0') ?? 0;
        return AlertDialog(
          title: const Text('Approve Claim'),
          content: Text(
              'Approve ₹${amount.toStringAsFixed(2)} claim by '
              '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}?\n\n'
              'Ref: ${_claimRef(c['id'] as String?)}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    await _updateStatus('approved', reason: null);
  }

  Future<void> _rejectWithReason() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Provide a reason for rejection (optional):',
              style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Missing receipts, duplicate submission...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null) return; // cancelled
    await _updateStatus('rejected', reason: reason);
  }

  Future<void> _updateStatus(String status, {String? reason}) async {
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{'status': status};
      if (reason != null && reason.isNotEmpty) data['rejectionReason'] = reason;
      await api.patch('/reimbursements/${widget.claim['id']}/status', data: data);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? '✅ Claim approved!' : 'Claim rejected.'),
          backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    final emp = c['employee'] as Map<String, dynamic>? ?? {};
    final status = c['status'] as String? ?? 'pending';
    final amount = double.tryParse(c['amount']?.toString() ?? '0') ?? 0;
    final statusColor = status == 'approved' || status == 'paid' ? AppColors.success
        : status == 'rejected' ? AppColors.error : AppColors.warning;

    return AppCard(
      onTap: () => context.go('/reimbursements/${c['id']}', extra: c),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header row: employee + amount ──────────────────────────────────
        Row(children: [
          // Employee avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
            child: Center(child: Text(
              '${emp['firstName']?[0] ?? '?'}${emp['lastName']?[0] ?? ''}'.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimaryOf(context))),
            Row(children: [
              if ((emp['employeeId'] as String? ?? '').isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(emp['employeeId'] as String,
                      style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                (c['category'] as String? ?? 'general').replaceAll('_', ' '),
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context)),
              ),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${NumberFormat('#,##0.00').format(amount)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryOf(context))),
            Text(_formatDate(c['expenseDate'] as String? ?? c['createdAt'] as String?),
                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ]),
        ]),

        // ── Claim title ────────────────────────────────────────────────────
        if ((c['title'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(c['title'] as String,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],

        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),

        // ── Footer row: Ref ID + status + actions ──────────────────────────
        Row(children: [
          // Claim Ref ID
          Text(_claimRef(c['id'] as String?),
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary,
                  fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(7),
            ),
            child: Text(status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),

          // View details arrow
          if (status != 'pending')
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),

          // Action buttons — pending only
          if (status == 'pending') ...[
            if (_loading)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              OutlinedButton.icon(
                onPressed: _rejectWithReason,
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Reject', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _approve,
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text('Approve', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 5 — TASKS
// ═══════════════════════════════════════════════════════════════════════════════

class _TasksTab extends ConsumerStatefulWidget {
  final bool isWide;
  const _TasksTab({required this.isWide});
  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(adminTasksProvider);

    return Column(children: [
      // Filter
      Container(
        color: AppColors.surfaceOf(context),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: ['all', 'pending', 'in_progress', 'completed', 'overdue'].map((f) {
            final selected = _filter == f;
            final color = f == 'completed' ? AppColors.success
                : f == 'overdue' ? AppColors.error
                : f == 'in_progress' ? AppColors.primary
                : f == 'pending' ? AppColors.warning
                : AppColors.accent;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : color)),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                backgroundColor: color.withOpacity(0.1),
                selectedColor: color,
                checkmarkColor: Colors.white,
                side: BorderSide(color: color.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            );
          }).toList()),
        ),
      ),

      Expanded(
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(adminTasksProvider)),
          data: (all) {
            final tasks = _filter == 'all' ? all : all.where((t) => t['status'] == _filter).toList();
            if (tasks.isEmpty) {
              return _EmptyState(icon: Icons.task_outlined,
                  message: 'No tasks', subtitle: 'No ${_filter == 'all' ? '' : _filter.replaceAll('_', ' ')} tasks found');
            }
            // Build ID list for prev/next navigation in detail screen
            final taskIds = tasks.map((t) => (t as Map)['id'] as String).toList();
            return ListView.builder(
              padding: EdgeInsets.all(widget.isWide ? 20 : 12),
              itemCount: tasks.length,
              itemBuilder: (_, i) => _AdminTaskTile(
                task: tasks[i] as Map<String, dynamic>,
                allIds: taskIds,
                index: i,
                onRefresh: () => ref.invalidate(adminTasksProvider),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _AdminTaskTile extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<String> allIds;
  final int index;
  final VoidCallback onRefresh;

  const _AdminTaskTile({
    required this.task,
    required this.allIds,
    required this.index,
    required this.onRefresh,
  });

  @override
  State<_AdminTaskTile> createState() => _AdminTaskTileState();
}

class _AdminTaskTileState extends State<_AdminTaskTile> {
  bool _loading = false;

  Map<String, dynamic> get task => widget.task;

  String _fmtDate(String d) {
    try { return DateFormat('d MMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  Future<void> _verifyAndClose() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify & Close Task'),
        content: Text('Mark "${task['title']}" as verified and close it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify & Close'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await api.patch('/tasks/${task['id']}/status', data: {'status': 'verified'});
    } catch (_) {
      try {
        await api.patch('/tasks/${task['id']}/status', data: {'status': 'completed', 'adminVerified': true});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
        setState(() => _loading = false);
        return;
      }
    }
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Task verified and closed!'), backgroundColor: AppColors.success));
      setState(() => _loading = false);
    }
  }

  Future<void> _reassign() async {
    final ctrl = TextEditingController();
    final empId = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reassign Task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Reassign "${task['title']}"',
              style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'New Employee ID',
              hintText: 'e.g. EMP001',
              prefixIcon: Icon(Icons.person_search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (empId == null || empId.isEmpty) return;
    setState(() => _loading = true);
    try {
      await api.patch('/tasks/${task['id']}/reassign', data: {'assignedTo': empId});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Task reassigned to $empId'), backgroundColor: AppColors.primary));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Task'),
        content: Text('Cancel "${task['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Task'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await api.patch('/tasks/${task['id']}/status', data: {'status': 'cancelled'});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task cancelled'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status    = task['status'] as String? ?? 'pending';
    final priority  = task['priority'] as String? ?? 'medium';
    final assignee  = task['assignee'] as Map<String, dynamic>? ?? {};
    final dueDate   = task['dueDate'] as String?;
    final isOverdue = dueDate != null &&
        DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true &&
        status != 'completed';
    final isCompleted = status == 'completed';

    final statusColor = isCompleted ? AppColors.success
        : isOverdue ? AppColors.error
        : status == 'in_progress' ? AppColors.primary
        : AppColors.warning;

    final priorityColor = priority == 'urgent' ? const Color(0xFF9B1DCA)
        : priority == 'high' ? AppColors.error
        : priority == 'medium' ? AppColors.warning
        : AppColors.success;

    return AppCard(
      onTap: () => context.go(
        '/tasks/${task['id']}',
        extra: {'ids': widget.allIds, 'index': widget.index},
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title row ──────────────────────────────────────────────────────
        Row(children: [
          // Priority stripe
          Container(width: 4, height: 44, decoration: BoxDecoration(
              color: priorityColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task['title'] as String? ?? 'Untitled',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimaryOf(context))),
            if ((task['description'] as String? ?? '').isNotEmpty)
              Text(task['description'] as String,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(isOverdue ? 'OVERDUE' : status.toUpperCase().replaceAll('_', ' '),
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 4),
          // Actions popup
          if (_loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondaryOf(context)),
              tooltip: 'Actions',
              onSelected: (v) {
                if (v == 'reassign') _reassign();
                if (v == 'cancel') _cancelTask();
                if (v == 'view') context.go('/tasks/${task['id']}', extra: {'ids': widget.allIds, 'index': widget.index});
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 8), Text('Open Task'),
                ])),
                const PopupMenuItem(value: 'reassign', child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.warning),
                  SizedBox(width: 8), Text('Reassign'),
                ])),
                if (status != 'cancelled') const PopupMenuItem(value: 'cancel', child: Row(children: [
                  Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                  SizedBox(width: 8), Text('Cancel Task', style: TextStyle(color: AppColors.error)),
                ])),
              ],
            ),
        ]),

        // ── Assignee + due date row ────────────────────────────────────────
        if (assignee.isNotEmpty || dueDate != null) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            if (assignee.isNotEmpty) ...[
              Icon(Icons.person_outline, size: 13, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 4),
              Flexible(child: Text(
                '${assignee['firstName'] ?? ''} ${assignee['lastName'] ?? ''}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              )),
              // Employee ID badge
              if ((assignee['employeeId'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                  child: Text(assignee['employeeId'] as String,
                      style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 12),
            ],
            if (dueDate != null) ...[
              Icon(Icons.schedule_rounded, size: 13,
                  color: isOverdue ? AppColors.error : AppColors.textSecondaryOf(context)),
              const SizedBox(width: 4),
              Text(_fmtDate(dueDate),
                  style: TextStyle(fontSize: 12,
                      color: isOverdue ? AppColors.error : AppColors.textSecondaryOf(context),
                      fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500)),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: priorityColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(priority.toUpperCase(),
                  style: TextStyle(fontSize: 9, color: priorityColor, fontWeight: FontWeight.w800)),
            ),
          ]),
        ],

        // ── Verify & Close banner for completed tasks ──────────────────────
        if (isCompleted) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              const Expanded(child: Text('Employee marked complete — verify and close?',
                  style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loading ? null : _verifyAndClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      gradient: AppGradients.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Verify & Close',
                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ],

        // Navigate hint
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textTertiary),
          Text('Tap to open', style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 14)),
    const SizedBox(width: 10),
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimaryOf(context), letterSpacing: -0.3)),
  ]);
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondaryOf(context), letterSpacing: 0.3)),
      const SizedBox(height: 16),
      ...children,
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool required;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.required = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    ),
    validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32)),
      const SizedBox(height: 16),
      Text('Something went wrong', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryOf(context)), maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      ),
    ]),
  ));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message, subtitle;
  const _EmptyState({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary, size: 36)),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryOf(context))),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryOf(context))),
    ]),
  ));
}

// ─── AI Hub Banner (shown in Overview tab) ────────────────────────────────────
class _AiHubBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.go('/admin/ai-hub'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.auroraViolet.withOpacity(0.22), AppColors.auroraCyan.withOpacity(0.12)]
                    : [AppColors.auroraViolet.withOpacity(0.12), AppColors.auroraCyan.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.auroraCyan.withOpacity(0.35), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.auroraViolet.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(children: [
              // Glowing icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppGradients.aurora,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.auroraViolet.withOpacity(0.45), blurRadius: 16)],
                ),
                child: const Text('✨', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(
                  shaderCallback: (b) => AppGradients.aurora.createShader(b),
                  child: const Text('AI Command Center',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Auto-assign tasks · Daily scheduling · Smart alerts',
                  style: TextStyle(fontSize: 11, height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _AiFeaturePill('🎯 Auto-Assign'),
                  const SizedBox(width: 6),
                  _AiFeaturePill('📅 Planner'),
                  const SizedBox(width: 6),
                  _AiFeaturePill('🔔 Alerts'),
                ]),
              ])),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.auroraCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.auroraCyan.withOpacity(0.3)),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: AppColors.auroraCyan, size: 18),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AiFeaturePill extends StatelessWidget {
  final String label;
  const _AiFeaturePill(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.auroraCyan.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.auroraCyan.withOpacity(0.25)),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.auroraCyan)),
  );
}
