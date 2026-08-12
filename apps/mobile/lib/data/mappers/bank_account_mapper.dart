import '../models/bank_account.dart';

class BankAccountMapper {
  const BankAccountMapper._();

  static Map<String, Object?> toMap(BankAccount account) {
    return {
      'id': account.id,
      'server_uuid': account.serverUuid,
      'bank_name': account.bankName,
      'account_title': account.accountTitle,
      'account_holder': account.accountHolder,
      'account_number': account.accountNumber,
      'card_number': account.cardNumber,
      'iban': account.iban,
      'note': account.note,
      'archived_at': account.archivedAt?.millisecondsSinceEpoch,
      'created_at': account.createdAt.millisecondsSinceEpoch,
      'updated_at': account.updatedAt.millisecondsSinceEpoch,
    };
  }

  static BankAccount fromMap(Map<String, Object?> map) {
    return BankAccount(
      id: map['id'] as int?,
      serverUuid: map['server_uuid'] as String?,
      bankName: map['bank_name'] as String,
      accountTitle: map['account_title'] as String,
      accountHolder: map['account_holder'] as String,
      accountNumber: map['account_number'] as String,
      cardNumber: map['card_number'] as String,
      iban: map['iban'] as String,
      note: map['note'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
