import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Enum ──────────────────────────────────────────────────────────────────────
enum AppThemeMode { light, dark, system }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode => switch (this) {
    AppThemeMode.light  => ThemeMode.light,
    AppThemeMode.dark   => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  String get label => switch (this) {
    AppThemeMode.light  => 'Light',
    AppThemeMode.dark   => 'Dark',
    AppThemeMode.system => 'Auto',
  };

  IconData get icon => switch (this) {
    AppThemeMode.light  => Icons.wb_sunny_rounded,
    AppThemeMode.dark   => Icons.dark_mode_rounded,
    AppThemeMode.system => Icons.brightness_auto_rounded,
  };

  String get _key => name; // 'light' | 'dark' | 'system'
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _prefKey = 'app_theme_mode';

  @override
  AppThemeMode build() {
    // Default: system. Async load from prefs on first frame.
    _loadFromPrefs();
    return AppThemeMode.system;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      final mode = AppThemeMode.values.firstWhere(
        (m) => m._key == saved,
        orElse: () => AppThemeMode.system,
      );
      state = mode;
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode._key);
  }

  void cycle() {
    final next = AppThemeMode.values[(state.index + 1) % AppThemeMode.values.length];
    setMode(next);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);
