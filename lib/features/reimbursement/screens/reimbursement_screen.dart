import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';

final reimbursementsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/reimbursements/my');
  return response.data['data'] as List;
});

class ReimbursementScreen extends ConsumerWidget {
  const ReimbursementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reimAsync = ref.watch(reimbursementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reimbursements'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(reimbursementsProvider)),
      ]),
      body: reimAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (items) {
          if (items.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('No reimbursements yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ElevatedButton.icon(onPressed: () => context.go('/reimbursements/expense-claim'), icon: const Icon(Icons.add), label: const Text('Submit Claim')),
            ],
          ));

          // Summary stats
          final totalAmount = items.fold<double>(0, (acc, r) => acc + double.parse(r['amount'].toString()));
          final approved = items.where((r) => r['status'] == 'approved' || r['status'] == 'paid').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: StatCard(title: 'Total Claims', value: '${items.length}', icon: Icons.receipt, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(title: 'Total Amount', value: '₹${NumberFormat.compact().format(totalAmount)}', icon: Icons.currency_rupee, color: AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(title: 'Approved', value: '$approved', icon: Icons.check_circle, color: AppColors.success)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _ReimbursementCard(item: items[i] as Map<String, dynamic>),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/reimbursements/expense-claim'),
        icon: const Icon(Icons.add),
        label: const Text('New Claim'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _ReimbursementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ReimbursementCard({required this.item});

  Color get _statusColor {
    switch (item['status']) {
      case 'approved': return AppColors.success;
      case 'paid': return AppColors.success;
      case 'rejected': return AppColors.error;
      case 'under_review': return AppColors.primary;
      default: return AppColors.warning;
    }
  }

  IconData get _categoryIcon {
    switch (item['category']) {
      case 'travel': return Icons.flight;
      case 'food': return Icons.restaurant;
      case 'accommodation': return Icons.hotel;
      case 'medical': return Icons.medical_services;
      case 'training': return Icons.school;
      default: return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    return AppCard(
      onTap: () => context.go('/reimbursements/${item['id']}', extra: item),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(_categoryIcon, color: _statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(item['category']?.toString().replaceAll('_', ' ') ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(item['expenseDate'] != null ? DateFormat('d MMM yyyy').format(DateTime.parse(item['expenseDate'])) : '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${NumberFormat('#,##0.00').format(amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            StatusBadge(label: item['status']?.toString().replaceAll('_', ' ') ?? '', color: _statusColor),
            const SizedBox(height: 2),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
          ]),
        ],
      ),
    );
  }
}
