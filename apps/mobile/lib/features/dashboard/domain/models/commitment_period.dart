class CommitmentPeriod {
  final String title;

  final DateTime startDate;

  final DateTime endDate;

  final int commitmentCount;

  final int totalAmount;

  const CommitmentPeriod({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.commitmentCount,
    required this.totalAmount,
  });
}