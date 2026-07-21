class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountTitle,
    required this.accountHolder,
    required this.accountNumber,
    required this.cardNumber,
    required this.iban,
    this.note,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  final String bankName;

  final String accountTitle;

  final String accountHolder;

  final String accountNumber;

  final String cardNumber;

  final String iban;

  final String? note;

  final DateTime? archivedAt;

  final DateTime createdAt;

  final DateTime updatedAt;
}