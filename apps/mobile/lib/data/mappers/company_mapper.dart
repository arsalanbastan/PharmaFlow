import '../models/company.dart';

class CompanyMapper {
  const CompanyMapper._();

  static Company fromMap(Map<String, Object?> map) {
    return Company(
      id: map['id'] as int?,
      name: map['name'] as String,
      nationalId: map['national_id'] as String?,
      economicCode: map['economic_code'] as String?,
      notes: map['notes'] as String?,
      visitorName: map['visitor_name'] as String?,
      visitorPhone: map['visitor_phone'] as String?,
      accountantName: map['accountant_name'] as String?,
      accountantPhone: map['accountant_phone'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['archived_at'] as int,
            ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int,
      ),
    );
  }

  static Map<String, Object?> toMap(Company company) {
    return {
      'id': company.id,
      'name': company.name,
      'national_id': company.nationalId,
      'economic_code': company.economicCode,
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