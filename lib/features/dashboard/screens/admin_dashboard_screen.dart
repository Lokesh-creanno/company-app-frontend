import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';

final adminDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await api.get('/dashboard/admin');
  return response.data['data'] as Map<String, dynamic>;
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(adminDashboardProvider)),
          IconButton(icon: const Icon(Icons.people_outline), onPressed: () => context.go('/employees')),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final overview = data['overview'] as Map<String, dynamic>? ?? {};
          final deptAttendance = (data['departmentAttendance'] as List?) ?? [];
          return _AdminContent(overview: overview, deptAttendance: deptAttendance);
        },
      ),
    );
  }
}

class _AdminContent extends StatelessWidget {
  final Map<String, dynamic> overview;
  final List<dynamic> deptAttendance;

  const _AdminContent({required this.overview, required this.deptAttendance});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview grid
        const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatCard(title: 'Total Employees', value: '${overview['totalEmployees'] ?? 0}', icon: Icons.people, color: AppColors.primary),
            StatCard(title: 'Present Today', value: '${overview['presentToday'] ?? 0}', icon: Icons.how_to_reg, color: AppColors.success),
            StatCard(title: 'Open Tasks', value: '${overview['openTasks'] ?? 0}', icon: Icons.task_alt, color: AppColors.warning),
            StatCard(title: 'Pending Claims', value: '${overview['pendingReimbursements'] ?? 0}', icon: Icons.receipt_long, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 20),

        // Monthly highlights
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This Month', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _HighlightRow(
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                label: 'Tasks Completed',
                value: '${overview['completedTasksThisMonth'] ?? 0}',
              ),
              const SizedBox(height: 12),
              _HighlightRow(
                icon: Icons.currency_rupee,
                color: AppColors.primary,
                label: 'Reimbursements Approved',
                value: '₹${_formatAmount(overview['reimbursementAmountThisMonth'])}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Department attendance chart
        if (deptAttendance.isNotEmpty) ...[
          const Text('Department Attendance Today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: deptAttendance.fold<double>(0, (m, d) => d['count'] > m ? d['count'].toDouble() : m) + 2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        if (v.toInt() >= deptAttendance.length) return const SizedBox();
                        final dept = (deptAttendance[v.toInt()]['department'] as String? ?? '');
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(dept.length > 6 ? dept.substring(0, 6) : dept, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        );
                      },
                    )),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 2, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.border, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  barGroups: deptAttendance.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: (e.value['count'] as num?)?.toDouble() ?? 0,
                      color: AppColors.primary,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )],
                  )).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Quick admin actions
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionCard(icon: Icons.person_add_outlined, label: 'Add Employee', color: AppColors.primary, onTap: () => context.go('/employees'))),
          const SizedBox(width: 12),
          Expanded(child: _ActionCard(icon: Icons.receipt_long_outlined, label: 'Review Claims', color: AppColors.warning, onTap: () => context.go('/reimbursements'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ActionCard(icon: Icons.assignment_outlined, label: 'All Tasks', color: AppColors.success, onTap: () => context.go('/tasks'))),
          const SizedBox(width: 12),
          Expanded(child: _ActionCard(icon: Icons.access_time_outlined, label: 'Attendance', color: AppColors.accent, onTap: () => context.go('/attendance'))),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  String _formatAmount(dynamic val) {
    if (val == null) return '0';
    final amount = double.tryParse(val.toString()) ?? 0;
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _HighlightRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
    const SizedBox(width: 12),
    Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
  ]);
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
    ]),
  );
}
