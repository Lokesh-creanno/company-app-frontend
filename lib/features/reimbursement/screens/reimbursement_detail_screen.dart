import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import 'reimbursement_screen.dart' show statusLabel, statusColor, claimsProvider;

final claimDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await api.get('/reimbursements/$id');
  return res.data['data'] as Map<String, dynamic>;
});

class ReimbursementDetailScreen extends ConsumerWidget {
  final String reimbursementId;
  final Map<String, dynamic>? initialData;
  const ReimbursementDetailScreen({super.key, required this.reimbursementId, this.initialData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final async = ref.watch(claimDetailProvider(reimbursementId));

    return Scaffold(
      appBar: AppBar(title: const Text('Claim')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is DioException
            ? (e.response?.data?['message']?.toString() ?? 'Error')
            : e.toString())),
        data: (r) {
          final status = r['status']?.toString() ?? '';
          final items = (r['items'] as List?) ?? [];
          final bills = (r['bills'] as List?) ?? [];
          final total = double.tryParse(r['amount']?.toString() ?? '0') ?? 0;
          final overdue = r['isOverdue'] == true;
          final emp = r['employee'] as Map<String, dynamic>?;
          final isApprover = user != null && (user.isAccounts || user.isSuperAdmin);
          final isOwner = user != null && emp == null; // /my has no employee join; owner viewing

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // Header
              Row(children: [
                Expanded(
                  child: Text(r['title'] ?? 'Claim',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                _Badge(text: statusLabel(status), color: statusColor(status)),
              ]),
              if (overdue) const Padding(
                padding: EdgeInsets.only(top: 6),
                child: _Badge(text: 'OVERDUE', color: AppColors.error),
              ),
              if (emp != null) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${emp['firstName']} ${emp['lastName']} · ${emp['department'] ?? ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
              const SizedBox(height: 16),

              // Line items table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                child: Column(children: [
                  for (int i = 0; i < items.length; i++)
                    _ItemRow(item: items[i] as Map<String, dynamic>, last: i == items.length - 1),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                    ),
                    child: Row(children: [
                      const Text('Grand total', style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('₹${NumberFormat('#,##0.00').format(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              if (bills.isNotEmpty) ...[
                const Text('Bills', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final b in bills)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(b.toString(), width: 90, height: 90, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 90, height: 90, color: AppColors.surfaceVariant,
                              child: const Icon(Icons.broken_image_rounded))),
                    ),
                ]),
                const SizedBox(height: 16),
              ],

              // Approval trail
              _Trail(r: r),

              const SizedBox(height: 8),
              // Actions
              ..._actions(context, ref, user, status, r, items),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, user, String status,
      Map<String, dynamic> r, List items) {
    if (user == null) return [];
    final widgets = <Widget>[];

    Future<void> act(String endpoint, String action) async {
      final remark = await _askRemark(context, action);
      if (remark == null) return; // cancelled
      try {
        await api.patch('/reimbursements/${r['id']}/$endpoint', data: {'action': action, 'remark': remark});
        ref.invalidate(claimDetailProvider(reimbursementId));
        ref.invalidate(claimsProvider('queue'));
        ref.invalidate(claimsProvider('mine'));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Claim ${action.replaceAll('_', ' ')} ✓'), backgroundColor: AppColors.success));
        }
      } catch (e) {
        if (context.mounted) {
          final m = e is DioException ? (e.response?.data?['message']?.toString() ?? 'Failed') : 'Failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));
        }
      }
    }

    // Accounts stage
    if ((user.isAccounts || user.isSuperAdmin) && status == 'pending_accounts') {
      widgets.add(_actionRow('Accounts review', [
        _btn('Approve', AppColors.success, () => act('accounts', 'approve')),
        _btn('Send back', AppColors.warning, () => act('accounts', 'send_back')),
        _btn('Reject', AppColors.error, () => act('accounts', 'reject')),
      ]));
    }
    // Super-admin stage
    if (user.isSuperAdmin && status == 'pending_superadmin') {
      widgets.add(_actionRow('Final approval', [
        _btn('Approve', AppColors.success, () => act('superadmin', 'approve')),
        _btn('Send back', AppColors.warning, () => act('superadmin', 'send_back')),
        _btn('Reject', AppColors.error, () => act('superadmin', 'reject')),
      ]));
    }
    // Owner resubmit
    if (status == 'sent_back') {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: FilledButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Resubmit as-is'),
          onPressed: () async {
            try {
              await api.post('/reimbursements/${r['id']}/resubmit',
                  data: {'items': jsonEncode(items)});
              ref.invalidate(claimDetailProvider(reimbursementId));
              ref.invalidate(claimsProvider('mine'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Resubmitted ✓'), backgroundColor: AppColors.success));
              }
            } catch (_) {}
          },
        ),
      ));
    }
    // Mark paid
    if ((user.isAccounts || user.isSuperAdmin) && status == 'approved') {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.payments_rounded),
          label: const Text('Mark as paid'),
          onPressed: () async {
            try {
              await api.patch('/reimbursements/${r['id']}/paid');
              ref.invalidate(claimDetailProvider(reimbursementId));
              ref.invalidate(claimsProvider('queue'));
            } catch (_) {}
          },
        ),
      ));
    }
    return widgets;
  }

  Widget _actionRow(String title, List<Widget> btns) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [for (final b in btns) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: b))]),
        ]),
      );

  Widget _btn(String label, Color c, VoidCallback onTap) =>
      FilledButton(style: FilledButton.styleFrom(backgroundColor: c), onPressed: onTap, child: Text(label, textAlign: TextAlign.center));
}

Future<String?> _askRemark(BuildContext context, String action) async {
  final ctrl = TextEditingController();
  final needReason = action == 'reject' || action == 'send_back';
  return showDialog<String>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(action.replaceAll('_', ' ')),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
            labelText: needReason ? 'Reason (required)' : 'Remark (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx, null), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (needReason && ctrl.text.trim().isEmpty) return;
            Navigator.pop(dctx, ctrl.text.trim());
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool last;
  const _ItemRow({required this.item, required this.last});
  @override
  Widget build(BuildContext context) {
    final amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.borderOf(context))),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['expenseHead']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text([
              if ((item['category'] ?? '').toString().isNotEmpty) item['category'],
              if ((item['date'] ?? '').toString().isNotEmpty) item['date'].toString().slice0(10),
              if ((item['remarks'] ?? '').toString().isNotEmpty) item['remarks'],
            ].join(' · '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ),
        Text('₹${NumberFormat('#,##0.00').format(amt)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}

extension _Slice on String {
  String slice0(int n) => length <= n ? this : substring(0, n);
}

class _Trail extends StatelessWidget {
  final Map<String, dynamic> r;
  const _Trail({required this.r});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ]),
      ));
    }
    String? fmt(dynamic v) => v == null ? null : DateFormat('d MMM, h:mm a').format(DateTime.parse(v.toString()).toLocal());
    add('Submitted', fmt(r['createdAt']));
    add('Accounts acted', fmt(r['accountsAt']));
    add('Accounts remark', r['accountsRemark']?.toString());
    add('Final approved', fmt(r['approvedAt']));
    add('Super admin remark', r['superAdminRemark']?.toString());
    add('Rejection reason', r['rejectionReason']?.toString());
    add('Sent-back reason', r['sentBackReason']?.toString());
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Trail', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      ...rows,
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}
