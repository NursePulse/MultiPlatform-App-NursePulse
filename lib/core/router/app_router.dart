import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/audit/presentation/audit_log_list_view.dart';
import '../../features/clinical_event/presentation/clinical_event_list_view.dart';
import '../../features/dashboard/presentation/dashboard_view.dart';
import '../../features/iam/application/auth_notifier.dart';
import '../../features/iam/domain/user.dart';
import '../../features/iam/presentation/sign_in_view.dart';
import '../../features/iam/presentation/sign_up_view.dart';
import '../../features/iam/presentation/user_management_view.dart';
import '../../features/notification/presentation/alert_list_view.dart';
import '../../features/patient/presentation/patient_list_view.dart';
import '../../features/patient/presentation/patient_monitoring_view.dart';
import '../../features/report/presentation/report_list_view.dart';
import '../../features/sbar/presentation/sbar_list_view.dart';
import '../../features/subscriptions/presentation/subscription_plans_view.dart';
import '../../features/vital_sign/presentation/vital_sign_list_view.dart';
import '../../shared/widgets/app_shell.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) => notifyListeners());
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      if (auth.restoring) {
        return location == '/' ? null : '/';
      }

      final loggingIn = location == '/sign-in' || location == '/sign-up';

      if (!auth.isAuthenticated) {
        return loggingIn ? null : '/sign-in';
      }

      if (loggingIn || location == '/') return '/dashboard';

      final requiredRoles = switch (location) {
        '/audit' || '/reports' => [kRoleAdmin, kRoleDoctor],
        '/users' => [kRoleAdmin],
        _ => <String>[],
      };

      if (requiredRoles.isNotEmpty && !auth.user!.hasAnyRole(requiredRoles)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInView(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpView(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentPath: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardView(),
          ),
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientListView(),
          ),
          GoRoute(
            path: '/patients/:id/monitoring',
            builder: (context, state) =>
                PatientMonitoringView(patientId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/vital-signs',
            builder: (context, state) => const VitalSignListView(),
          ),
          GoRoute(
            path: '/clinical-events',
            builder: (context, state) => const ClinicalEventListView(),
          ),
          GoRoute(
            path: '/sbar',
            builder: (context, state) => const SbarListView(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) =>
                AlertListView(alertId: state.uri.queryParameters['alert']),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportListView(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditLogListView(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UserManagementView(),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionPlansView(),
          ),
        ],
      ),
    ],
  );
});
