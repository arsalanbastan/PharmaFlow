import 'package:go_router/go_router.dart';

import '../../features/company/presentation/pages/company_list_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'companies',
        builder: (context, state) => const CompanyListPage(),
      ),
    ],
  );
}