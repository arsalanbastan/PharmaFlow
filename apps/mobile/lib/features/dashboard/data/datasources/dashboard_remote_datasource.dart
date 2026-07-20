import '../../domain/entities/dashboard.dart';

abstract interface class DashboardRemoteDataSource {
  Future<Dashboard> getDashboard();

  Future<void> syncDashboard(Dashboard dashboard);
}