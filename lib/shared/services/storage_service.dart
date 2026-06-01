import 'package:shared_preferences/shared_preferences.dart';

// Simple key-value storage using SharedPreferences.
// On mobile, consider upgrading to flutter_secure_storage for production.
class StorageService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _get() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<String?> read({required String key}) async {
    final prefs = await _get();
    return prefs.getString(key);
  }

  static Future<void> write({required String key, required String? value}) async {
    final prefs = await _get();
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  static Future<void> delete({required String key}) async {
    final prefs = await _get();
    await prefs.remove(key);
  }

  static Future<void> deleteAll() async {
    final prefs = await _get();
    await prefs.clear();
  }
}
