import 'package:flutter/foundation.dart' show kIsWeb;
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
    // ── Web demo mode: auto-login as demo admin with REAL backend token ──
    // Calls /auth/demo-login on the live backend to get a real JWT.
    // Result: every API call from the web demo is authenticated and works
    // end-to-end against the real Railway backend + Supabase database.
    if (kIsWeb) {
      try {
        // If we already have a cached token, just verify it's still valid
        final cached = await StorageService.read(key: AppConstants.accessTokenKey);
        if (cached != null) {
          try {
            final meResp = await api.get('/auth/me');
            return UserModel.fromJson(meResp.data['data']);
          } catch (_) {
            // Cached token expired/invalid — fall through to demo-login
            await StorageService.deleteAll();
          }
        }

        // Fetch a fresh demo session
        final response = await api.post('/auth/demo-login', data: {});
        final data = response.data['data'];
        await StorageService.write(
            key: AppConstants.accessTokenKey,  value: data['accessToken']);
        await StorageService.write(
            key: AppConstants.refreshTokenKey, value: data['refreshToken']);
        return UserModel.fromJson(data['user']);
      } catch (e) {
        // If backend is unreachable, still show the UI with a stub user
        return UserModel(
          id:          'demo-fallback',
          employeeId:  'EMP-DEMO',
          firstName:   'Demo',
          lastName:    'Admin',
          email:       'demo@creanno.com',
          role:        'admin',
          department:  'Operations',
          designation: 'Owner',
        );
      }
    }

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
    // Web demo: ignore logout — keeps the public demo always-on
    if (kIsWeb) return;

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
