import '../models/cash_payment_attachment.dart';

class CashPaymentAttachmentMapper {
  const CashPaymentAttachmentMapper._();

  static CashPaymentAttachment fromMap(Map<String, Object?> map) {
    return CashPaymentAttachment(
      id: _optionalInt(map['id']),
      serverUuid: _optionalString(map['server_uuid']),
      cashPaymentId: _requiredInt(map['cash_payment_id'], 'cash_payment_id'),
      kind: kindFromWireValue(_requiredString(map['kind'], 'kind')),
      fileName: _requiredString(map['file_name'], 'file_name'),
      mimeType: _requiredString(map['mime_type'], 'mime_type'),
      originalFileSize: _optionalInt(map['original_file_size']),
      fileSize: _requiredInt(map['file_size'], 'file_size'),
      sha256: _requiredString(map['sha256'], 'sha256').toLowerCase(),
      localPath: _optionalString(map['local_path']),
      storageKey: _optionalString(map['storage_key']),
      deleteRequestedAt: _optionalDateTime(map['delete_requested_at']),
      deletedAt: _optionalDateTime(map['deleted_at']),
      createdAt: _requiredDateTime(map['created_at'], 'created_at'),
      updatedAt: _requiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  static Map<String, Object?> toMap(CashPaymentAttachment attachment) {
    return <String, Object?>{
      'id': attachment.id,
      'server_uuid': attachment.serverUuid,
      'cash_payment_id': attachment.cashPaymentId,
      'kind': kindToWireValue(attachment.kind),
      'file_name': attachment.fileName,
      'mime_type': attachment.mimeType,
      'original_file_size': attachment.originalFileSize,
      'file_size': attachment.fileSize,
      'sha256': attachment.sha256.toLowerCase(),
      'local_path': attachment.localPath,
      'storage_key': attachment.storageKey,
      'delete_requested_at':
          attachment.deleteRequestedAt?.millisecondsSinceEpoch,
      'deleted_at': attachment.deletedAt?.millisecondsSinceEpoch,
      'created_at': attachment.createdAt.millisecondsSinceEpoch,
      'updated_at': attachment.updatedAt.millisecondsSinceEpoch,
    };
  }

  static String kindToWireValue(CashPaymentAttachmentKind kind) {
    switch (kind) {
      case CashPaymentAttachmentKind.receipt:
        return 'RECEIPT';

      case CashPaymentAttachmentKind.statement:
        return 'STATEMENT';
    }
  }

  static CashPaymentAttachmentKind kindFromWireValue(String value) {
    switch (value.trim().toUpperCase()) {
      case 'RECEIPT':
        return CashPaymentAttachmentKind.receipt;

      case 'STATEMENT':
        return CashPaymentAttachmentKind.statement;

      default:
        throw ArgumentError.value(
          value,
          'value',
          'Invalid cash payment attachment kind',
        );
    }
  }

  static int _requiredInt(Object? value, String field) {
    final parsed = _optionalInt(value);

    if (parsed == null) {
      throw StateError(
        'CashPaymentAttachment field '
        '"$field" is missing or invalid.',
      );
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
      throw StateError(
        'CashPaymentAttachment field '
        '"$field" is missing or invalid.',
      );
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
      throw StateError(
        'CashPaymentAttachment field '
        '"$field" is missing or invalid.',
      );
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
      final normalized = value.trim();

      final millis = int.tryParse(normalized);

      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }

      return DateTime.tryParse(normalized)?.toUtc();
    }

    return null;
  }
}
