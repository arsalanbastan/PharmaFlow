import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_test_page.dart';
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
        builder: (context, state) =>
            const DashboardTestPage(),
      ),

      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),

      GoRoute(
        path: '/menu',
        name: 'menu',
        builder: (context, state) => const MenuPage(),
      ),
    ],
  );
}