import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_header_view_model.freezed.dart';
part 'dashboard_header_view_model.g.dart';

@freezed
class DashboardHeaderViewModel with _$DashboardHeaderViewModel {
  const factory DashboardHeaderViewModel({
    required String userName,
    required String pharmacyName,
    required String todayDate,
  }) = _DashboardHeaderViewModel;

  factory DashboardHeaderViewModel.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$DashboardHeaderViewModelFromJson(json);
}