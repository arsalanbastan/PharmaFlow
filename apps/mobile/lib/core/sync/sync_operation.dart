enum SyncOperation { create, update, delete }

extension SyncOperationX on SyncOperation {
  String get dbValue => switch (this) {
    SyncOperation.create => 'CREATE',
    SyncOperation.update => 'UPDATE',
    SyncOperation.delete => 'DELETE',
  };

  static SyncOperation fromDbValue(String value) {
    switch (value.trim().toUpperCase()) {
      case 'CREATE':
        return SyncOperation.create;
      case 'UPDATE':
        return SyncOperation.update;
      case 'DELETE':
        return SyncOperation.delete;
    }

    throw ArgumentError.value(value, 'value', 'Invalid sync operation');
  }
}
