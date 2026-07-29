class TomorrowCommitmentSummary {
  final bool hasCommitment;
  final List<BankCommitment> bankCommitments;

  const TomorrowCommitmentSummary({
    required this.hasCommitment,
    required this.bankCommitments,
  });
}


class BankCommitment {
  final String bankName;
  final int amount;

  const BankCommitment({
    required this.bankName,
    required this.amount,
  });
}