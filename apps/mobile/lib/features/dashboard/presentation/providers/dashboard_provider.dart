import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/sqlite_dashboard_repository.dart';
import '../../domain/models/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) {
    return SqliteDashboardRepository();
  },
);


final dashboardSummaryProvider =
    FutureProvider<DashboardSummary>(
  (ref) async {
    final repository = ref.watch(
      dashboardRepositoryProvider,
    );

    return repository.getDashboardSummary();
  },
);