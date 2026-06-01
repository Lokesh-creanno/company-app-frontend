import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (xFile == null) return;

    setState(() => _uploading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(xFile.path, filename: 'profile.jpg'),
      });
      await api.postForm('/employees/${user.id}/photo', formData);
      await ref.read(authStateProvider.notifier).refreshUser();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated!'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white24,
                          backgroundImage: user.profilePhoto != null ? NetworkImage(user.profilePhoto!) : null,
                          child: user.profilePhoto == null ? Text('${user.firstName[0]}${user.lastName[0]}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)) : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _uploading ? null : _changePhoto,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: _uploading
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                  : const Icon(Icons.camera_alt, color: AppColors.primary, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(user.designation ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              AppCard(child: Column(children: [
                _ProfileRow(icon: Icons.badge_outlined, label: 'Member ID', value: user.employeeId),
                _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
                _ProfileRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phone ?? 'Not set'),
                _ProfileRow(icon: Icons.business_outlined, label: 'Department', value: user.department ?? 'N/A'),
                _ProfileRow(icon: Icons.work_outline, label: 'Designation', value: user.designation ?? 'N/A'),
                _ProfileRow(icon: Icons.security_outlined, label: 'Role', value: user.role.toUpperCase()),
                _ProfileRow(icon: Icons.calendar_today_outlined, label: 'Joined', value: user.joiningDate ?? 'N/A'),
                if (user.lastLogin != null)
                  _ProfileRow(icon: Icons.login, label: 'Last Login', value: DateFormat('d MMM yyyy, hh:mm a').format(user.lastLogin!), isLast: true),
              ])),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(authStateProvider.notifier).logout();
                  context.go('/login');
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 80),
            ])),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isLast;
  const _ProfileRow({required this.icon, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ])),
      ]),
    ),
    if (!isLast) const Divider(height: 1),
  ]);
}
