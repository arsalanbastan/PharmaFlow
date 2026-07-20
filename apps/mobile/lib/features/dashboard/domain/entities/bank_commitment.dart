import 'package:freezed_annotation/freezed_annotation.dart';

import 'company_commitment.dart';

part 'bank_commitment.freezed.dart';
part 'bank_commitment.g.dart';

@freezed
class BankCommitment with _$BankCommitment {
  const factory BankCommitment({
    required int id,
    required String bankName,
    required int totalAmount,
    required int chequeCount,
    @Default(<CompanyCommitment>[])
    List<CompanyCommitment> companies,
  }) = _BankCommitment;

  factory BankCommitment.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$BankCommitmentFromJson(json);
}