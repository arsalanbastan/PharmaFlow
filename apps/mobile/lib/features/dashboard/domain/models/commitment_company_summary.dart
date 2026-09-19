class CommitmentChequeSummary {
  final String chequeNumber;
  final String bankAccount;
  final int amount;

  const CommitmentChequeSummary({
    required this.chequeNumber,
    required this.bankAccount,
    required this.amount,
  });
}

class CommitmentCompanySummary {
  final int companyId;
  final String companyName;
  final int chequeCount;
  final int totalAmount;
  final List<CommitmentChequeSummary> cheques;

  const CommitmentCompanySummary({
    required this.companyId,
    required this.companyName,
    required this.chequeCount,
    required this.totalAmount,
    required this.cheques,
  });
}
