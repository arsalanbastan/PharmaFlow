import '../../domain/entities/dashboard.dart';

abstract interface class DashboardLocalDataSource {
  Future<Dashboard> getDashboard();

  Future<void> saveDashboard(Dashboard dashboard);
}