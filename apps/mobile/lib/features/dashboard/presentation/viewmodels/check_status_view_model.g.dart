// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_status_view_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CheckStatusViewModel _$CheckStatusViewModelFromJson(
  Map<String, dynamic> json,
) => _CheckStatusViewModel(
  banks: (json['banks'] as List<dynamic>)
      .map((e) => BankTodayCheckViewModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalTodayCommitments: (json['totalTodayCommitments'] as num).toInt(),
);

Map<String, dynamic> _$CheckStatusViewModelToJson(
  _CheckStatusViewModel instance,
) => <String, dynamic>{
  'banks': instance.banks,
  'totalTodayCommitments': instance.totalTodayCommitments,
};

_BankTodayCheckViewModel _$BankTodayCheckViewModelFromJson(
  Map<String, dynamic> json,
) => _BankTodayCheckViewModel(
  bankName: json['bankName'] as String,
  totalAmount: (json['totalAmount'] as num).toInt(),
  chequeCount: (json['chequeCount'] as num).toInt(),
);

Map<String, dynamic> _$BankTodayCheckViewModelToJson(
  _BankTodayCheckViewModel instance,
) => <String, dynamic>{
  'bankName': instance.bankName,
  'totalAmount': instance.totalAmount,
  'chequeCount': instance.chequeCount,
};
