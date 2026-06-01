// Firebase / push notification support is disabled on Windows desktop.
// On mobile, re-enable firebase_core, firebase_messaging, and
// flutter_local_notifications in pubspec.yaml and restore the full
// implementation.

class NotificationService {
  static Future<void> initialize() async {
    // no-op on desktop
  }

  static Future<String?> getToken() async => null;
}
