// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Dashboard _$DashboardFromJson(Map<String, dynamic> json) => _Dashboard(
  userName: json['userName'] as String,
  pharmacyName: json['pharmacyName'] as String,
  todayDate: json['todayDate'] as String,
  totalTodayCommitments: (json['totalTodayCommitments'] as num).toInt(),
  todayChecks:
      (json['todayChecks'] as List<dynamic>?)
          ?.map((e) => TodayCheck.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TodayCheck>[],
  commitmentPeriods:
      (json['commitmentPeriods'] as List<dynamic>?)
          ?.map((e) => CommitmentPeriod.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CommitmentPeriod>[],
);

Map<String, dynamic> _$DashboardToJson(_Dashboard instance) =>
    <String, dynamic>{
      'userName': instance.userName,
      'pharmacyName': instance.pharmacyName,
      'todayDate': instance.todayDate,
      'totalTodayCommitments': instance.totalTodayCommitments,
      'todayChecks': instance.todayChecks,
      'commitmentPeriods': instance.commitmentPeriods,
    };
