import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─── Error Entry Model ────────────────────────────────────────────────────────

class AppErrorEntry {
  final String id;
  final DateTime timestamp;
  final String message;
  final String stackSummary; // first 4 lines only
  final String category;    // flutter | api | ui | unknown
  final bool isRead;
  final bool isResolved;

  const AppErrorEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.stackSummary,
    required this.category,
    this.isRead = false,
    this.isResolved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'stackSummary': stackSummary,
    'category': category,
    'isRead': isRead,
    'isResolved': isResolved,
  };

  factory AppErrorEntry.fromJson(Map<String, dynamic> j) => AppErrorEntry(
    id:           j['id'] as String,
    timestamp:    DateTime.parse(j['timestamp'] as String),
    message:      j['message'] as String,
    stackSummary: j['stackSummary'] as String? ?? '',
    category:     j['category'] as String? ?? 'unknown',
    isRead:       j['isRead'] as bool? ?? false,
    isResolved:   j['isResolved'] as bool? ?? false,
  );

  AppErrorEntry copyWith({bool? isRead, bool? isResolved}) => AppErrorEntry(
    id: id, timestamp: timestamp, message: message,
    stackSummary: stackSummary, category: category,
    isRead: isRead ?? this.isRead,
    isResolved: isResolved ?? this.isResolved,
  );

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM, h:mm a').format(timestamp);
  }
}

// ─── Error Log Service ────────────────────────────────────────────────────────

class ErrorLogService {
  static const _storageKey = 'creanno_error_log_v2';
  static const _maxEntries = 50;

  // ── Log a new error ────────────────────────────────────────────────────────
  static Future<void> logError({
    required String message,
    String? stackTrace,
    String category = 'unknown',
  }) async {
    try {
      // Ignore very short/noise messages
      if (message.trim().length < 8) return;

      final entry = AppErrorEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        message: _truncate(message, 300),
        stackSummary: _summarizeStack(stackTrace),
        category: category,
      );

      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_storageKey);
      final list  = raw != null
          ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      list.insert(0, entry.toJson());
      // Keep only latest N entries
      if (list.length > _maxEntries) list.removeRange(_maxEntries, list.length);

      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (_) {
      // Never throw from error logger
    }
  }

  // ── Get all errors ─────────────────────────────────────────────────────────
  static Future<List<AppErrorEntry>> getErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_storageKey);
      if (raw == null) return [];
      final list  = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(AppErrorEntry.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Unread count (for badge) ───────────────────────────────────────────────
  static Future<int> getUnreadCount() async {
    final errors = await getErrors();
    return errors.where((e) => !e.isRead && !e.isResolved).length;
  }

  // ── Mark error as read ─────────────────────────────────────────────────────
  static Future<void> markRead(String id) async {
    await _updateEntry(id, isRead: true);
  }

  // ── Mark error as resolved ─────────────────────────────────────────────────
  static Future<void> markResolved(String id) async {
    await _updateEntry(id, isRead: true, isResolved: true);
  }

  // ── Mark all read ──────────────────────────────────────────────────────────
  static Future<void> markAllRead() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final errors  = await getErrors();
      final updated = errors.map((e) => e.copyWith(isRead: true).toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(updated));
    } catch (_) {}
  }

  // ── Clear all errors ───────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  // ── Detect category from error message ────────────────────────────────────
  static String detectCategory(String message) {
    final m = message.toLowerCase();
    if (m.contains('dio') || m.contains('http') || m.contains('socket') ||
        m.contains('connection') || m.contains('api') || m.contains('network')) {
      return 'api';
    }
    if (m.contains('flutter') || m.contains('widget') || m.contains('renderflex') ||
        m.contains('overflow') || m.contains('build') || m.contains('layout')) {
      return 'ui';
    }
    if (m.contains('null') || m.contains('type') || m.contains('cast') ||
        m.contains('format') || m.contains('parse')) {
      return 'data';
    }
    return 'app';
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static Future<void> _updateEntry(String id, {bool? isRead, bool? isResolved}) async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final errors = await getErrors();
      final updated = errors.map((e) {
        if (e.id == id) return e.copyWith(isRead: isRead, isResolved: isResolved);
        return e;
      }).map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(updated));
    } catch (_) {}
  }

  static String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;

  static String _summarizeStack(String? stack) {
    if (stack == null || stack.isEmpty) return '';
    final lines = stack.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
    return lines.join('\n');
  }
}
