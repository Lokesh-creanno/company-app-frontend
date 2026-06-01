import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme.dart';

final taskDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final response = await api.get('/tasks/$id');
  return response.data['data'] as Map<String, dynamic>;
});

// ══════════════════════════════════════════════════════════════════════════════
//  Task Detail Screen — with Prev/Next navigation, admin verify, reassign
// ══════════════════════════════════════════════════════════════════════════════
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  final List<String> allIds;   // for prev/next navigation
  final int currentIndex;
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.allIds = const [],
    this.currentIndex = 0,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _updatingStatus = false;
  bool _verifying = false;
  bool _cancelling = false;

  // Navigate to prev or next task in the list
  void _navigate(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.allIds.length) return;
    final newId = widget.allIds[newIndex];
    context.go(
      '/tasks/$newId',
      extra: {'ids': widget.allIds, 'index': newIndex},
    );
  }

  bool get _hasPrev => widget.allIds.isNotEmpty && widget.currentIndex > 0;
  bool get _hasNext => widget.allIds.isNotEmpty && widget.currentIndex < widget.allIds.length - 1;

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await api.patch('/tasks/${widget.taskId}/status', data: {'status': status});
      ref.invalidate(taskDetailProvider(widget.taskId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'in_progress' ? '▶ Task started!' : '✅ Task marked complete!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _verifyAndClose() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify & Close Task'),
        content: const Text(
            'Mark this task as verified and officially closed? The assignee will be notified.'),
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
    setState(() => _verifying = true);
    try {
      await api.patch('/tasks/${widget.taskId}/status', data: {'status': 'verified'});
      ref.invalidate(taskDetailProvider(widget.taskId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Task verified and closed!'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      // fallback — some backends may not have 'verified', use 'completed'
      try {
        await api.patch('/tasks/${widget.taskId}/status', data: {'status': 'completed', 'adminVerified': true});
        ref.invalidate(taskDetailProvider(widget.taskId));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _cancelTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Task'),
        content: const Text('Are you sure you want to cancel this task? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Task')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Task'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await api.patch('/tasks/${widget.taskId}/status', data: {'status': 'cancelled'});
      ref.invalidate(taskDetailProvider(widget.taskId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task cancelled.'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showReassignDialog(Map<String, dynamic> task) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reassign Task'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the Employee ID of the new assignee:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Employee ID',
              hintText: 'e.g. EMP001',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await api.patch('/tasks/${widget.taskId}/reassign',
                    data: {'assignedTo': ctrl.text.trim()});
                ref.invalidate(taskDetailProvider(widget.taskId));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task reassigned!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed': case 'verified': return AppColors.success;
      case 'in_progress': return AppColors.primary;
      case 'cancelled': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final currentUser = ref.watch(authStateProvider).value;
    final isAdmin = currentUser?.isAdmin == true;
    final isManager = currentUser?.isManager == true || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Task Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (widget.allIds.isNotEmpty)
            Text('${widget.currentIndex + 1} of ${widget.allIds.length}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(taskDetailProvider(widget.taskId)),
          ),
          if (isManager)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'reassign') {
                  taskAsync.whenData((task) => _showReassignDialog(task));
                } else if (v == 'cancel') {
                  _cancelTask();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'reassign', child: Row(children: [
                  Icon(Icons.person_search_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 10), Text('Reassign Task'),
                ])),
                const PopupMenuItem(value: 'cancel', child: Row(children: [
                  Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                  SizedBox(width: 10), Text('Cancel Task', style: TextStyle(color: AppColors.error)),
                ])),
              ],
            ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(e.toString(), textAlign: TextAlign.center),
          TextButton(onPressed: () => ref.invalidate(taskDetailProvider(widget.taskId)), child: const Text('Retry')),
        ])),
        data: (task) {
          final assignee   = task['assignee'] as Map<String, dynamic>?;
          final creator    = task['creator'] as Map<String, dynamic>?;
          final comments   = (task['comments'] as List?) ?? [];
          final isAssignee = currentUser?.id == task['assignedTo'];
          final status     = task['status'] as String? ?? 'pending';

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [

                  // ── Task Header Card ─────────────────────────────────────
                  AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      // Priority indicator
                      Container(
                        width: 4, height: 48,
                        decoration: BoxDecoration(
                          color: task['priority'] == 'urgent' ? AppColors.error
                              : task['priority'] == 'high' ? AppColors.warning
                              : task['priority'] == 'medium' ? AppColors.primary
                              : AppColors.textTertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(task['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text((task['priority'] as String? ?? '').toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          ),
                        ]),
                      ])),
                    ]),

                    if (task['description'] != null && (task['description'] as String).isNotEmpty) ...[
                      const Divider(height: 20),
                      Text(task['description'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                    ],

                    const Divider(height: 20),
                    if (assignee != null)
                      _InfoRow(icon: Icons.person_outline, label: 'Assignee',
                          value: '${assignee['firstName'] ?? ''} ${assignee['lastName'] ?? ''}  ·  ${assignee['employeeId'] ?? ''}'),
                    if (creator != null)
                      _InfoRow(icon: Icons.supervisor_account_outlined, label: 'Created by',
                          value: '${creator['firstName'] ?? ''} ${creator['lastName'] ?? ''}'),
                    if (task['dueDate'] != null)
                      _InfoRow(icon: Icons.calendar_today, label: 'Due Date',
                          value: DateFormat('d MMM yyyy').format(DateTime.parse(task['dueDate']))),
                    if (task['estimatedHours'] != null)
                      _InfoRow(icon: Icons.timer_outlined, label: 'Estimated', value: '${task['estimatedHours']}h'),
                  ])),

                  const SizedBox(height: 16),

                  // ── Assignee Status Update ───────────────────────────────
                  if (isAssignee && status != 'completed' && status != 'cancelled' && status != 'verified') ...[
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Update Your Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (status == 'pending')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _updatingStatus ? null : () => _updateStatus('in_progress'),
                              icon: _updatingStatus
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start Working on This', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        if (status == 'in_progress')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _updatingStatus ? null : () => _updateStatus('completed'),
                              icon: _updatingStatus
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_rounded),
                              label: const Text('Mark as Completed', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                minimumSize: const Size(double.infinity, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Admin: Verify Completed Task ─────────────────────────
                  if (isManager && (status == 'completed') && !isAssignee) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.success.withOpacity(0.10), AppColors.success.withOpacity(0.03),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          const Text('Assignee marked this as complete',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.success)),
                        ]),
                        const SizedBox(height: 6),
                        const Text('Review the work and verify to officially close this task.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _verifying ? null : _verifyAndClose,
                            icon: _verifying
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.verified_rounded),
                            label: const Text('Verify & Close Task', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Comments ─────────────────────────────────────────────
                  Row(children: [
                    const Text('Comments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    if (comments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${comments.length}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    AppCard(child: const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(children: [
                        Icon(Icons.chat_bubble_outline, size: 36, color: AppColors.textTertiary),
                        SizedBox(height: 8),
                        Text('No comments yet', style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    ))),
                  ...comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CommentTile(comment: c as Map<String, dynamic>),
                  )),
                  const SizedBox(height: 12),
                  _CommentInput(
                    taskId: widget.taskId,
                    onSubmit: () => ref.invalidate(taskDetailProvider(widget.taskId)),
                  ),
                ],
              ),

              // ── Prev / Next Navigation Bar ────────────────────────────────
              if (widget.allIds.isNotEmpty)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.12))),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(children: [
                        // Previous button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _hasPrev ? () => _navigate(widget.currentIndex - 1) : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 20),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: _hasPrev ? AppColors.primary : AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${widget.currentIndex + 1} / ${widget.allIds.length}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Next button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _hasNext ? () => _navigate(widget.currentIndex + 1) : null,
                            icon: const Text('Next'),
                            label: const Icon(Icons.chevron_right_rounded, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.surfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textTertiary),
      const SizedBox(width: 8),
      SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
    ]),
  );
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 14, backgroundColor: AppColors.primary,
            child: Text((comment['name'] as String? ?? '?')[0],
                style: const TextStyle(color: Colors.white, fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(child: Text(comment['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Text(comment['createdAt'] != null
            ? DateFormat('d MMM, hh:mm a').format(DateTime.parse(comment['createdAt']))
            : '',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ]),
      const SizedBox(height: 8),
      Text(comment['message'] ?? '', style: const TextStyle(fontSize: 13)),
    ]),
  );
}

class _CommentInput extends ConsumerStatefulWidget {
  final String taskId;
  final VoidCallback onSubmit;
  const _CommentInput({required this.taskId, required this.onSubmit});
  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_ctrl.text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await api.post('/tasks/${widget.taskId}/comments', data: {'message': _ctrl.text});
      _ctrl.clear();
      widget.onSubmit();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        hintText: 'Add a comment...',
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, color: AppColors.primary),
        ),
      ),
      onSubmitted: (_) => _send(),
    )),
  ]);
}
