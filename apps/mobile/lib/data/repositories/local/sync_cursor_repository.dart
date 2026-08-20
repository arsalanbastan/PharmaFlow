import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/queries/sync_cursor_queries.dart';
import '../../../core/sync/sync_cursor.dart';

class SyncCursorRepository {
  SyncCursorRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  Future<SyncCursor?> getByEntityType(String entityType) async {
    final normalizedEntityType = _normalizeEntityType(entityType);

    final rows = _db.select(SyncCursorQueries.findByEntityType, [
      normalizedEntityType,
    ]);

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;

    final updatedAtMillis = _toInt(row['updated_at']);
    final serverUuid = row['server_uuid']?.toString().trim();

    if (serverUuid == null || serverUuid.isEmpty) {
      throw StateError(
        'Stored sync cursor for $normalizedEntityType has an empty server UUID.',
      );
    }

    return SyncCursor(
      entityType: normalizedEntityType,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtMillis,
        isUtc: true,
      ),
      serverUuid: serverUuid,
    );
  }

  Future<void> save(SyncCursor cursor) async {
    upsertInDatabase(_db, cursor);
  }

  void upsertInDatabase(Database db, SyncCursor cursor) {
    final normalizedEntityType = _normalizeEntityType(cursor.entityType);
    final normalizedServerUuid = cursor.serverUuid.trim();

    if (normalizedServerUuid.isEmpty) {
      throw ArgumentError('Sync cursor serverUuid cannot be empty.');
    }

    db.execute(SyncCursorQueries.upsert, [
      normalizedEntityType,
      cursor.updatedAt.toUtc().millisecondsSinceEpoch,
      normalizedServerUuid,
    ]);
  }

  String _normalizeEntityType(String entityType) {
    final normalized = entityType.trim().toUpperCase();

    if (normalized.isEmpty) {
      throw ArgumentError('Sync cursor entityType cannot be empty.');
    }

    return normalized;
  }

  int _toInt(Object? value) {
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

    throw StateError('Stored sync cursor updated_at is invalid: $value');
  }
}
