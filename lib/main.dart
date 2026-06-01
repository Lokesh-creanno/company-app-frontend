import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/router.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/error_log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global Flutter error capture ─────────────────────────────────────────
  // Catches widget build errors, overflow, null pointer, etc.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    final cat = ErrorLogService.detectCategory(msg);
    ErrorLogService.logError(
      message: msg,
      stackTrace: details.stack?.toString(),
      category: cat,
    );
    // Still show errors in debug mode
    FlutterError.presentError(details);
  };

  // Catches async errors that escape the Flutter framework
  runZonedGuarded(
    () async {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ));

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      try {
        await NotificationService.initialize();
      } catch (_) {
        // Notifications optional — app works without them
      }

      runApp(const ProviderScope(child: CompanyApp()));
    },
    (error, stack) {
      final msg = error.toString();
      ErrorLogService.logError(
        message: msg,
        stackTrace: stack.toString(),
        category: ErrorLogService.detectCategory(msg),
      );
    },
  );
}

class CompanyApp extends ConsumerWidget {
  const CompanyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final appMode   = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CREANNO',
      theme:      AppTheme.lightTheme,
      darkTheme:  AppTheme.darkTheme,
      themeMode:  appMode.themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Keep system UI in sync with current theme
        final isDark = Theme.of(context).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
    );
  }
}
