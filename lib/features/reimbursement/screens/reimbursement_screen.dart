import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/download_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';

// mode: 'mine' (own claims) or 'queue' (approval queue for accounts/super_admin)
final claimsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, mode) async {
  final path = mode == 'queue' ? '/reimbursements/queue' : '/reimbursements/my';
  final res = await api.get(path);
  return res.data['data'] as List;
});

class ReimbursementScreen extends ConsumerStatefulWidget {
  const ReimbursementScreen({super.key});
  @override
  ConsumerState<ReimbursementScreen> createState() => _ReimbursementScreenState();
}

class _ReimbursementScreenState extends ConsumerState<ReimbursementScreen> {
  bool _showQueue = true; // approvers default to the queue
  bool _downloading = false;

  Future<void> _exportAll() async {
    setState(() => _downloading = true);
    try {
      final bytes = await api.getBytes('/export/reimbursements');
      await saveFile(bytes, 'reimbursements_all.xlsx');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isApprover = user != null && (user.isAccounts || user.isSuperAdmin);
    final mode = (isApprover && _showQueue) ? 'queue' : 'mine';
    final async = ref.watch(claimsProvider(mode));

    return Scaffold(
      appBar: AppBar(
        title: Text(mode == 'queue' ? 'Claims to review' : 'My reimbursements'),
        actions: [
          if (isApprover)
            IconButton(
              tooltip: 'Export all (Excel)',
              icon: _downloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              onPressed: _downloading ? null : _exportAll,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(claimsProvider(mode))),
        ],
        bottom: isApprover
            ? PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Queue'), icon: Icon(Icons.inbox_rounded)),
                      ButtonSegment(value: false, label: Text('Mine'), icon: Icon(Icons.person_rounded)),
                    ],
                    selected: {_showQueue},
                    onSelectionChanged: (s) => setState(() => _showQueue = s.first),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/reimbursements/new');
          ref.invalidate(claimsProvider(mode)); // refresh list on return
        },
        icon: const Icon(Icons.add),
        label: const Text('New claim'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(e),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(mode == 'queue' ? 'Nothing to review' : 'No claims yet',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(claimsProvider(mode)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ClaimCard(
                item: items[i] as Map<String, dynamic>,
                showWho: mode == 'queue',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _err(Object e) {
    final msg = e is DioException
        ? (e.response?.data?['message']?.toString() ?? 'Cannot reach server')
        : e.toString();
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(msg, textAlign: TextAlign.center)));
  }
}

String statusLabel(String s) {
  switch (s) {
    case 'pending_accounts': return 'With Accounts';
    case 'pending_superadmin': return 'With Super Admin';
    case 'sent_back': return 'Sent back';
    case 'approved': return 'Approved';
    case 'rejected': return 'Rejected';
    case 'paid': return 'Paid';
    default: return s;
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'approved':
    case 'paid': return AppColors.success;
    case 'rejected': return AppColors.error;
    case 'sent_back': return AppColors.warning;
    default: return AppColors.primary; // pending_*
  }
}

class _ClaimCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showWho;
  const _ClaimCard({required this.item, required this.showWho});

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
    final status = item['status']?.toString() ?? '';
    final overdue = item['isOverdue'] == true;
    final emp = item['employee'] as Map<String, dynamic>?;
    final who = emp != null ? '${emp['firstName']} ${emp['lastName']}' : '';
    final lines = (item['items'] as List?)?.length ?? 0;

    return AppCard(
      onTap: () => context.push('/reimbursements/${item['id']}', extra: item),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: statusColor(status).withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_long_rounded, color: statusColor(status), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] ?? 'Claim',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${showWho && who.trim().isNotEmpty ? '$who · ' : ''}$lines item${lines == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${NumberFormat('#,##0').format(amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            StatusBadge(label: statusLabel(status), color: statusColor(status)),
            if (overdue) ...[
              const SizedBox(height: 3),
              const StatusBadge(label: 'OVERDUE', color: AppColors.error),
            ],
          ]),
        ],
      ),
    );
  }
}
