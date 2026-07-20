// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'today_check.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TodayCheck _$TodayCheckFromJson(Map<String, dynamic> json) => _TodayCheck(
  bankId: (json['bankId'] as num).toInt(),
  bankName: json['bankName'] as String,
  totalAmount: (json['totalAmount'] as num).toInt(),
  chequeCount: (json['chequeCount'] as num).toInt(),
);

Map<String, dynamic> _$TodayCheckToJson(_TodayCheck instance) =>
    <String, dynamic>{
      'bankId': instance.bankId,
      'bankName': instance.bankName,
      'totalAmount': instance.totalAmount,
      'chequeCount': instance.chequeCount,
    };
