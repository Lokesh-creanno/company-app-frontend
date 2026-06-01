import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/constants.dart';

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());

/// Demo admin user — used ONLY on web build (public demo).
/// Mobile builds still go through the real OTP login flow.
final _demoWebUser = UserModel(
  id:           'demo-web-admin',
  employeeId:   'EMP-DEMO',
  firstName:    'Demo',
  lastName:     'Admin',
  email:        'demo@creanno.com',
  phone:        '+91 00000 00000',
  role:         'admin',
  department:   'Operations',
  designation:  'Owner',
  profilePhoto: null,
);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // ── Web demo mode: skip login completely ────────────────────────────
    if (kIsWeb) {
      return _demoWebUser;
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
