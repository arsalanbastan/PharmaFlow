import 'dart:typed_data';

import '../models/cheque.dart';

class ChequeMapper {
  const ChequeMapper._();

  static Cheque fromMap(Map<String, Object?> map) {
    return Cheque(
      id: _toRequiredInt(map['id'], 'id'),
      serverUuid: map['server_uuid'] as String?,
      companyId: _toRequiredInt(map['company_id'], 'company_id'),
      bankAccountId: _toRequiredInt(map['bank_account_id'], 'bank_account_id'),
      chequeNumber: _toRequiredString(map['cheque_number'], 'cheque_number'),
      amountRial: _toRequiredInt(map['amount_rial'], 'amount_rial'),
      issueDate: _toRequiredDateTime(map['issue_date'], 'issue_date'),
      dueDate: _toRequiredDateTime(map['due_date'], 'due_date'),
      status: _statusFromDb(_toRequiredString(map['status'], 'status')),
      isRegisteredInSayad: _toBoolFlag(map['is_registered_in_sayad']),
      sayadId: map['sayad_id'] as String?,
      receiverName: map['receiver_name'] as String?,
      description: map['description'] as String?,
      archivedAt: map['archived_at'] == null
          ? null
          : _toRequiredDateTime(map['archived_at'], 'archived_at'),
      deleteRequestedAt: map['delete_requested_at'] == null
          ? null
          : _toRequiredDateTime(
              map['delete_requested_at'],
              'delete_requested_at',
            ),
      imageData: _imageDataFromDb(map['image_data']),
      createdAt: _toRequiredDateTime(map['created_at'], 'created_at'),
      updatedAt: _toRequiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  static Map<String, Object?> toMap(Cheque cheque) {
    return {
      'id': cheque.id,
      'server_uuid': cheque.serverUuid,
      'company_id': cheque.companyId,
      'bank_account_id': cheque.bankAccountId,
      'cheque_number': cheque.chequeNumber,
      'amount_rial': cheque.amountRial,
      'issue_date': cheque.issueDate.millisecondsSinceEpoch,
      'due_date': cheque.dueDate.millisecondsSinceEpoch,
      'status': _statusToDb(cheque.status),
      'is_registered_in_sayad': cheque.isRegisteredInSayad ? 1 : 0,
      'sayad_id': cheque.sayadId,
      'receiver_name': cheque.receiverName,
      'description': cheque.description,
      'archived_at': cheque.archivedAt?.millisecondsSinceEpoch,
      'delete_requested_at': cheque.deleteRequestedAt?.millisecondsSinceEpoch,
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

  static int _toRequiredInt(Object? value, String field) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    throw ArgumentError.value(value, field, 'Expected int-compatible value');
  }

  static String _toRequiredString(Object? value, String field) {
    if (value is String) {
      return value;
    }

    throw ArgumentError.value(value, field, 'Expected string value');
  }

  static DateTime _toRequiredDateTime(Object? value, String field) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String) {
      final trimmed = value.trim();
      final asEpoch = int.tryParse(trimmed);
      if (asEpoch != null) {
        return DateTime.fromMillisecondsSinceEpoch(asEpoch);
      }

      final asIso = DateTime.tryParse(trimmed);
      if (asIso != null) {
        return asIso;
      }
    }

    throw ArgumentError.value(
      value,
      field,
      'Expected epoch milliseconds or ISO date string',
    );
  }

  static bool _toBoolFlag(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value != 0;
    }

    if (value is num) {
      return value.toInt() != 0;
    }

    if (value is String) {
      final trimmed = value.trim().toLowerCase();
      if (trimmed == '1' || trimmed == 'true') {
        return true;
      }

      if (trimmed == '0' || trimmed == 'false') {
        return false;
      }
    }

    throw ArgumentError.value(
      value,
      'is_registered_in_sayad',
      'Expected bool/int/string flag value',
    );
  }
}
