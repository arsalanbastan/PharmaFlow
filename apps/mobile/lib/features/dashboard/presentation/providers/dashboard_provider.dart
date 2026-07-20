import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/dashboard_local_datasource.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard.dart';

/// ===============================================
/// DataSources
/// ===============================================

final dashboardLocalDataSourceProvider =
    Provider<DashboardLocalDataSource>((ref) {
  throw UnimplementedError(
    'DashboardLocalDataSource has not been implemented yet.',
  );
});

final dashboardRemoteDataSourceProvider =
    Provider<DashboardRemoteDataSource>((ref) {
  throw UnimplementedError(
    'DashboardRemoteDataSource has not been implemented yet.',
  );
});

/// ===============================================
/// Repository
/// ===============================================

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    localDataSource:
        ref.read(dashboardLocalDataSourceProvider),
    remoteDataSource:
        ref.read(dashboardRemoteDataSourceProvider),
  );
});

/// ===============================================
/// Dashboard
/// ===============================================

final dashboardProvider =
    FutureProvider<Dashboard>((ref) async {
  final repository =
      ref.read(dashboardRepositoryProvider);

  return repository.getDashboard();
});