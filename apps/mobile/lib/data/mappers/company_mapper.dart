import '../models/company.dart';

class CompanyMapper {
  const CompanyMapper._();

  static Company fromMap(Map<String, Object?> map) {
    return Company(
      id: map['id'] as int?,
      serverUuid: map['server_uuid'] as String?,
      name: map['name'] as String,
      nationalId: map['national_id'] as String?,
      economicCode: map['economic_code'] as String?,
      bankName: map['bank_name'] as String?,
      accountNumber: map['account_number'] as String?,
      cardNumber: map['card_number'] as String?,
      shebaNumber: map['sheba_number'] as String?,
      notes: map['notes'] as String?,
      visitorName: map['visitor_name'] as String?,
      visitorPhone: map['visitor_phone'] as String?,
      accountantName: map['accountant_name'] as String?,
      accountantPhone: map['accountant_phone'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  static Map<String, Object?> toMap(Company company) {
    return {
      'id': company.id,
      'server_uuid': company.serverUuid,
      'name': company.name,
      'national_id': company.nationalId,
      'economic_code': company.economicCode,
      'bank_name': company.bankName,
      'account_number': company.accountNumber,
      'card_number': company.cardNumber,
      'sheba_number': company.shebaNumber,
      'notes': company.notes,
      'visitor_name': company.visitorName,
      'visitor_phone': company.visitorPhone,
      'accountant_name': company.accountantName,
      'accountant_phone': company.accountantPhone,
      'archived_at': company.archivedAt?.millisecondsSinceEpoch,
      'created_at': company.createdAt.millisecondsSinceEpoch,
      'updated_at': company.updatedAt.millisecondsSinceEpoch,
    };
  }
}
