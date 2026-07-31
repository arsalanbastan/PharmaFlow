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
    final params = item.toDbMap()..remove('id');
    final statement = _db.prepare(SyncQueueQueries.insert);

    try {
      statement.executeWith(StatementParameters.named(params));

      return _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
    } finally {
      statement.dispose();
    }
  }

  Future<List<SyncQueueItem>> getPending() async {
    final rows = _db.select(SyncQueueQueries.findPending, [
      SyncStatus.pending.dbValue,
    ]);

    return rows.map((row) => SyncQueueItem.fromDbMap(row)).toList();
  }

  Future<void> markSynced(int id) async {
    final statement = _db.prepare(SyncQueueQueries.markSynced);

    try {
      statement.executeWith(
        StatementParameters.named({
          'id': id,
          'status': SyncStatus.synced.dbValue,
          'lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
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
          'id': id,
          'status': SyncStatus.failed.dbValue,
          'lastAttemptAt': DateTime.now().millisecondsSinceEpoch,
          'errorMessage': errorMessage,
        }),
      );
    } finally {
      statement.dispose();
    }
  }

  Future<void> addChequeCreated(int chequeId) async {
    await add(
      SyncQueueItem(
        entityType: syncEntityTypeCheque,
        entityId: chequeId,
        operation: SyncOperation.create,
        status: SyncStatus.pending,
        retryCount: 0,
        createdAt: DateTime.now(),
      ),
    );
  }
}
