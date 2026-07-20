// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_view_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DashboardViewModel _$DashboardViewModelFromJson(Map<String, dynamic> json) =>
    _DashboardViewModel(
      header: DashboardHeaderViewModel.fromJson(
        json['header'] as Map<String, dynamic>,
      ),
      checkStatus: CheckStatusViewModel.fromJson(
        json['checkStatus'] as Map<String, dynamic>,
      ),
      financialCommitments: FinancialCommitmentsViewModel.fromJson(
        json['financialCommitments'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$DashboardViewModelToJson(_DashboardViewModel instance) =>
    <String, dynamic>{
      'header': instance.header,
      'checkStatus': instance.checkStatus,
      'financialCommitments': instance.financialCommitments,
    };
