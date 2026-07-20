import 'package:freezed_annotation/freezed_annotation.dart';

import 'check_status_view_model.dart';
import 'dashboard_header_view_model.dart';
import 'financial_commitments_view_model.dart';

part 'dashboard_view_model.freezed.dart';
part 'dashboard_view_model.g.dart';

@freezed
class DashboardViewModel with _$DashboardViewModel {
  const factory DashboardViewModel({
    required DashboardHeaderViewModel header,
    required CheckStatusViewModel checkStatus,
    required FinancialCommitmentsViewModel financialCommitments,
  }) = _DashboardViewModel;

  factory DashboardViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$DashboardViewModelFromJson(json);
}