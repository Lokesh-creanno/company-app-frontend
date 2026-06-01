import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../core/theme.dart';

final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/notifications');
  return response.data['data'] as List;
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final response = await api.get('/notifications/unread-count');
  return response.data['data']['count'] as int;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await api.patch('/notifications/read-all');
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (notifications) {
          if (notifications.isEmpty) return const EmptyStateWidget(
            icon: Icons.notifications_none_outlined,
            title: 'No Notifications',
            subtitle: 'You\'re all caught up!',
          );

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (_, i) => _NotificationTile(
              notification: notifications[i] as Map<String, dynamic>,
              onTap: () async {
                if (notifications[i]['isRead'] == false) {
                  await api.patch('/notifications/${notifications[i]['id']}/read');
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification['type']) {
      case 'task': return Icons.task_outlined;
      case 'attendance': return Icons.access_time;
      case 'reimbursement': return Icons.receipt_long_outlined;
      case 'document': return Icons.folder_outlined;
      case 'reminder': return Icons.alarm;
      default: return Icons.notifications_outlined;
    }
  }

  Color get _color {
    switch (notification['type']) {
      case 'task': return AppColors.primary;
      case 'attendance': return AppColors.success;
      case 'reimbursement': return AppColors.warning;
      case 'document': return AppColors.accent;
      case 'reminder': return AppColors.info;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = notification['isRead'] == false;
    final createdAt = notification['createdAt'] != null
        ? DateTime.tryParse(notification['createdAt'])
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread ? _color.withOpacity(0.05) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread ? _color.withOpacity(0.2) : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(notification['title'] ?? '', style: TextStyle(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600, fontSize: 14))),
                      if (isUnread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 4),
                    Text(notification['body'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      createdAt != null ? _formatTime(createdAt) : '',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}
