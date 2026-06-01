import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_service.dart';
import 'package:intl/intl.dart';

/// Holds today's attendance record
final todayAttendanceProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    final response = await api.get('/attendance/my', params: {
      'month': DateTime.now().month.toString(),
      'year': DateTime.now().year.toString(),
    });
    final records = response.data['data']['records'] as List;
    final todayRecord = records.firstWhere(
      (r) => r['date'] == today,
      orElse: () => null,
    );
    return todayRecord as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

/// Attendance state notifier for check-in/out actions
class AttendanceNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AttendanceNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await api.get('/attendance/my', params: {
        'month': DateTime.now().month.toString(),
        'year': DateTime.now().year.toString(),
      });
      final records = response.data['data']['records'] as List;
      final todayRecord = records.firstWhere(
        (r) => r['date'] == today,
        orElse: () => null,
      );
      state = AsyncValue.data(todayRecord as Map<String, dynamic>?);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> checkIn({double? lat, double? lng}) async {
    final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await api.post('/attendance/check-in', data: {'lat': lat, 'lng': lng, 'localDate': localDate});
    await _load();
  }

  Future<Map<String, dynamic>> checkOut({double? lat, double? lng}) async {
    final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final response = await api.post('/attendance/check-out', data: {'lat': lat, 'lng': lng, 'localDate': localDate});
    await _load();
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> refresh() => _load();
}

final attendanceNotifierProvider =
    StateNotifierProvider.autoDispose<AttendanceNotifier, AsyncValue<Map<String, dynamic>?>>(
  (_) => AttendanceNotifier(),
);
