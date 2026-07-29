import '../../domain/models/dashboard_summary.dart';
import '../../domain/models/tomorrow_commitment_summary.dart';
import '../../domain/models/commitment_period.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getDashboardSummary();

  Future<TomorrowCommitmentSummary> getTomorrowCommitments();

  Future<List<CommitmentPeriod>> getCommitmentPeriods();
}