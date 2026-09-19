import 'tomorrow_commitment_summary.dart';
import 'commitment_period.dart';
import 'dashboard_warning.dart';

class DashboardSummary {
  final TomorrowCommitmentSummary tomorrow;
  final List<CommitmentPeriod> periods;
  final List<DashboardWarning> warnings;

  const DashboardSummary({
    required this.tomorrow,
    required this.periods,
    required this.warnings,
  });
}