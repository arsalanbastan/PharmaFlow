enum SyncStatus { pending, synced, failed }

extension SyncStatusX on SyncStatus {
  String get dbValue => switch (this) {
    SyncStatus.pending => 'PENDING',
    SyncStatus.synced => 'SYNCED',
    SyncStatus.failed => 'FAILED',
  };

  static SyncStatus fromDbValue(String value) {
    switch (value.trim().toUpperCase()) {
      case 'PENDING':
        return SyncStatus.pending;
      case 'SYNCED':
        return SyncStatus.synced;
      case 'FAILED':
        return SyncStatus.failed;
    }

    throw ArgumentError.value(value, 'value', 'Invalid sync status');
  }
}
