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
    return addInDatabase(_db, item);
  }

  int addInDatabase(Database db, SyncQueueItem item) {
    final params = _namedParams(item.toDbMap()..remove('id'));

    final statement = db.prepare(SyncQueueQueries.insert);

    try {
      statement.executeWith(StatementParameters.named(params));

      return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
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

    return rows.map(SyncQueueItem.fromDbMap).toList();
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

    return rows.map(SyncQueueItem.fromDbMap).toList();
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

    return rows.map(SyncQueueItem.fromDbMap).toList();
  }

  Future<List<SyncQueueItem>> getAllItems() async {
    final statement = _db.prepare(SyncQueueQueries.findAllNewest);

    late final ResultSet rows;

    try {
      rows = statement.select();
    } finally {
      statement.dispose();
    }

    return rows.map(SyncQueueItem.fromDbMap).toList();
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
    enqueueUpdateWithMergeInDatabase(
      _db,
      entityType: entityType,
      entityId: entityId,
    );
  }

  void enqueueUpdateWithMergeInDatabase(
    Database db, {
    required String entityType,
    required int entityId,
  }) {
    final existing = _findLatestActiveByEntityInDatabase(
      db,
      entityType: entityType,
      entityId: entityId,
    );

    if (existing == null) {
      _insertPendingUpdateInDatabase(
        db,
        entityType: entityType,
        entityId: entityId,
      );
      return;
    }

    /*
     * Pending/failed CREATE has not started its
     * current network attempt yet.
     *
     * Because SyncService reads the current entity
     * snapshot when CREATE is eventually processed,
     * no separate UPDATE is required.
     *
     * PROCESSING is different: the CREATE request may
     * already contain an older snapshot. In that case
     * preserve the new mutation as a follow-up UPDATE.
     */
    if (existing.operation == SyncOperation.create) {
      if (existing.status == SyncStatus.processing) {
        _insertPendingUpdateInDatabase(
          db,
          entityType: entityType,
          entityId: entityId,
        );
      }

      return;
    }

    /*
     * Once DELETE is active, UPDATE must not resurrect
     * the entity.
     */
    if (existing.operation == SyncOperation.delete) {
      return;
    }

    if (existing.operation == SyncOperation.update && existing.id != null) {
      /*
       * Never rewrite an in-flight PROCESSING row back
       * to PENDING. The currently running sync could
       * mark that same row SYNCED after the local
       * mutation and silently swallow the change.
       *
       * A new pending UPDATE is the follow-up work.
       */
      if (existing.status == SyncStatus.processing) {
        _insertPendingUpdateInDatabase(
          db,
          entityType: entityType,
          entityId: entityId,
        );
      } else {
        _requeueExistingUpdateInDatabase(db, existing.id!);
      }

      return;
    }

    _insertPendingUpdateInDatabase(
      db,
      entityType: entityType,
      entityId: entityId,
    );
  }

  void enqueueDeleteWithMergeInDatabase(
    Database db, {
    required String entityType,
    required int entityId,
  }) {
    final existing = _findLatestActiveByEntityInDatabase(
      db,
      entityType: entityType,
      entityId: entityId,
    );

    if (existing != null) {
      if (existing.operation == SyncOperation.delete) {
        return;
      }

      if (existing.operation == SyncOperation.create) {
        /*
         * A pending CREATE has definitely not started yet, so deleting the
         * local entity can cancel that CREATE without a remote DELETE.
         *
         * FAILED / PROCESSING CREATE is different: the request may already
         * have reached the server. Keep the CREATE work alive. CashPayment
         * SyncService will enqueue a follow-up DELETE after an idempotent
         * CREATE succeeds when deleteRequestedAt is present.
         */
        if (existing.status == SyncStatus.pending && existing.id != null) {
          final cancelStatement = db.prepare(SyncQueueQueries.deleteById);

          try {
            cancelStatement.executeWith(
              StatementParameters.named({':id': existing.id}),
            );
          } finally {
            cancelStatement.dispose();
          }
        }

        return;
      }

      if (existing.operation == SyncOperation.update &&
          existing.id != null &&
          existing.status != SyncStatus.processing) {
        final cancelStatement = db.prepare(SyncQueueQueries.deleteById);

        try {
          cancelStatement.executeWith(
            StatementParameters.named({':id': existing.id}),
          );
        } finally {
          cancelStatement.dispose();
        }
      }
    }

    addInDatabase(
      db,
      SyncQueueItem(
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.delete,
        status: SyncStatus.pending,
        retryCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  SyncQueueItem? _findLatestActiveByEntityInDatabase(
    Database db, {
    required String entityType,
    required int entityId,
  }) {
    final statement = db.prepare(SyncQueueQueries.findLatestActiveByEntity);

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

  void _insertPendingUpdateInDatabase(
    Database db, {
    required String entityType,
    required int entityId,
  }) {
    addInDatabase(
      db,
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

  void _requeueExistingUpdateInDatabase(Database db, int id) {
    final statement = db.prepare(SyncQueueQueries.requeueExistingUpdate);

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
