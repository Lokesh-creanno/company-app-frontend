import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/attendance/screens/attendance_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/reimbursement/screens/reimbursement_screen.dart';
import '../features/reimbursement/screens/reimbursement_form_screen.dart';
import '../features/reimbursement/screens/expense_claim_screen.dart';
import '../features/reimbursement/screens/reimbursement_detail_screen.dart';
import '../features/documents/screens/documents_screen.dart';
import '../features/employees/screens/employees_screen.dart';
import '../features/employees/screens/employee_detail_screen.dart';
import '../features/admin/screens/admin_panel_screen.dart';
import '../features/admin/screens/ai_command_center_screen.dart';
import '../features/admin/screens/error_console_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../shared/widgets/main_shell.dart';
import '../features/auth/providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authStateProvider, (_, __) => notifier.notify());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/login') || loc.startsWith('/otp');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      if (loc.startsWith('/admin')) {
        final user = authState.valueOrNull;
        if (user == null || (!user.isAdmin && !user.isManager)) return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OTPScreen(email: state.extra as String),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),

          // ── Tasks: with prev/next list context ────────────────────────────
          GoRoute(
            path: '/tasks',
            builder: (_, __) => const TasksScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final ids = (extra?['ids'] as List?)?.cast<String>() ?? [];
                  final idx = (extra?['index'] as int?) ?? 0;
                  return TaskDetailScreen(
                    taskId: state.pathParameters['id']!,
                    allIds: ids,
                    currentIndex: idx,
                  );
                },
              ),
            ],
          ),

          // ── Reimbursements ────────────────────────────────────────────────
          GoRoute(
            path: '/reimbursements',
            builder: (_, __) => const ReimbursementScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const ReimbursementFormScreen()),
              GoRoute(path: 'expense-claim', builder: (_, __) => const ExpenseClaimScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) => ReimbursementDetailScreen(
                  reimbursementId: state.pathParameters['id']!,
                  initialData: state.extra as Map<String, dynamic>?,
                ),
              ),
            ],
          ),

          GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
          GoRoute(
            path: '/employees',
            builder: (_, __) => const EmployeesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    EmployeeDetailScreen(employeeId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/admin',
            builder: (_, __) => const AdminPanelScreen(),
            routes: [
              GoRoute(
                path: 'ai-hub',
                builder: (_, __) => const AiCommandCenterScreen(),
              ),
              GoRoute(
                path: 'error-console',
                builder: (_, __) => const ErrorConsoleScreen(),
              ),
            ],
          ),
          GoRoute(path: '/calendar', builder: (_, __) => const AgencyCalendarScreen()),
        ],
      ),
    ],
  );
});
