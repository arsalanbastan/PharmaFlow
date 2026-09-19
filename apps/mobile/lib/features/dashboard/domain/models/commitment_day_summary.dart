class CommitmentDaySummary {
  final DateTime date;
  final int commitmentCount;
  final int totalAmount;

  const CommitmentDaySummary({
    required this.date,
    required this.commitmentCount,
    required this.totalAmount,
  });
}
