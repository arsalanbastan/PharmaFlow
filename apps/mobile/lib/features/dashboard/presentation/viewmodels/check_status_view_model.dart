import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_status_view_model.freezed.dart';
part 'check_status_view_model.g.dart';

@freezed
class CheckStatusViewModel with _$CheckStatusViewModel {
  const factory CheckStatusViewModel({
    required List<BankTodayCheckViewModel> banks,
    required int totalTodayCommitments,
  }) = _CheckStatusViewModel;

  factory CheckStatusViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$CheckStatusViewModelFromJson(json);
}

@freezed
class BankTodayCheckViewModel with _$BankTodayCheckViewModel {
  const factory BankTodayCheckViewModel({
    required String bankName,
    required int totalAmount,
    required int chequeCount,
  }) = _BankTodayCheckViewModel;

  factory BankTodayCheckViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$BankTodayCheckViewModelFromJson(json);
}