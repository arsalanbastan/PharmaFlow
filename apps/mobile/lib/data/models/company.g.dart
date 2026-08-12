// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Company _$CompanyFromJson(Map<String, dynamic> json) => _Company(
  id: (json['id'] as num?)?.toInt(),
  serverUuid: json['serverUuid'] as String?,
  name: json['name'] as String,
  nationalId: json['nationalId'] as String?,
  economicCode: json['economicCode'] as String?,
  notes: json['notes'] as String?,
  visitorName: json['visitorName'] as String?,
  visitorPhone: json['visitorPhone'] as String?,
  accountantName: json['accountantName'] as String?,
  accountantPhone: json['accountantPhone'] as String?,
  archivedAt: json['archivedAt'] == null
      ? null
      : DateTime.parse(json['archivedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CompanyToJson(_Company instance) => <String, dynamic>{
  'id': instance.id,
  'serverUuid': instance.serverUuid,
  'name': instance.name,
  'nationalId': instance.nationalId,
  'economicCode': instance.economicCode,
  'notes': instance.notes,
  'visitorName': instance.visitorName,
  'visitorPhone': instance.visitorPhone,
  'accountantName': instance.accountantName,
  'accountantPhone': instance.accountantPhone,
  'archivedAt': instance.archivedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
