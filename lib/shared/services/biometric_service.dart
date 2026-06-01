import 'storage_service.dart';

// Biometric authentication is not supported on Windows desktop.
// On mobile, re-enable local_auth in pubspec.yaml and restore the
// full implementation.

enum BiometricType { fingerprint, face, iris, strong, weak }

class BiometricService {
  /// Returns true if biometric hardware is available and enrolled
  static Future<bool> isAvailable() async => false;

  /// Authenticates the user with biometrics
  static Future<bool> authenticate({String reason = 'Confirm your identity to log in'}) async => false;

  /// Check if biometric login is enabled by the user
  static Future<bool> isBiometricLoginEnabled() async {
    final val = await StorageService.read(key: 'biometric_login_enabled');
    return val == 'true';
  }

  /// Enable or disable biometric login
  static Future<void> setBiometricLogin(bool enabled) async {
    await StorageService.write(key: 'biometric_login_enabled', value: enabled.toString());
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async => [];
}
