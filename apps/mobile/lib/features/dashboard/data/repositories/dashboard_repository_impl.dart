import '../../domain/entities/dashboard.dart';
import '../datasources/dashboard_local_datasource.dart';
import '../datasources/dashboard_remote_datasource.dart';
import 'dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required DashboardLocalDataSource localDataSource,
    required DashboardRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  final DashboardLocalDataSource _localDataSource;
  final DashboardRemoteDataSource _remoteDataSource;

  @override
  Future<Dashboard> getDashboard() async {
    try {
      final dashboard = await _remoteDataSource.getDashboard();

      await _localDataSource.saveDashboard(dashboard);

      return dashboard;
    } catch (_) {
      return _localDataSource.getDashboard();
    }
  }
}