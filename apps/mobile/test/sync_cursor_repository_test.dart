import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';

void main() {
  late Database db;
  late SyncCursorRepository repository;

  setUp(() {
    db = sqlite3.openInMemory();

    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    repository = SyncCursorRepository(DatabaseService.instance);
  });

  tearDown(() {
    DatabaseService.instance.close();
  });

  test('migration creates sync_cursors and upgrades to current schema', () {
    final version =
        db.select('PRAGMA user_version').first['user_version'] as int;

    expect(version, equals(MigrationManager.currentVersion));

    final tables = db.select('''
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name = 'sync_cursors'
''');

    expect(tables.length, equals(1));
  });

  test('cursor can be saved and loaded without losing precision', () async {
    final cursor = SyncCursor(
      entityType: 'COMPANY',
      updatedAt: DateTime.utc(2026, 8, 13, 5, 12, 34, 567),
      serverUuid: '98c8d9b5-3aa0-4cf6-bcfc-009887dfbf9a',
    );

    await repository.save(cursor);

    final loaded = await repository.getByEntityType('company');

    expect(loaded, isNotNull);
    expect(loaded!.entityType, equals('COMPANY'));
    expect(
      loaded.updatedAt.millisecondsSinceEpoch,
      equals(cursor.updatedAt.millisecondsSinceEpoch),
    );
    expect(loaded.serverUuid, equals(cursor.serverUuid));
  });

  test('saving a newer cursor replaces the prior entity cursor', () async {
    await repository.save(
      SyncCursor(
        entityType: 'COMPANY',
        updatedAt: DateTime.utc(2026, 8, 13, 5),
        serverUuid: '11111111-1111-4111-8111-111111111111',
      ),
    );

    await repository.save(
      SyncCursor(
        entityType: 'COMPANY',
        updatedAt: DateTime.utc(2026, 8, 13, 6),
        serverUuid: '22222222-2222-4222-8222-222222222222',
      ),
    );

    final loaded = await repository.getByEntityType('COMPANY');

    expect(loaded, isNotNull);
    expect(loaded!.updatedAt, equals(DateTime.utc(2026, 8, 13, 6)));
    expect(loaded.serverUuid, equals('22222222-2222-4222-8222-222222222222'));

    final count =
        db.select('''
SELECT COUNT(*) AS count
FROM sync_cursors
WHERE entity_type = 'COMPANY'
''').first['count']
            as int;

    expect(count, equals(1));
  });

  test('cursor update participates in caller transaction rollback', () async {
    expect(() {
      DatabaseService.instance.transaction((transactionDb) {
        repository.upsertInDatabase(
          transactionDb,
          SyncCursor(
            entityType: 'COMPANY',
            updatedAt: DateTime.utc(2026, 8, 13, 7),
            serverUuid: '33333333-3333-4333-8333-333333333333',
          ),
        );

        throw StateError('simulate merge failure');
      });
    }, throwsStateError);

    final loaded = await repository.getByEntityType('COMPANY');

    expect(
      loaded,
      isNull,
      reason:
          'Cursor must not advance when the surrounding merge transaction fails.',
    );
  });
}
