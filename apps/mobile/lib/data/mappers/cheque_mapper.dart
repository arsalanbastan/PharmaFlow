import 'dart:typed_data';

import '../models/cheque.dart';

class ChequeMapper {
  const ChequeMapper._();

  static Cheque fromMap(Map<String, Object?> map) {
    return Cheque(
      id: map['id'] as int,
      companyId: map['company_id'] as int,
      bankAccountId: map['bank_account_id'] as int,
      chequeNumber: map['cheque_number'] as String,
      amountRial: map['amount_rial'] as int,
      issueDate: DateTime.fromMillisecondsSinceEpoch(
        map['issue_date'] as int,
      ),
      dueDate: DateTime.fromMillisecondsSinceEpoch(
        map['due_date'] as int,
      ),
      status: _statusFromDb(map['status'] as String),
      isRegisteredInSayad: (map['is_registered_in_sayad'] as int) == 1,
      receiverName: map['receiver_name'] as String?,
      description: map['description'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['archived_at'] as int,
            ),
      imageData: _imageDataFromDb(map['image_data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int,
      ),
    );
  }

  static Map<String, Object?> toMap(Cheque cheque) {
    return {
      'id': cheque.id,
      'company_id': cheque.companyId,
      'bank_account_id': cheque.bankAccountId,
      'cheque_number': cheque.chequeNumber,
      'amount_rial': cheque.amountRial,
      'issue_date': cheque.issueDate.millisecondsSinceEpoch,
      'due_date': cheque.dueDate.millisecondsSinceEpoch,
      'status': _statusToDb(cheque.status),
      'is_registered_in_sayad': cheque.isRegisteredInSayad ? 1 : 0,
      'receiver_name': cheque.receiverName,
      'description': cheque.description,
      'archived_at': cheque.archivedAt?.millisecondsSinceEpoch,
      'image_data': cheque.imageData,
      'created_at': cheque.createdAt.millisecondsSinceEpoch,
      'updated_at': cheque.updatedAt.millisecondsSinceEpoch,
    };
  }

  static ChequeStatus _statusFromDb(String value) {
    switch (value) {
      case 'Issued':
        return ChequeStatus.issued;
      case 'Registered':
        return ChequeStatus.registered;
      case 'Cancelled':
        return ChequeStatus.cancelled;
    }

    throw ArgumentError.value(value, 'value', 'Invalid cheque status');
  }

  static String _statusToDb(ChequeStatus status) {
    switch (status) {
      case ChequeStatus.issued:
        return 'Issued';
      case ChequeStatus.registered:
        return 'Registered';
      case ChequeStatus.cancelled:
        return 'Cancelled';
    }
  }

  static Uint8List? _imageDataFromDb(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is Uint8List) {
      return value;
    }

    if (value is List<int>) {
      return Uint8List.fromList(value);
    }

    throw ArgumentError.value(value, 'value', 'Invalid image data payload');
  }
}