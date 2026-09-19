import '../models/cash_payment.dart';

class CashPaymentMapper {
  const CashPaymentMapper._();

  static CashPayment fromMap(Map<String, Object?> map) {
    return CashPayment(
      id: _optionalInt(map['id']),
      serverUuid: _optionalString(map['server_uuid']),
      amountRial: _requiredInt(map['amount_rial'], 'amount_rial'),
      paymentDate: _requiredDateTime(map['payment_date'], 'payment_date'),
      companyId: _requiredInt(map['company_id'], 'company_id'),
      bankAccountId: _requiredInt(map['bank_account_id'], 'bank_account_id'),
      paymentMethod: _paymentMethodFromDb(
        _requiredString(map['payment_method'], 'payment_method'),
      ),
      trackingNumber: _optionalString(map['tracking_number']),
      description: _optionalString(map['description']),
      notes: _optionalString(map['notes']),
      archivedAt: _optionalDateTime(map['archived_at']),
      deleteRequestedAt: _optionalDateTime(map['delete_requested_at']),
      deletedAt: _optionalDateTime(map['deleted_at']),
      createdAt: _requiredDateTime(map['created_at'], 'created_at'),
      updatedAt: _requiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  static Map<String, Object?> toMap(CashPayment payment) {
    return <String, Object?>{
      'id': payment.id,
      'server_uuid': payment.serverUuid,
      'amount_rial': payment.amountRial,
      'payment_date': payment.paymentDate.millisecondsSinceEpoch,
      'company_id': payment.companyId,
      'bank_account_id': payment.bankAccountId,
      'payment_method': paymentMethodToWireValue(payment.paymentMethod),
      'tracking_number': payment.trackingNumber,
      'description': payment.description,
      'notes': payment.notes,
      'archived_at': payment.archivedAt?.millisecondsSinceEpoch,
      'delete_requested_at': payment.deleteRequestedAt?.millisecondsSinceEpoch,
      'deleted_at': payment.deletedAt?.millisecondsSinceEpoch,
      'created_at': payment.createdAt.millisecondsSinceEpoch,
      'updated_at': payment.updatedAt.millisecondsSinceEpoch,
    };
  }

  static String paymentMethodToWireValue(CashPaymentMethod method) {
    switch (method) {
      case CashPaymentMethod.bankDeposit:
        return 'BANK_DEPOSIT';

      case CashPaymentMethod.posPayment:
        return 'POS_PAYMENT';
    }
  }

  static CashPaymentMethod _paymentMethodFromDb(String value) {
    switch (value.trim().toUpperCase()) {
      case 'BANK_DEPOSIT':
        return CashPaymentMethod.bankDeposit;

      case 'POS_PAYMENT':
        return CashPaymentMethod.posPayment;

      default:
        throw ArgumentError.value(
          value,
          'value',
          'Invalid cash payment method',
        );
    }
  }

  static int _requiredInt(Object? value, String field) {
    final parsed = _optionalInt(value);

    if (parsed == null) {
      throw StateError('CashPayment field "$field" is missing or invalid.');
    }

    return parsed;
  }

  static int? _optionalInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  static String _requiredString(Object? value, String field) {
    final parsed = _optionalString(value);

    if (parsed == null) {
      throw StateError('CashPayment field "$field" is missing.');
    }

    return parsed;
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static DateTime _requiredDateTime(Object? value, String field) {
    final parsed = _optionalDateTime(value);

    if (parsed == null) {
      throw StateError('CashPayment field "$field" is missing or invalid.');
    }

    return parsed;
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }

    if (value is String) {
      final asInteger = int.tryParse(value.trim());

      if (asInteger != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInteger, isUtc: true);
      }

      return DateTime.tryParse(value)?.toUtc();
    }

    return null;
  }
}
