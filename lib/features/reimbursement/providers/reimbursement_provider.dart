import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_service.dart';

class ReimbursementNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  ReimbursementNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final response = await api.get('/reimbursements/my');
      state = AsyncValue.data(response.data['data'] as List);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  /// Summary totals
  Map<String, dynamic> get summary {
    final list = state.value ?? [];
    final total = list.fold<double>(0, (acc, r) => acc + double.parse(r['amount'].toString()));
    return {
      'count': list.length,
      'total': total,
      'pending': list.where((r) => r['status'] == 'pending').length,
      'approved': list.where((r) => r['status'] == 'approved' || r['status'] == 'paid').length,
      'rejected': list.where((r) => r['status'] == 'rejected').length,
    };
  }
}

final reimbursementProvider =
    StateNotifierProvider.autoDispose<ReimbursementNotifier, AsyncValue<List<dynamic>>>(
  (_) => ReimbursementNotifier(),
);

// For managers/admins — all reimbursements
final allReimbursementsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/reimbursements');
  return response.data['data'] as List;
});
