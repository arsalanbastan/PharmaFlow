// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cheque.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Cheque _$ChequeFromJson(Map<String, dynamic> json) => _Cheque(
  id: (json['id'] as num).toInt(),
  companyId: (json['companyId'] as num).toInt(),
  bankAccountId: (json['bankAccountId'] as num).toInt(),
  chequeNumber: json['chequeNumber'] as String,
  amountRial: (json['amountRial'] as num).toInt(),
  issueDate: DateTime.parse(json['issueDate'] as String),
  dueDate: DateTime.parse(json['dueDate'] as String),
  status: $enumDecode(_$ChequeStatusEnumMap, json['status']),
  isRegisteredInSayad: json['isRegisteredInSayad'] as bool,
  sayadId: json['sayadId'] as String?,
  receiverName: json['receiverName'] as String?,
  description: json['description'] as String?,
  archivedAt: json['archivedAt'] == null
      ? null
      : DateTime.parse(json['archivedAt'] as String),
  imageData: _imageDataFromJson(json['imageData'] as String?),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ChequeToJson(_Cheque instance) => <String, dynamic>{
  'id': instance.id,
  'companyId': instance.companyId,
  'bankAccountId': instance.bankAccountId,
  'chequeNumber': instance.chequeNumber,
  'amountRial': instance.amountRial,
  'issueDate': instance.issueDate.toIso8601String(),
  'dueDate': instance.dueDate.toIso8601String(),
  'status': _$ChequeStatusEnumMap[instance.status]!,
  'isRegisteredInSayad': instance.isRegisteredInSayad,
  'sayadId': instance.sayadId,
  'receiverName': instance.receiverName,
  'description': instance.description,
  'archivedAt': instance.archivedAt?.toIso8601String(),
  'imageData': _imageDataToJson(instance.imageData),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$ChequeStatusEnumMap = {
  ChequeStatus.issued: 'issued',
  ChequeStatus.registered: 'registered',
  ChequeStatus.cancelled: 'cancelled',
};
