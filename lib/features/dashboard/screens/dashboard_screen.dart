import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/ai_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await api.get('/dashboard/me');
  return response.data['data'] as Map<String, dynamic>;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(authStateProvider).value;
    final dashAsync = ref.watch(dashboardProvider);
    final isWide    = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWide ? null : _buildAppBar(context, ref, user),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: dashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error)),
            const SizedBox(height: 16),
            Text('Could not load dashboard', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => ref.invalidate(dashboardProvider), child: const Text('Retry')),
          ])),
          data: (data) => _DashboardBody(data: data, user: user, greeting: _greeting()),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref, dynamic user) {
    final initial = user?.firstName?.isNotEmpty == true ? user!.firstName[0].toUpperCase() : '?';
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: Builder(builder: (ctx) => IconButton(
        icon: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.menu_rounded, size: 18, color: AppColors.textPrimary)),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      )),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const Text('Dashboard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
      ]),
      actions: [
        IconButton(
          icon: Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
            child: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.textPrimary)),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle,
                boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.25)),
              child: user?.profilePhoto != null
                  ? ClipOval(child: Image.network(user!.profilePhoto!, fit: BoxFit.cover))
                  : Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  final dynamic user;
  final String greeting;
  const _DashboardBody({required this.data, required this.user, required this.greeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance     = data['attendanceSummary'] as Map<String, dynamic>? ?? {};
    final today          = data['todayAttendance']   as Map<String, dynamic>?;
    final tasks          = (data['pendingTasks']     as List?) ?? [];
    final reimbursements = (data['pendingReimbursements'] as List?) ?? [];
    final isWide         = Responsive.isWide(context);
    final padding        = Responsive.pagePadding(context);

    return ListView(
      padding: padding,
      children: [
        // ── Wide layout: show inline header ────────────────────────────────
        if (isWide) ...[
          _WideHeader(user: user, greeting: greeting, ref: ref),
          const SizedBox(height: 24),
        ],

        // ── AI Insights Panel ───────────────────────────────────────────────
        if (AiConfig.aiEnabled) ...[
          _AiInsightsPanel(
            userName: user?.fullName ?? 'there',
            tasksDueToday: tasks.length,
            tasksDueTomorrow: 0,
            pendingClaims: reimbursements.length,
            pendingClaimsAmount: reimbursements.fold<double>(0, (s, r) =>
                s + (double.tryParse(r['amount']?.toString() ?? '0') ?? 0)),
            attendanceDays: (attendance['presentDays'] as num?)?.toInt() ?? 0,
            workingDays: (attendance['totalWorkingDays'] as num?)?.toInt() ?? 22,
            teamCompleted: 0,
            teamTotal: tasks.length,
          ),
          const SizedBox(height: 20),
        ],

        // ── Hero: Today's status ────────────────────────────────────────────
        _TodayStatusCard(today: today),
        const SizedBox(height: 24),

        // ── Monthly stats grid ──────────────────────────────────────────────
        _SectionLabel(title: 'This Month'),
        const SizedBox(height: 14),
        _StatsGrid(attendance: attendance),
        const SizedBox(height: 28),

        // ── Quick actions ───────────────────────────────────────────────────
        _SectionLabel(title: 'Quick Actions'),
        const SizedBox(height: 14),
        _QuickActionsRow(),
        const SizedBox(height: 28),

        // ── Pending tasks ───────────────────────────────────────────────────
        if (tasks.isNotEmpty) ...[
          _SectionHeader(title: 'Pending Tasks', count: tasks.length, onTap: () => context.go('/tasks')),
          const SizedBox(height: 12),
          ...tasks.take(3).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskTile(task: t as Map<String, dynamic>),
          )),
          const SizedBox(height: 16),
        ],

        // ── Pending reimbursements ──────────────────────────────────────────
        if (reimbursements.isNotEmpty) ...[
          _SectionHeader(title: 'Pending Claims', count: reimbursements.length, onTap: () => context.go('/reimbursements')),
          const SizedBox(height: 12),
          ...reimbursements.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReimbursementTile(r: r as Map<String, dynamic>),
          )),
        ],
        const SizedBox(height: 100),
      ],
    );
  }
}

// ─── Wide Header ─────────────────────────────────────────────────────────────
class _WideHeader extends StatelessWidget {
  final dynamic user; final String greeting; final WidgetRef ref;
  const _WideHeader({required this.user, required this.greeting, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initial = user?.firstName?.isNotEmpty == true ? user!.firstName[0].toUpperCase() : '?';
    return Row(children: [
      Container(width: 48, height: 48,
        decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle,
          boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.25)),
        child: user?.profilePhoto != null
            ? ClipOval(child: Image.network(user!.profilePhoto!, fit: BoxFit.cover))
            : Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting, ${user?.firstName ?? ''}! 👋',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
        Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ])),
      IconButton(
        icon: Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textPrimary)),
        onPressed: () {},
      ),
    ]);
  }
}

// ─── Today's Status Hero Card ────────────────────────────────────────────────
class _TodayStatusCard extends StatelessWidget {
  final Map<String, dynamic>? today;
  const _TodayStatusCard({this.today});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn  = today?['checkInTime'] != null;
    final isCheckedOut = today?['checkOutTime'] != null;
    // .toLocal() converts UTC server time → device's local timezone (e.g. IST)
    final checkIn  = isCheckedIn  ? DateFormat('hh:mm a').format(DateTime.parse(today!['checkInTime']).toLocal())  : '--:--';
    final checkOut = isCheckedOut ? DateFormat('hh:mm a').format(DateTime.parse(today!['checkOutTime']).toLocal()) : '--:--';
    final hours    = today?['workingHours'] != null ? '${double.parse(today!['workingHours'].toString()).toStringAsFixed(1)}h' : '0h';

    return GradientCard(
      gradient: AppGradients.hero,
      shadows: AppShadows.primaryGlow,
      child: Column(children: [
        // Top row: title + status badge
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.work_outline_rounded, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            const Text("Today's Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
                color: isCheckedIn && !isCheckedOut ? const Color(0xFF4ADE80) : Colors.white60)),
              const SizedBox(width: 5),
              Text(isCheckedIn && !isCheckedOut ? 'Working' : isCheckedOut ? 'Done' : 'Not Started',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
        ]),

        const SizedBox(height: 20),

        // Time row
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TimeInfo(label: 'Check In', time: checkIn, icon: Icons.login_rounded),
          Container(width: 1, height: 48, color: Colors.white.withOpacity(0.2)),
          _TimeInfo(label: 'Check Out', time: checkOut, icon: Icons.logout_rounded),
          Container(width: 1, height: 48, color: Colors.white.withOpacity(0.2)),
          _TimeInfo(label: 'Hours', time: hours, icon: Icons.timer_rounded),
        ]),

        if (isCheckedIn && !isCheckedOut) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/attendance'),
            child: Container(
              width: double.infinity, height: 42,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.logout_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text('Check Out Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          ),
        ] else if (!isCheckedIn) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go('/attendance'),
            child: Container(
              width: double.infinity, height: 42,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.login_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                const Text('Check In Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final String label, time;
  final IconData icon;
  const _TimeInfo({required this.label, required this.time, required this.icon});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: Colors.white60, size: 16),
    const SizedBox(height: 6),
    Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
  ]);
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> attendance;
  const _StatsGrid({required this.attendance});

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.gridCols(context);
    final stats = [
      (title: 'Present Days', value: '${attendance['present'] ?? 0}', icon: Icons.check_circle_outline_rounded, color: AppColors.success),
      (title: 'Absent',       value: '${attendance['absent']  ?? 0}', icon: Icons.cancel_outlined,             color: AppColors.error),
      (title: 'Half Days',    value: '${attendance['halfDay'] ?? 0}', icon: Icons.brightness_4_rounded,        color: AppColors.warning),
      (title: 'Work Hours',   value: '${attendance['totalHours'] ?? 0}h', icon: Icons.timer_rounded,           color: AppColors.primary),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols > 3 ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => StatCard(
        title: stats[i].title,
        value: stats[i].value,
        icon: stats[i].icon,
        color: stats[i].color,
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (label: 'Attendance', icon: Icons.access_time_rounded, gradient: AppGradients.secondary, path: '/attendance'),
      (label: 'New Claim',  icon: Icons.add_card_rounded,    gradient: AppGradients.warning,   path: '/reimbursements/new'),
      (label: 'Tasks',      icon: Icons.task_alt_rounded,    gradient: AppGradients.primary,   path: '/tasks'),
      (label: 'Documents',  icon: Icons.folder_zip_rounded,  gradient: AppGradients.info,      path: '/documents'),
    ];

    return Row(
      children: actions.map((a) => Expanded(child: Padding(
        padding: EdgeInsets.only(right: a != actions.last ? 10 : 0),
        child: GestureDetector(
          onTap: () => context.go(a.path),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: a.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.card,
            ),
            child: Column(children: [
              Icon(a.icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(a.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ))).toList(),
    );
  }
}

// ─── Section labels / headers ─────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3));
}

class _SectionHeader extends StatelessWidget {
  final String title; final int count; final VoidCallback onTap;
  const _SectionHeader({required this.title, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        _SectionLabel(title: title),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      TextButton.icon(
        onPressed: onTap,
        icon: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        label: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
    ],
  );
}

// ─── Task Tile ────────────────────────────────────────────────────────────────
class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  const _TaskTile({required this.task});

  Color get _priorityColor {
    switch (task['priority']) {
      case 'urgent': return AppColors.error;
      case 'high':   return AppColors.warning;
      case 'medium': return AppColors.primary;
      default:       return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    onTap: () => context.go('/tasks/${task['id']}'),
    child: Row(children: [
      Container(width: 4, height: 44, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_priorityColor, _priorityColor.withOpacity(0.4)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 12),
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.task_alt_rounded, color: _priorityColor, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(task['dueDate'] != null ? 'Due ${DateFormat('d MMM').format(DateTime.parse(task['dueDate']))}' : 'No due date',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ])),
      const SizedBox(width: 8),
      StatusBadge(label: task['status']?.toString().replaceAll('_', ' ') ?? '', color: AppColors.primary),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  ✨ AI INSIGHTS PANEL
// ══════════════════════════════════════════════════════════════════════════════
class _AiInsightsPanel extends StatefulWidget {
  final String userName;
  final int tasksDueToday;
  final int tasksDueTomorrow;
  final int pendingClaims;
  final double pendingClaimsAmount;
  final int attendanceDays;
  final int workingDays;
  final int teamCompleted;
  final int teamTotal;

  const _AiInsightsPanel({
    required this.userName,
    required this.tasksDueToday,
    required this.tasksDueTomorrow,
    required this.pendingClaims,
    required this.pendingClaimsAmount,
    required this.attendanceDays,
    required this.workingDays,
    required this.teamCompleted,
    required this.teamTotal,
  });

  @override
  State<_AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends State<_AiInsightsPanel> {
  List<AiInsight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await AiService.generateDashboardInsights(
      userName:            widget.userName,
      tasksDueToday:       widget.tasksDueToday,
      tasksDueTomorrow:    widget.tasksDueTomorrow,
      pendingClaims:       widget.pendingClaims,
      pendingClaimsAmount: widget.pendingClaimsAmount,
      attendanceDays:      widget.attendanceDays,
      workingDays:         widget.workingDays,
      teamCompleted:       widget.teamCompleted,
      teamTotal:           widget.teamTotal,
    );
    if (mounted) setState(() { _insights = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.14),
                    AppColors.auroraCyan.withOpacity(0.08),
                  ])
                : LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.08),
                    AppColors.auroraCyan.withOpacity(0.05),
                  ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.auroraCyan.withOpacity(isDark ? 0.25 : 0.30),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (b) => AppGradients.aurora.createShader(b),
                child: const Text('AI Insights',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
              const Spacer(),
              if (!_loading)
                GestureDetector(
                  onTap: _load,
                  child: Icon(Icons.refresh_rounded, size: 16,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ),
            ]),
            const SizedBox(height: 12),

            // Insights
            if (_loading)
              const Center(child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.auroraCyan),
              ))
            else
              Column(
                children: _insights.asMap().entries.map((entry) {
                  final i = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: entry.key < _insights.length - 1 ? 10 : 0),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(i.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w500,
                        ))),
                      if (i.actionLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppGradients.aurora,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(i.actionLabel!,
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  );
                }).toList(),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─── Reimbursement Tile ───────────────────────────────────────────────────────
class _ReimbursementTile extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ReimbursementTile({required this.r});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    onTap: () => context.go('/reimbursements'),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(gradient: AppGradients.warning, borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.glow(AppColors.warning, intensity: 0.2)),
        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text('₹${r['amount']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ])),
      StatusBadge(label: 'Pending', color: AppColors.warning),
    ]),
  );
}
