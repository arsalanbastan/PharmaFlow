import 'package:freezed_annotation/freezed_annotation.dart';

part 'financial_commitments_view_model.freezed.dart';
part 'financial_commitments_view_model.g.dart';

@freezed
class FinancialCommitmentsViewModel
    with _$FinancialCommitmentsViewModel {
  const factory FinancialCommitmentsViewModel({
    required List<CommitmentPeriodViewModel> periods,
  }) = _FinancialCommitmentsViewModel;

  factory FinancialCommitmentsViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$FinancialCommitmentsViewModelFromJson(json);
}

@freezed
class CommitmentPeriodViewModel
    with _$CommitmentPeriodViewModel {
  const factory CommitmentPeriodViewModel({
    required String title,
    required String fromDate,
    required String toDate,
    required int totalAmount,
    required int chequeCount,
    required List<BankCommitmentViewModel> banks,
  }) = _CommitmentPeriodViewModel;

  factory CommitmentPeriodViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$CommitmentPeriodViewModelFromJson(json);
}

@freezed
class BankCommitmentViewModel
    with _$BankCommitmentViewModel {
  const factory BankCommitmentViewModel({
    required String bankName,
    required int totalAmount,
    required int chequeCount,
    required List<CompanyCommitmentViewModel> companies,
  }) = _BankCommitmentViewModel;

  factory BankCommitmentViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$BankCommitmentViewModelFromJson(json);
}

@freezed
class CompanyCommitmentViewModel
    with _$CompanyCommitmentViewModel {
  const factory CompanyCommitmentViewModel({
    required String companyName,
    required int totalAmount,
    required int chequeCount,
  }) = _CompanyCommitmentViewModel;

  factory CompanyCommitmentViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$CompanyCommitmentViewModelFromJson(json);
}