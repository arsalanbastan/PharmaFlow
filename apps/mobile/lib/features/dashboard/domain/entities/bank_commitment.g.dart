// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_commitment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BankCommitment _$BankCommitmentFromJson(Map<String, dynamic> json) =>
    _BankCommitment(
      id: (json['id'] as num).toInt(),
      bankName: json['bankName'] as String,
      totalAmount: (json['totalAmount'] as num).toInt(),
      chequeCount: (json['chequeCount'] as num).toInt(),
      companies:
          (json['companies'] as List<dynamic>?)
              ?.map(
                (e) => CompanyCommitment.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <CompanyCommitment>[],
    );

Map<String, dynamic> _$BankCommitmentToJson(_BankCommitment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bankName': instance.bankName,
      'totalAmount': instance.totalAmount,
      'chequeCount': instance.chequeCount,
      'companies': instance.companies,
    };
