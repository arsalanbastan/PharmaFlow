// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_header_view_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DashboardHeaderViewModel _$DashboardHeaderViewModelFromJson(
  Map<String, dynamic> json,
) => _DashboardHeaderViewModel(
  userName: json['userName'] as String,
  pharmacyName: json['pharmacyName'] as String,
  todayDate: json['todayDate'] as String,
);

Map<String, dynamic> _$DashboardHeaderViewModelToJson(
  _DashboardHeaderViewModel instance,
) => <String, dynamic>{
  'userName': instance.userName,
  'pharmacyName': instance.pharmacyName,
  'todayDate': instance.todayDate,
};
