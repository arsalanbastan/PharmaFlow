import 'sync_operation.dart';
import 'sync_status.dart';

class SyncQueueItem {
  const SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.status,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  final int? id;
  final String entityType;
  final int entityId;
  final SyncOperation operation;
  final SyncStatus status;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation.dbValue,
      'status': status.dbValue,
      'retryCount': retryCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastAttemptAt': lastAttemptAt?.millisecondsSinceEpoch,
      'errorMessage': errorMessage,
    };
  }

  factory SyncQueueItem.fromDbMap(Map<String, Object?> map) {
    return SyncQueueItem(
      id: _toInt(map['id']),
      entityType: _toString(map['entityType']),
      entityId: _toInt(map['entityId']) ?? 0,
      operation: SyncOperationX.fromDbValue(_toString(map['operation'])),
      status: SyncStatusX.fromDbValue(_toString(map['status'])),
      retryCount: _toInt(map['retryCount']) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(map['createdAt']) ?? 0,
      ),
      lastAttemptAt: _toDateTime(map['lastAttemptAt']),
      errorMessage: _toStringOrNull(map['errorMessage']),
    );
  }
}

const String syncEntityTypeCheque = 'CHEQUE';
const String syncEntityTypeCompany = 'COMPANY';
const String syncEntityTypeBankAccount = 'BANK_ACCOUNT';

int? _toInt(Object? value) {
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

String _toString(Object? value) {
  if (value is String) {
    return value;
  }

  if (value == null) {
    throw ArgumentError.value(value, 'value', 'Expected string value');
  }

  return value.toString();
}

String? _toStringOrNull(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _toDateTime(Object? value) {
  final millis = _toInt(value);
  if (millis == null) {
    return null;
  }

  return DateTime.fromMillisecondsSinceEpoch(millis);
}
