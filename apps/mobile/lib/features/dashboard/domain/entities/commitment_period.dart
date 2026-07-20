import 'package:freezed_annotation/freezed_annotation.dart';

import 'bank_commitment.dart';

part 'commitment_period.freezed.dart';
part 'commitment_period.g.dart';

@freezed
class CommitmentPeriod with _$CommitmentPeriod {
  const factory CommitmentPeriod({
    required int id,

    /// مثال:
    /// ۵ مرداد ۱۴۰۵
    required String title,

    required String fromDate,

    required String toDate,

    required int totalAmount,

    required int chequeCount,

    @Default(<BankCommitment>[])
    List<BankCommitment> banks,
  }) = _CommitmentPeriod;

  factory CommitmentPeriod.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$CommitmentPeriodFromJson(json);
}