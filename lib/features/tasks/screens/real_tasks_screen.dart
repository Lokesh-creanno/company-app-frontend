import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Tasks, backed by the server.
///
/// The previous screen was a calendar mock: it kept everything in memory and
/// never called the API, so a task vanished on reload. This one reads and
/// writes real tasks.

String _taskError(Object e) {
  if (e is DioException) {
    return e.response?.data?['message']?.toString() ??
        'Cannot reach the server. Check your connection.';
  }
  return 'Something went wrong.';
}

/// Tasks assigned to me.
final myTasksProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await api.get('/tasks/my');
  return (res.data['data'] as List?) ?? const [];
});

/// Tasks I handed out (a super admin sees every task).
final assignedTasksProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await api.get('/tasks/assigned');
  return (res.data['data'] as List?) ?? const [];
});

/// People a task can be given to.
final assignableUsersProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await api.get('/employees', params: {'limit': 100});
  return (res.data['data'] as List?) ?? const [];
});

const _statuses = ['pending', 'in_progress', 'completed', 'verified'];

Color _priorityColor(String p) => switch (p) {
      'urgent' => AppColors.error,
      'high' => AppColors.warning,
      'low' => AppColors.success,
      _ => AppColors.info,
    };

Color _statusColor(String s) => switch (s) {
      'completed' || 'verified' => AppColors.success,
      'in_progress' => AppColors.info,
      'cancelled' => AppColors.error,
      _ => AppColors.warning,
    };

String _pretty(String s) =>
    s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

class RealTasksScreen extends ConsumerStatefulWidget {
  const RealTasksScreen({super.key});
  @override
  ConsumerState<RealTasksScreen> createState() => _RealTasksScreenState();
}

class _RealTasksScreenState extends ConsumerState<RealTasksScreen> {
  bool _showAssigned = false;
  String _filter = 'all';

  bool _canAssign(String? role) =>
      role == 'super_admin' || role == 'admin' || role == 'manager';

  void _refresh() {
    ref.invalidate(myTasksProvider);
    ref.invalidate(assignedTasksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final canAssign = _canAssign(user?.role);
    final async =
        ref.watch(_showAssigned ? assignedTasksProvider : myTasksProvider);

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
        ],
      ),
      floatingActionButton: canAssign
          ? FloatingActionButton.extended(
              onPressed: _newTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New task'),
            )
          : null,
      body: Column(children: [
        if (canAssign)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('My tasks')),
                ButtonSegment(value: true, label: Text('Given out')),
              ],
              selected: {_showAssigned},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _showAssigned = s.first),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', ..._statuses].map((s) {
                final on = _filter == s;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(s == 'all' ? 'All' : _pretty(s)),
                    selected: on,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_taskError(e), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ]),
            ),
            data: (all) {
              final tasks = _filter == 'all'
                  ? all
                  : all.where((t) => t['status'] == _filter).toList();
              if (tasks.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(children: [
                    const SizedBox(height: 120),
                    Icon(Icons.task_alt_rounded,
                        size: 54, color: AppColors.textTertiaryOf(context)),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _showAssigned
                            ? 'No tasks given out yet'
                            : 'No tasks for you',
                        style:
                            TextStyle(color: AppColors.textSecondaryOf(context)),
                      ),
                    ),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TaskCard(
                    task: Map<String, dynamic>.from(tasks[i] as Map),
                    onOpen: () => _openTask(
                        Map<String, dynamic>.from(tasks[i] as Map)),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSheet(task: task),
    );
    _refresh();
  }

  Future<void> _newTask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTaskSheet(),
    );
    if (created == true) _refresh();
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onOpen;
  const _TaskCard({required this.task, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final status = (task['status'] ?? 'pending').toString();
    final priority = (task['priority'] ?? 'medium').toString();
    final assignee = task['assignee'] as Map?;
    final due = DateTime.tryParse('${task['dueDate']}');
    final overdue = due != null &&
        due.isBefore(DateTime.now()) &&
        status != 'completed' &&
        status != 'verified';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: _priorityColor(priority),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${task['title'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(_pretty(status).toUpperCase(),
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: _statusColor(status))),
            ),
          ]),
          const SizedBox(height: 7),
          Row(children: [
            if (assignee != null) ...[
              Icon(Icons.person_outline_rounded,
                  size: 13, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 3),
              Text(
                  '${assignee['firstName'] ?? ''} ${assignee['lastName'] ?? ''}'
                      .trim(),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(context))),
              const SizedBox(width: 12),
            ],
            if (due != null) ...[
              Icon(Icons.event_rounded,
                  size: 13,
                  color: overdue
                      ? AppColors.error
                      : AppColors.textSecondaryOf(context)),
              const SizedBox(width: 3),
              Text(DateFormat('d MMM').format(due),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: overdue ? FontWeight.w700 : FontWeight.w400,
                      color: overdue
                          ? AppColors.error
                          : AppColors.textSecondaryOf(context))),
              if (overdue) ...[
                const SizedBox(width: 5),
                const Text('OVERDUE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error)),
              ],
            ],
            const Spacer(),
            Text(_pretty(priority),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor(priority))),
          ]),
        ]),
      ),
    );
  }
}

/// One task: what it is, and the buttons to move it along.
class _TaskSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> task;
  const _TaskSheet({required this.task});
  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late String _status = (widget.task['status'] ?? 'pending').toString();
  bool _busy = false;

  Future<void> _setStatus(String s) async {
    setState(() => _busy = true);
    try {
      await api.patch('/tasks/${widget.task['id']}/status', data: {'status': s});
      if (!mounted) return;
      setState(() { _status = s; _busy = false; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task marked ${_pretty(s).toLowerCase()}')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_taskError(e)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final assignee = t['assignee'] as Map?;
    final due = DateTime.tryParse('${t['dueDate']}');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: AppColors.borderOf(context),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('${t['title'] ?? ''}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if ('${t['description'] ?? ''}'.isNotEmpty)
              Text('${t['description']}',
                  style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondaryOf(context))),
            const SizedBox(height: 14),
            Wrap(spacing: 18, runSpacing: 8, children: [
              _Bit(
                  label: 'Assigned to',
                  value: assignee == null
                      ? '—'
                      : '${assignee['firstName'] ?? ''} ${assignee['lastName'] ?? ''}'
                          .trim()),
              _Bit(
                  label: 'Due',
                  value: due == null ? '—' : DateFormat('d MMM yyyy').format(due)),
              _Bit(
                  label: 'Priority',
                  value: _pretty('${t['priority'] ?? 'medium'}')),
              _Bit(label: 'Status', value: _pretty(_status)),
            ]),
            const Divider(height: 26),
            Text('Move this task',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondaryOf(context))),
            const SizedBox(height: 8),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses
                    .where((s) => s != _status)
                    .map((s) => OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38)),
                          onPressed: () => _setStatus(s),
                          child: Text(_pretty(s)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bit extends StatelessWidget {
  final String label;
  final String value;
  const _Bit({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.textSecondaryOf(context))),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
}

/// Hand a task to someone.
class _NewTaskSheet extends ConsumerStatefulWidget {
  const _NewTaskSheet();
  @override
  ConsumerState<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<_NewTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _assignee;
  String _priority = 'medium';
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_assignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick who this task is for'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      await api.post('/tasks', data: {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'assignedTo': _assignee,
        'priority': _priority,
        'dueDate': DateFormat('yyyy-MM-dd').format(_due),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task created')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_taskError(e)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(assignableUsersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: EdgeInsets.fromLTRB(
                18, 10, 18, MediaQuery.of(context).viewInsets.bottom + 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.borderOf(context),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('New task',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Details (optional)'),
              ),
              const SizedBox(height: 12),
              people.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(_taskError(e),
                    style: const TextStyle(color: AppColors.error)),
                data: (list) => DropdownButtonFormField<String>(
                  value: _assignee,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: list.map<DropdownMenuItem<String>>((u) {
                    final m = Map<String, dynamic>.from(u as Map);
                    final name =
                        '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
                    return DropdownMenuItem(
                      value: m['id'].toString(),
                      child: Text(
                          name.isEmpty ? '${m['email']}' : '$name · ${m['role']}',
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _assignee = v),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const ['low', 'medium', 'high', 'urgent']
                    .map((p) =>
                        DropdownMenuItem(value: p, child: Text(_pretty(p))))
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _due,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _due = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due date'),
                  child: Text(DateFormat('EEEE, d MMM yyyy').format(_due)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving…' : 'Create task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
