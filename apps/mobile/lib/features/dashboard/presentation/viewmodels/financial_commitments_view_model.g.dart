// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_commitments_view_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FinancialCommitmentsViewModel _$FinancialCommitmentsViewModelFromJson(
  Map<String, dynamic> json,
) => _FinancialCommitmentsViewModel(
  periods: (json['periods'] as List<dynamic>)
      .map((e) => CommitmentPeriodViewModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$FinancialCommitmentsViewModelToJson(
  _FinancialCommitmentsViewModel instance,
) => <String, dynamic>{'periods': instance.periods};

_CommitmentPeriodViewModel _$CommitmentPeriodViewModelFromJson(
  Map<String, dynamic> json,
) => _CommitmentPeriodViewModel(
  title: json['title'] as String,
  fromDate: json['fromDate'] as String,
  toDate: json['toDate'] as String,
  totalAmount: (json['totalAmount'] as num).toInt(),
  chequeCount: (json['chequeCount'] as num).toInt(),
  banks: (json['banks'] as List<dynamic>)
      .map((e) => BankCommitmentViewModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CommitmentPeriodViewModelToJson(
  _CommitmentPeriodViewModel instance,
) => <String, dynamic>{
  'title': instance.title,
  'fromDate': instance.fromDate,
  'toDate': instance.toDate,
  'totalAmount': instance.totalAmount,
  'chequeCount': instance.chequeCount,
  'banks': instance.banks,
};

_BankCommitmentViewModel _$BankCommitmentViewModelFromJson(
  Map<String, dynamic> json,
) => _BankCommitmentViewModel(
  bankName: json['bankName'] as String,
  totalAmount: (json['totalAmount'] as num).toInt(),
  chequeCount: (json['chequeCount'] as num).toInt(),
  companies: (json['companies'] as List<dynamic>)
      .map(
        (e) => CompanyCommitmentViewModel.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$BankCommitmentViewModelToJson(
  _BankCommitmentViewModel instance,
) => <String, dynamic>{
  'bankName': instance.bankName,
  'totalAmount': instance.totalAmount,
  'chequeCount': instance.chequeCount,
  'companies': instance.companies,
};

_CompanyCommitmentViewModel _$CompanyCommitmentViewModelFromJson(
  Map<String, dynamic> json,
) => _CompanyCommitmentViewModel(
  companyName: json['companyName'] as String,
  totalAmount: (json['totalAmount'] as num).toInt(),
  chequeCount: (json['chequeCount'] as num).toInt(),
);

Map<String, dynamic> _$CompanyCommitmentViewModelToJson(
  _CompanyCommitmentViewModel instance,
) => <String, dynamic>{
  'companyName': instance.companyName,
  'totalAmount': instance.totalAmount,
  'chequeCount': instance.chequeCount,
};
