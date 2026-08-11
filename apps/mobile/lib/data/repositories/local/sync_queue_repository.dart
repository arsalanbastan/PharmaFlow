import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/queries/sync_queue_queries.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/sync/sync_status.dart';

class SyncQueueRepository {
  SyncQueueRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  Future<int> add(SyncQueueItem item) async {
    final params = _namedParams(item.toDbMap()..remove('id'));
    final statement = _db.prepare(SyncQueueQueries.insert);

    try {
      statement.executeWith(StatementParameters.named(params));
      final insertedId =
          _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
      return insertedId;
    } finally {
      statement.dispose();
    }
  }

  Future<List<SyncQueueItem>> getPending() async {
    final statement = _db.prepare(SyncQueueQueries.findPending);

    late final ResultSet rows;
    try {
      rows = statement.selectWith(
        StatementParameters.named(
          _namedParams({'status': SyncStatus.pending.dbValue}),
        ),
      );
    } finally {
      statement.dispose();
    }

    return rows.map((row) => SyncQueueItem.fromDbMap(row)).toList();
  }

  Future<List<SyncQueueItem>> getProcessable() async {
    final statement = _db.prepare(SyncQueueQueries.findProcessable);

    late final ResultSet rows;
    try {
      rows = statement.selectWith(
        StatementParameters.named(
          _namedParams({
            'pendingStatus': SyncStatus.pending.dbValue,
            'failedStatus': SyncStatus.failed.dbValue,
          }),
        ),
      );
    } finally {
      statement.dispose();
    }

    return rows.map((row) => SyncQueueItem.fromDbMap(row)).toList();
  }

  Future<List<SyncQueueItem>> getFailedItems() async {
    final statement = _db.prepare(SyncQueueQueries.findFailedNewest);

    late final ResultSet rows;
    try {
      rows = statement.selectWith(
        StatementParameters.named({':status': SyncStatus.failed.dbValue}),
      );
    } finally {
      statement.dispose();
    }

    return rows.map((row) => SyncQueueItem.fromDbMap(row)).toList();
  }

  Future<List<SyncQueueItem>> getAllItems() async {
    final statement = _db.prepare(SyncQueueQueries.findAllNewest);

    late final ResultSet rows;
    try {
      rows = statement.select();
    } finally {
      statement.dispose();
    }

    return rows.map((row) => SyncQueueItem.fromDbMap(row)).toList();
  }

  Future<SyncQueueItem?> findById(int id) async {
    final statement = _db.prepare(SyncQueueQueries.findById);

    try {
      final rows = statement.selectWith(StatementParameters.named({':id': id}));
      if (rows.isEmpty) {
        return null;
      }
      return SyncQueueItem.fromDbMap(rows.first);
    } finally {
      statement.dispose();
    }
  }

  Future<int> countAll() async {
    final row = _db.select(SyncQueueQueries.countAll).first;
    return _toInt(row['total']);
  }

  Future<int> countByStatus(SyncStatus status) async {
    final statement = _db.prepare(SyncQueueQueries.countByStatus);

    try {
      final rows = statement.selectWith(
        StatementParameters.named(_namedParams({'status': status.dbValue})),
      );
      return _toInt(rows.first['total']);
    } finally {
      statement.dispose();
    }
  }

  Future<void> markSynced(int id) async {
    final statement = _db.prepare(SyncQueueQueries.markSynced);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':id': id,
          ':status': SyncStatus.synced.dbValue,
          ':lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> markProcessing(int id) async {
    final statement = _db.prepare(SyncQueueQueries.markProcessing);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':id': id,
          ':status': SyncStatus.processing.dbValue,
          ':lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> markFailed(int id, {String? errorMessage}) async {
    final statement = _db.prepare(SyncQueueQueries.markFailed);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':id': id,
          ':status': SyncStatus.failed.dbValue,
          ':lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
          ':errorMessage': errorMessage,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> retryQueueItem(int id) async {
    final statement = _db.prepare(SyncQueueQueries.retryById);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':id': id,
          ':status': SyncStatus.pending.dbValue,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> deleteQueueItem(int id) async {
    final statement = _db.prepare(SyncQueueQueries.deleteById);

    try {
      statement.executeWith(StatementParameters.named({':id': id}));
    } finally {
      statement.dispose();
    }
  }

  Future<void> resetProcessingToPending() async {
    final statement = _db.prepare(SyncQueueQueries.resetProcessingToPending);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':pendingStatus': SyncStatus.pending.dbValue,
          ':processingStatus': SyncStatus.processing.dbValue,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> addChequeCreated(int chequeId) async {
    await addChequeEvent(chequeId, operation: SyncOperation.create);
  }

  Future<void> addChequeUpdated(int chequeId) async {
    await enqueueUpdateWithMerge(
      entityType: syncEntityTypeCheque,
      entityId: chequeId,
    );
  }

  Future<void> addChequeDeleted(int chequeId) async {
    await addChequeEvent(chequeId, operation: SyncOperation.delete);
  }

  Future<void> addChequeEvent(
    int chequeId, {
    required SyncOperation operation,
  }) async {
    await add(
      SyncQueueItem(
        entityType: syncEntityTypeCheque,
        entityId: chequeId,
        operation: operation,
        status: SyncStatus.pending,
        retryCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> enqueueUpdateWithMerge({
    required String entityType,
    required int entityId,
  }) async {
    final existing = await _findLatestActiveByEntity(
      entityType: entityType,
      entityId: entityId,
    );

    if (existing == null) {
      await _insertPendingUpdate(entityType: entityType, entityId: entityId);
      return;
    }

    if (existing.operation == SyncOperation.create ||
        existing.operation == SyncOperation.delete) {
      return;
    }

    if (existing.operation == SyncOperation.update && existing.id != null) {
      await _requeueExistingUpdate(existing.id!);
      return;
    }

    await _insertPendingUpdate(entityType: entityType, entityId: entityId);
  }

  Future<SyncQueueItem?> _findLatestActiveByEntity({
    required String entityType,
    required int entityId,
  }) async {
    final statement = _db.prepare(SyncQueueQueries.findLatestActiveByEntity);

    try {
      final rows = statement.selectWith(
        StatementParameters.named({
          ':entityType': entityType,
          ':entityId': entityId,
          ':pendingStatus': SyncStatus.pending.dbValue,
          ':failedStatus': SyncStatus.failed.dbValue,
          ':processingStatus': SyncStatus.processing.dbValue,
        }),
      );

      if (rows.isEmpty) {
        return null;
      }

      return SyncQueueItem.fromDbMap(rows.first);
    } finally {
      statement.dispose();
    }
  }

  Future<void> _insertPendingUpdate({
    required String entityType,
    required int entityId,
  }) async {
    await add(
      SyncQueueItem(
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.update,
        status: SyncStatus.pending,
        retryCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _requeueExistingUpdate(int id) async {
    final statement = _db.prepare(SyncQueueQueries.requeueExistingUpdate);

    try {
      statement.executeWith(
        StatementParameters.named({
          ':id': id,
          ':status': SyncStatus.pending.dbValue,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Map<String, Object?> _namedParams(Map<String, Object?> params) {
    final named = <String, Object?>{};

    for (final entry in params.entries) {
      named[':${entry.key}'] = entry.value;
    }

    return named;
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }

    return 0;
  }
}
