import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

// Super Admin control center: create / list / view-password / archive users.
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  bool _loading = true;
  bool _includeArchived = false;
  String? _err;
  String _query = '';
  List<Map<String, dynamic>> _users = [];

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final hay = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''} '
              '${u['email'] ?? ''} ${u['role'] ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final res = await api.get('/admin/users',
          params: {'includeArchived': _includeArchived});
      _users = (res.data['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _err = _msg(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _msg(Object e) {
    if (e is DioException) {
      return e.response?.data?['message']?.toString() ??
          'Cannot reach server. Is the backend running?';
    }
    return 'Something went wrong.';
  }

  void _toast(String m, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _archive(Map<String, dynamic> u, bool archive) async {
    try {
      await api.post('/admin/users/${u['id']}/${archive ? 'archive' : 'unarchive'}');
      _toast(archive ? 'User archived' : 'User restored');
      _load();
    } catch (e) {
      _toast(_msg(e), ok: false);
    }
  }

  Future<void> _viewPassword(Map<String, dynamic> u) async {
    try {
      final res = await api.get('/admin/users/${u['id']}/password');
      final pw = res.data['data']['password']?.toString() ?? '(none)';
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u['email']?.toString() ?? '',
                  style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13)),
              const SizedBox(height: 12),
              SelectableText(pw,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      _toast(_msg(e), ok: false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(existing: existing),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          IconButton(
            tooltip: _includeArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(_includeArchived ? Icons.visibility_off_rounded : Icons.archive_rounded),
            onPressed: () { setState(() => _includeArchived = !_includeArchived); _load(); },
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New user'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? _ErrorState(message: _err!, onRetry: _load)
              : Column(
                  children: [
                    // Search box
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search name, email or role…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Signed in as ${me?.email ?? ''} · '
                          '${_filtered.length} of ${_users.length} users',
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context), fontSize: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? const _EmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _UserTile(
                                  user: _filtered[i],
                                  onViewPassword: () => _viewPassword(_filtered[i]),
                                  onEdit: () => _openForm(existing: _filtered[i]),
                                  onArchive: (a) => _archive(_filtered[i], a),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── One user row ─────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onViewPassword;
  final VoidCallback onEdit;
  final void Function(bool archive) onArchive;
  const _UserTile({
    required this.user,
    required this.onViewPassword,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final archived = user['isArchived'] == true;
    final role = (user['role'] ?? 'employee').toString();
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return Opacity(
      opacity: archived ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _roleColor(role).withOpacity(0.15),
              child: Text(
                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(name.isEmpty ? '(no name)' : name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    _RoleChip(role: role),
                    if (archived) ...[
                      const SizedBox(width: 6),
                      _RoleChip(role: 'archived'),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(user['email']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context), fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'password') onViewPassword();
                if (v == 'edit') onEdit();
                if (v == 'archive') onArchive(true);
                if (v == 'restore') onArchive(false);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'password', child: Text('View password')),
                const PopupMenuItem(value: 'edit', child: Text('Edit / reset password')),
                if (!archived)
                  const PopupMenuItem(value: 'archive', child: Text('Archive'))
                else
                  const PopupMenuItem(value: 'restore', child: Text('Restore')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'super_admin': return AppColors.accent;
    case 'accounts':    return AppColors.secondary;
    case 'admin':
    case 'manager':     return AppColors.primary;
    case 'archived':    return AppColors.textTertiary;
    default:            return AppColors.success;
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});
  @override
  Widget build(BuildContext context) {
    final c = _roleColor(role);
    final label = role == 'super_admin' ? 'SUPER ADMIN' : role.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c, letterSpacing: 0.4)),
    );
  }
}

// ─── Create / edit dialog ─────────────────────────────────────────────────────
class _UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _UserFormDialog({this.existing});
  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _department = TextEditingController();
  final _designation = TextEditingController();
  String _role = 'employee';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _first.text = e['firstName']?.toString() ?? '';
      _last.text = e['lastName']?.toString() ?? '';
      _email.text = e['email']?.toString() ?? '';
      _department.text = e['department']?.toString() ?? '';
      _designation.text = e['designation']?.toString() ?? '';
      final r = (e['role'] ?? 'employee').toString();
      _role = ['accounts', 'employee', 'admin', 'manager'].contains(r) ? r : 'employee';
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _password, _department, _designation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'role': _role,
        'department': _department.text.trim(),
        'designation': _designation.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
      };
      if (_isEdit) {
        await api.patch('/admin/users/${widget.existing!['id']}', data: body);
      } else {
        body['email'] = _email.text.trim().toLowerCase();
        await api.post('/admin/users', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final m = e is DioException
          ? (e.response?.data?['message']?.toString() ?? 'Save failed')
          : 'Save failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit user' : 'New user'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _field(_first, 'First name', req: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_last, 'Last name', req: true)),
                ]),
                const SizedBox(height: 12),
                _field(_email, 'Email', req: !_isEdit, enabled: !_isEdit,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                      labelText: _isEdit
                          ? 'New password (leave blank to keep)'
                          : 'Password'),
                  validator: (v) {
                    final val = v ?? '';
                    if (!_isEdit && val.isEmpty) return 'Required';
                    if (val.isNotEmpty && val.length < 6) {
                      return 'At least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Team member')),
                    DropdownMenuItem(value: 'accounts', child: Text('Accounts (finance)')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'employee'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_department, 'Department')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_designation, 'Designation')),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool req = false, bool enabled = true, TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      enabled: enabled,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.group_off_rounded, size: 56, color: AppColors.textTertiaryOf(context)),
          const SizedBox(height: 12),
          Center(
            child: Text('No users yet. Tap "New user" to add one.',
                style: TextStyle(color: AppColors.textSecondaryOf(context))),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(child: FilledButton(onPressed: onRetry, child: const Text('Retry'))),
        ],
      );
}
