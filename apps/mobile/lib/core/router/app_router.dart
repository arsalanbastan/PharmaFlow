import 'package:go_router/go_router.dart';

import '../../features/dashboard/domain/models/commitment_period.dart';
import '../../features/dashboard/presentation/pages/commitment_period_detail_page.dart';
import '../../features/dashboard/presentation/pages/jalali_commitment_calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_test_page.dart';
import '../../features/dashboard/presentation/pages/sync_failures_page.dart';
import '../../features/menu/presentation/pages/menu_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',

    routes: [
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      GoRoute(
        path: '/dashboard-test',
        name: 'dashboard-test',
        builder: (context, state) => const DashboardTestPage(),
      ),

      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),

      GoRoute(
        path: '/jalali-calendar',
        name: 'jalali-calendar',
        builder: (context, state) => const JalaliCommitmentCalendarPage(),
      ),

      GoRoute(
        path: '/sync-failures',
        name: 'sync-failures',
        builder: (context, state) => const SyncFailuresPage(),
      ),

      GoRoute(
        path: '/menu',
        name: 'menu',
        builder: (context, state) => const MenuPage(),
      ),

      GoRoute(
        path: '/commitment-period-detail',
        name: 'commitment-period-detail',

        builder: (context, state) {
          final period = state.extra as CommitmentPeriod;

          return CommitmentPeriodDetailPage(period: period);
        },
      ),
    ],
  );
}
