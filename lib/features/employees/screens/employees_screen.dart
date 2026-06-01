import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';

final employeesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, search) async {
  final params = <String, dynamic>{};
  if (search.isNotEmpty) params['search'] = search;
  final response = await api.get('/employees', params: params);
  return response.data['data'] as List;
});

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});
  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final empAsync = ref.watch(employeesProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Team Members')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, email, ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: empAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (employees) {
                if (employees.isEmpty) return const Center(child: Text('No team members found'));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  itemBuilder: (_, i) => _EmployeeTile(emp: employees[i] as Map<String, dynamic>),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Map<String, dynamic> emp;
  const _EmployeeTile({required this.emp});

  @override
  Widget build(BuildContext context) {
    final initials = '${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}';
    return AppCard(
      onTap: () => context.go('/employees/${emp['id']}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage: emp['profilePhoto'] != null ? CachedNetworkImageProvider(emp['profilePhoto']) : null,
            child: emp['profilePhoto'] == null ? Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${emp['firstName']} ${emp['lastName']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(emp['designation'] ?? emp['department'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(emp['employeeId'] ?? '', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: emp['role'] == 'admin' ? AppColors.error.withOpacity(0.1) : emp['role'] == 'manager' ? AppColors.warning.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (emp['role'] as String? ?? '').toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: emp['role'] == 'admin' ? AppColors.error : emp['role'] == 'manager' ? AppColors.warning : AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: emp['isActive'] == true ? AppColors.success : AppColors.textTertiary, shape: BoxShape.circle)),
          ]),
        ],
      ),
    );
  }
}
