import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/constants.dart';

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // Same on web and mobile now: if we have a valid token show the user,
    // otherwise show the login screen. (No more web auto demo-login.)
    final token = await StorageService.read(key: AppConstants.accessTokenKey);
    if (token == null) return null;
    try {
      final response = await api.get('/auth/me');
      return UserModel.fromJson(response.data['data']);
    } catch (_) {
      await StorageService.deleteAll();
      return null;
    }
  }

  // ── Password login (email + password) ──────────────────────────────────────
  Future<void> loginWithPassword(String email, String password) async {
    state = const AsyncLoading();
    try {
      final response = await api.post('/auth/login',
          data: {'email': email.trim().toLowerCase(), 'password': password});
      final data = response.data['data'];
      await StorageService.write(key: AppConstants.accessTokenKey, value: data['accessToken']);
      await StorageService.write(key: AppConstants.refreshTokenKey, value: data['refreshToken']);
      state = AsyncData(UserModel.fromJson(data['user']));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> sendOTP(String email) async {
    await api.post('/auth/send-otp', data: {'email': email});
  }

  Future<void> verifyOTP(String email, String otp) async {
    state = const AsyncLoading();
    try {
      final response = await api.post('/auth/verify-otp', data: {'email': email, 'otp': otp});
      final data = response.data['data'];
      await StorageService.write(key: AppConstants.accessTokenKey, value: data['accessToken']);
      await StorageService.write(key: AppConstants.refreshTokenKey, value: data['refreshToken']);

      final user = UserModel.fromJson(data['user']);
      state = AsyncData(user);

      // Register FCM token
      try {
        final fcmToken = await NotificationService.getToken();
        if (fcmToken != null) await api.patch('/auth/fcm-token', data: {'fcmToken': fcmToken});
      } catch (_) {}
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await StorageService.deleteAll();
    state = const AsyncData(null);
  }

  Future<void> refreshUser() async {
    try {
      final response = await api.get('/auth/me');
      state = AsyncData(UserModel.fromJson(response.data['data']));
    } catch (_) {}
  }
}
