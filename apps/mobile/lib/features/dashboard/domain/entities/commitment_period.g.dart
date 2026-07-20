// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commitment_period.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CommitmentPeriod _$CommitmentPeriodFromJson(Map<String, dynamic> json) =>
    _CommitmentPeriod(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      fromDate: json['fromDate'] as String,
      toDate: json['toDate'] as String,
      totalAmount: (json['totalAmount'] as num).toInt(),
      chequeCount: (json['chequeCount'] as num).toInt(),
      banks:
          (json['banks'] as List<dynamic>?)
              ?.map((e) => BankCommitment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <BankCommitment>[],
    );

Map<String, dynamic> _$CommitmentPeriodToJson(_CommitmentPeriod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'fromDate': instance.fromDate,
      'toDate': instance.toDate,
      'totalAmount': instance.totalAmount,
      'chequeCount': instance.chequeCount,
      'banks': instance.banks,
    };
