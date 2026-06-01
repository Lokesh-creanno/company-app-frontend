import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_service.dart';

class TaskNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  final String status;
  TaskNotifier({this.status = ''}) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final params = <String, dynamic>{};
      if (status.isNotEmpty) params['status'] = status;
      final response = await api.get('/tasks/my', params: params);
      state = AsyncValue.data(response.data['data'] as List);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateStatus(String taskId, String newStatus) async {
    await api.patch('/tasks/$taskId/status', data: {'status': newStatus});
    await loadTasks();
  }

  Future<void> refresh() => loadTasks();
}

final taskNotifierProvider = StateNotifierProvider.autoDispose
    .family<TaskNotifier, AsyncValue<List<dynamic>>, String>(
  (_, status) => TaskNotifier(status: status),
);

// Unread notification count badge
final unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final response = await api.get('/notifications/unread-count');
    return response.data['data']['count'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});
