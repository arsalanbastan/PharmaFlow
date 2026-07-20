// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_commitment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CompanyCommitment _$CompanyCommitmentFromJson(Map<String, dynamic> json) =>
    _CompanyCommitment(
      id: (json['id'] as num).toInt(),
      companyName: json['companyName'] as String,
      totalAmount: (json['totalAmount'] as num).toInt(),
      chequeCount: (json['chequeCount'] as num).toInt(),
    );

Map<String, dynamic> _$CompanyCommitmentToJson(_CompanyCommitment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'companyName': instance.companyName,
      'totalAmount': instance.totalAmount,
      'chequeCount': instance.chequeCount,
    };
