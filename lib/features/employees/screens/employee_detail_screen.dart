import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme.dart';

final employeeDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final response = await api.get('/employees/$id');
  return response.data['data'] as Map<String, dynamic>;
});

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeDetailProvider(employeeId));
    final currentUser = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Member Profile'),
        actions: [
          if (currentUser?.isManager == true)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (emp) {
          return ListView(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white24,
                    backgroundImage: emp['profilePhoto'] != null ? CachedNetworkImageProvider(emp['profilePhoto']) : null,
                    child: emp['profilePhoto'] == null ? Text('${emp['firstName']?[0] ?? ''}${emp['lastName']?[0] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)) : null,
                  ),
                  const SizedBox(height: 12),
                  Text('${emp['firstName']} ${emp['lastName']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(emp['designation'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: Text(emp['employeeId'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  AppCard(child: Column(children: [
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: emp['email'] ?? ''),
                    _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: emp['phone'] ?? 'Not set'),
                    _InfoRow(icon: Icons.business_outlined, label: 'Department', value: emp['department'] ?? 'N/A'),
                    _InfoRow(icon: Icons.badge_outlined, label: 'Role', value: (emp['role'] as String?)?.toUpperCase() ?? ''),
                    _InfoRow(icon: Icons.calendar_today_outlined, label: 'Joining Date', value: emp['joiningDate'] != null ? DateFormat('d MMMM yyyy').format(DateTime.parse(emp['joiningDate'])) : 'N/A', isLast: true),
                  ])),
                  if (emp['manager'] != null) ...[
                    const SizedBox(height: 16),
                    const Text('Reporting Manager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    AppCard(
                      child: Row(children: [
                        CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.15), child: Text('${emp['manager']['firstName']?[0] ?? ''}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Text('${emp['manager']['firstName']} ${emp['manager']['lastName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                  if (currentUser?.isManager == true) ...[
                    const SizedBox(height: 16),
                    const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.folder_outlined, size: 18),
                        label: const Text('Documents'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.access_time_outlined, size: 18),
                        label: const Text('Attendance'),
                      )),
                    ]),
                  ],
                ]),
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
  final bool isLast;
  const _InfoRow({required this.icon, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ])),
        ]),
      ),
      if (!isLast) const Divider(height: 1),
    ],
  );
}
