import 'package:freezed_annotation/freezed_annotation.dart';

part 'company_commitment.freezed.dart';
part 'company_commitment.g.dart';

@freezed
class CompanyCommitment with _$CompanyCommitment {
  const factory CompanyCommitment({
    required int id,
    required String companyName,
    required int totalAmount,
    required int chequeCount,
  }) = _CompanyCommitment;

  factory CompanyCommitment.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$CompanyCommitmentFromJson(json);
}