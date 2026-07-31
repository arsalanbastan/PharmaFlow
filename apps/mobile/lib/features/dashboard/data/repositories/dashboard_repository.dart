import '../../domain/models/dashboard_summary.dart';
import '../../domain/models/tomorrow_commitment_summary.dart';
import '../../domain/models/commitment_period.dart';
import '../../domain/models/commitment_day_summary.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../../../data/models/cheque.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getDashboardSummary();

  Future<TomorrowCommitmentSummary> getTomorrowCommitments();

  Future<List<CommitmentPeriod>> getCommitmentPeriods();

  Future<List<CommitmentDaySummary>> getCommitmentDaysByPeriod(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<CommitmentCompanySummary>> getCommitmentCompaniesByDay(
    DateTime dayStart,
    DateTime dayEnd,
  );

  Future<List<Cheque>> getUnregisteredCheques();
}
