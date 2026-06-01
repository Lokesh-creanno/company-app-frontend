import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';

// Provider: fetches full list and filters by ID — avoids missing /reimbursements/:id route
final reimbursementDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  // Try employee's own list first
  try {
    final resp = await api.get('/reimbursements/my');
    final list = resp.data['data'] as List;
    final found = list.where((r) => r['id']?.toString() == id).toList();
    if (found.isNotEmpty) return found.first as Map<String, dynamic>;
  } catch (_) {}
  // Fallback: admin all-claims list
  try {
    final resp = await api.get('/reimbursements');
    final list = resp.data['data'] as List;
    final found = list.where((r) => r['id']?.toString() == id).toList();
    if (found.isNotEmpty) return found.first as Map<String, dynamic>;
  } catch (_) {}
  throw Exception('Claim not found. It may have been deleted.');
});

// ══════════════════════════════════════════════════════════════════════════════
//  Reimbursement Detail Screen
// ══════════════════════════════════════════════════════════════════════════════
class ReimbursementDetailScreen extends ConsumerWidget {
  final String reimbursementId;
  /// Data passed directly from the list — avoids API call entirely
  final Map<String, dynamic>? initialData;

  const ReimbursementDetailScreen({
    super.key,
    required this.reimbursementId,
    this.initialData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authStateProvider).value;
    final isAdmin = currentUser?.isAdmin == true || currentUser?.isManager == true;

    // If we have initialData from navigation, show immediately — no API call needed
    if (initialData != null) {
      return _ClaimDetailScaffold(
        claim: initialData!,
        isAdmin: isAdmin,
        onRefresh: () => ref.invalidate(reimbursementDetailProvider(reimbursementId)),
      );
    }

    // Otherwise fetch (e.g. deep link / refresh)
    final async = ref.watch(reimbursementDetailProvider(reimbursementId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Claim Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Claim Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, size: 40, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              const Text('Could not load claim details',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(reimbursementDetailProvider(reimbursementId)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ]),
          ),
        ),
      ),
      data: (claim) => _ClaimDetailScaffold(
        claim: claim,
        isAdmin: isAdmin,
        onRefresh: () => ref.invalidate(reimbursementDetailProvider(reimbursementId)),
      ),
    );
  }
}

// Scaffold wrapper so both paths share the same UI
class _ClaimDetailScaffold extends StatelessWidget {
  final Map<String, dynamic> claim;
  final bool isAdmin;
  final VoidCallback onRefresh;
  const _ClaimDetailScaffold({
    required this.claim, required this.isAdmin, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Claim Details'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: onRefresh,
        ),
      ],
    ),
    body: _ClaimDetailBody(claim: claim, isAdmin: isAdmin, onRefresh: onRefresh),
  );
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _ClaimDetailBody extends StatefulWidget {
  final Map<String, dynamic> claim;
  final bool isAdmin;
  final VoidCallback onRefresh;
  const _ClaimDetailBody({required this.claim, required this.isAdmin, required this.onRefresh});

  @override
  State<_ClaimDetailBody> createState() => _ClaimDetailBodyState();
}

class _ClaimDetailBodyState extends State<_ClaimDetailBody> {
  bool _approving = false;
  bool _rejecting = false;

  Map<String, dynamic> get c => widget.claim;

  String get _status => c['status'] as String? ?? 'pending';
  double get _amount => double.tryParse(c['amount']?.toString() ?? '0') ?? 0;

  Color get _statusColor {
    switch (_status) {
      case 'approved': case 'paid': return AppColors.success;
      case 'rejected': return AppColors.error;
      case 'under_review': return AppColors.primary;
      default: return AppColors.warning;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'approved': case 'paid': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      case 'under_review': return Icons.pending_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  // Parse expense lines from description
  List<Map<String, String>> _parseExpenses(String? desc) {
    if (desc == null || desc.isEmpty) return [];
    final lines = desc.split('\n');
    final expenses = <Map<String, String>>[];
    for (final line in lines) {
      final match = RegExp(r'^\d+\.\s*(.+?):\s*Rs\.(\d+(?:\.\d{1,2})?)').firstMatch(line.trim());
      if (match != null) {
        expenses.add({'name': match.group(1)!.trim(), 'amount': match.group(2)!});
      }
    }
    return expenses;
  }

  String _fmtDate(String? d) {
    if (d == null) return 'N/A';
    try { return DateFormat('d MMMM yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
  }

  String _fmtDateTime(String? d) {
    if (d == null) return 'N/A';
    try { return DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(d).toLocal()); } catch (_) { return d; }
  }

  Future<void> _approve() async {
    final confirm = await _showConfirmDialog(
      title: 'Approve Claim',
      message: 'Approve this claim of ₹${_amount.toStringAsFixed(2)} for ${_employeeName()}?',
      actionLabel: 'Approve',
      actionColor: AppColors.success,
    );
    if (confirm != true) return;
    setState(() => _approving = true);
    try {
      await api.patch('/reimbursements/${c['id']}/status', data: {'status': 'approved'});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Claim approved successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _rejectWithReason() async {
    final reason = await _showRejectReasonDialog();
    if (reason == null) return; // cancelled
    setState(() => _rejecting = true);
    try {
      await api.patch('/reimbursements/${c['id']}/status', data: {
        'status': 'rejected',
        'rejectionReason': reason,
      });
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim rejected.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title, required String message,
    required String actionLabel, required Color actionColor,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: actionColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );

  Future<String?> _showRejectReasonDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide a reason for rejection (optional):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. Missing receipts, amount exceeds policy limit...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Reject Claim'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _employeeName() {
    final emp = c['employee'] as Map<String, dynamic>?;
    if (emp == null) return 'Team Member';
    return '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final emp = c['employee'] as Map<String, dynamic>? ?? {};
    final expenses = _parseExpenses(c['description'] as String?);
    final fmt = NumberFormat('#,##0.00');
    final bills = (c['bills'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Status Hero Card ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_statusColor.withOpacity(0.12), _statusColor.withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _statusColor.withOpacity(0.3)),
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15), shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _status == 'approved' ? 'Approved' :
                  _status == 'paid' ? 'Paid' :
                  _status == 'rejected' ? 'Rejected' :
                  _status == 'under_review' ? 'Under Review' : 'Pending Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _statusColor),
                ),
                Text(
                  _status == 'pending' ? 'Waiting for admin review' :
                  _status == 'under_review' ? 'Being reviewed by admin' :
                  _status == 'approved' ? 'Claim has been approved' :
                  _status == 'paid' ? 'Amount has been disbursed' :
                  'Claim was not approved',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${fmt.format(_amount)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _statusColor)),
                const Text('Total Claim', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ]),

            // Rejection reason if rejected
            if (_status == 'rejected' && (c['rejectionReason'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Rejection Reason',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error)),
                    const SizedBox(height: 2),
                    Text(c['rejectionReason'] as String,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ])),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // ── Claim Info ─────────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('Claim Information'),
          const SizedBox(height: 12),
          _DetailRow(label: 'Claim ID', value: c['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A',
              icon: Icons.tag_rounded, valueStyle: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 14)),
          _DetailRow(label: 'Title', value: c['title'] ?? 'N/A', icon: Icons.title_rounded),
          _DetailRow(label: 'Project / Category',
              value: (c['category'] as String?)?.replaceAll('_', ' ').toUpperCase() ?? 'General',
              icon: Icons.folder_outlined),
          _DetailRow(label: 'Expense Date', value: _fmtDate(c['expenseDate'] as String?), icon: Icons.calendar_today_outlined),
          _DetailRow(label: 'Submitted On', value: _fmtDateTime(c['createdAt'] as String?), icon: Icons.send_rounded),
          if ((c['remarks'] as String? ?? '').isNotEmpty)
            _DetailRow(label: 'Remarks', value: c['remarks'] as String, icon: Icons.notes_rounded),
        ])),

        const SizedBox(height: 12),

        // ── Team Member Info ───────────────────────────────────────────────
        if (emp.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('Team Member'),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
              child: Center(child: Text(
                '${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}'.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(emp['designation'] ?? emp['department'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
                ),
                child: Text(emp['employeeId'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ])),

        // ── Expense Breakdown ──────────────────────────────────────────────
        if (expenses.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Expense Breakdown'),
            const SizedBox(height: 10),
            // Table header
            Container(
              color: AppColors.primary.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(children: const [
                SizedBox(width: 28, child: Text('#',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary))),
                Expanded(child: Text('Expense',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary))),
                Text('Amount',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            ...expenses.asMap().entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: e.key.isEven ? Colors.transparent : Colors.grey.withOpacity(0.025),
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.08))),
              ),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${e.key + 1}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                Expanded(child: Text(e.value['name']!, style: const TextStyle(fontSize: 13))),
                Text('₹${fmt.format(double.tryParse(e.value['amount']!) ?? 0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            )),
            // Total
            Container(
              color: AppColors.success.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const SizedBox(width: 28),
                const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Text('₹${fmt.format(_amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
              ]),
            ),
          ])),
        ] else ...[
          const SizedBox(height: 12),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Amount'),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.currency_rupee, size: 28, color: AppColors.primary),
              Text(fmt.format(_amount),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ]),
          ])),
        ],

        // ── Bill Attachments ───────────────────────────────────────────────
        if (bills.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionTitle('Bill Attachments (${bills.length})'),
            const SizedBox(height: 8),
            ...bills.asMap().entries.map((e) {
              final bill = e.value as Map<String, dynamic>? ?? {};
              final filename = bill['filename'] ?? bill['originalname'] ?? 'Document ${e.key + 1}';
              final isPdf = filename.toString().toLowerCase().endsWith('.pdf');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPdf ? AppColors.error : AppColors.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                      color: isPdf ? AppColors.error : AppColors.primary, size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(filename.toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (bill['size'] != null)
                      Text('${((bill['size'] as num) / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  if (bill['url'] != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                      onPressed: () {}, // open file URL
                      tooltip: 'View file',
                    ),
                ]),
              );
            }),
          ])),
        ],

        // ── Status Timeline ────────────────────────────────────────────────
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('Status Timeline'),
          const SizedBox(height: 12),
          _TimelineStep(
            label: 'Submitted', date: _fmtDateTime(c['createdAt'] as String?),
            color: AppColors.primary, icon: Icons.send_rounded, isDone: true,
          ),
          _TimelineStep(
            label: 'Under Review', date: _status != 'pending' ? 'In progress' : 'Pending',
            color: AppColors.primary, icon: Icons.manage_search_rounded,
            isDone: _status != 'pending',
          ),
          _TimelineStep(
            label: _status == 'rejected' ? 'Rejected' : 'Approved',
            date: _status == 'approved' || _status == 'paid' || _status == 'rejected'
                ? _fmtDateTime(c['updatedAt'] as String?) : 'Awaiting',
            color: _status == 'rejected' ? AppColors.error : AppColors.success,
            icon: _status == 'rejected' ? Icons.cancel_rounded : Icons.check_circle_rounded,
            isDone: _status == 'approved' || _status == 'paid' || _status == 'rejected',
            isLast: _status != 'approved' && _status != 'paid',
          ),
          if (_status == 'approved' || _status == 'paid')
            _TimelineStep(
              label: 'Amount Disbursed', date: _status == 'paid' ? _fmtDateTime(c['updatedAt'] as String?) : 'Pending',
              color: AppColors.success, icon: Icons.payments_rounded,
              isDone: _status == 'paid', isLast: true,
            ),
        ])),

        // ── Admin Actions ──────────────────────────────────────────────────
        if (widget.isAdmin && _status == 'pending') ...[
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _rejecting ? null : _rejectWithReason,
                icon: _rejecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _approving ? null : _approve,
                icon: _approving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve Claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3));
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final TextStyle? valueStyle;
  const _DetailRow({required this.label, required this.value, required this.icon, this.valueStyle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 10),
      SizedBox(width: 110, child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: Text(value,
          style: valueStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

class _TimelineStep extends StatelessWidget {
  final String label, date;
  final Color color;
  final IconData icon;
  final bool isDone;
  final bool isLast;
  const _TimelineStep({
    required this.label, required this.date, required this.color,
    required this.icon, required this.isDone, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: isDone ? color : AppColors.surfaceVariant,
            shape: BoxShape.circle,
            border: Border.all(color: isDone ? color : AppColors.border, width: 2),
          ),
          child: Icon(icon, size: 14, color: isDone ? Colors.white : AppColors.textTertiary),
        ),
        if (!isLast)
          Container(width: 2, height: 28, color: isDone ? color.withOpacity(0.3) : AppColors.border),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: isDone ? AppColors.textPrimary : AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ]),
      )),
    ]);
  }
}
