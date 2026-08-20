import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/company_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

class _FakeRemoteCompanyRepository extends RemoteCompanyRepository {
  _FakeRemoteCompanyRepository(List<RemoteCompanyChangesPage> pages)
    : _pages = Queue<RemoteCompanyChangesPage>.of(pages),
      super(ApiClient());

  final Queue<RemoteCompanyChangesPage> _pages;

  final List<SyncCursor?> requestedCursors = <SyncCursor?>[];

  @override
  Future<RemoteCompanyChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteCompanyRepository.defaultChangesLimit,
  }) async {
    requestedCursors.add(cursor);

    if (_pages.isEmpty) {
      throw StateError('Fake remote has no more configured pages.');
    }

    return _pages.removeFirst();
  }
}

RemoteCompanyChange _remoteChange({
  required String uuid,
  required String name,
  required DateTime updatedAt,
  DateTime? createdAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  String? notes,
}) {
  return RemoteCompanyChange(
    company: Company(
      id: null,
      serverUuid: uuid,
      name: name,
      nationalId: null,
      economicCode: null,
      notes: notes,
      visitorName: null,
      visitorPhone: null,
      accountantName: null,
      accountantPhone: null,
      archivedAt: archivedAt,
      createdAt: createdAt ?? updatedAt.subtract(const Duration(days: 1)),
      updatedAt: updatedAt,
    ),
    deletedAt: deletedAt,
  );
}

SyncCursor _cursorFor(RemoteCompanyChange change) {
  return SyncCursor(
    entityType: syncEntityTypeCompany,
    updatedAt: change.updatedAt,
    serverUuid: change.serverUuid,
  );
}

int _seedLocalCompany(
  Database db, {
  required String serverUuid,
  required String name,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);

  final updated = updatedAt ?? DateTime.utc(2026, 1, 1);

  db.execute(
    '''
INSERT INTO companies (
  server_uuid,
  name,
  national_id,
  economic_code,
  notes,
  visitor_name,
  visitor_phone,
  accountant_name,
  accountant_phone,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
''',
    [
      serverUuid,
      name,
      created.millisecondsSinceEpoch,
      updated.millisecondsSinceEpoch,
    ],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

void _enqueuePendingCompanyUpdate(Database db, int companyId) {
  db.execute(
    '''
INSERT INTO sync_queue (
  entityType,
  entityId,
  operation,
  status,
  retryCount,
  createdAt,
  lastAttemptAt,
  errorMessage
)
VALUES (?, ?, ?, ?, 0, ?, NULL, NULL)
''',
    [
      syncEntityTypeCompany,
      companyId,
      SyncOperation.update.dbValue,
      SyncStatus.pending.dbValue,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}

void main() {
  late Database db;
  late SyncCursorRepository cursorRepository;

  setUp(() {
    db = sqlite3.openInMemory();

    MigrationManager.migrate(db);

    DatabaseService.instance.injectDatabaseForTesting(db);

    cursorRepository = SyncCursorRepository(DatabaseService.instance);
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'initial paged pull inserts active companies, ignores absent tombstones, and saves final cursor',
    () async {
      final first = _remoteChange(
        uuid: '11111111-1111-4111-8111-111111111111',
        name: 'Company A',
        updatedAt: DateTime.utc(2026, 8, 13, 5),
      );

      final tombstone = _remoteChange(
        uuid: '22222222-2222-4222-8222-222222222222',
        name: 'Deleted Historical Company',
        updatedAt: DateTime.utc(2026, 8, 13, 6),
        deletedAt: DateTime.utc(2026, 8, 13, 6),
      );

      final firstCursor = _cursorFor(first);
      final finalCursor = _cursorFor(tombstone);

      final remote = _FakeRemoteCompanyRepository([
        RemoteCompanyChangesPage(
          items: [first],
          hasMore: true,
          nextCursor: firstCursor,
        ),
        RemoteCompanyChangesPage(
          items: [tombstone],
          hasMore: false,
          nextCursor: finalCursor,
        ),
      ]);

      final service = CompanyPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.pagesFetched, equals(2));
      expect(result.changesReceived, equals(2));
      expect(result.uniqueChanges, equals(2));
      expect(result.inserted, equals(1));
      expect(result.updated, equals(0));
      expect(result.tombstonesIgnored, equals(1));

      final companies = db.select('''
SELECT server_uuid, name
FROM companies
ORDER BY id
''');

      expect(companies.length, equals(1));
      expect(companies.first['server_uuid'], equals(first.serverUuid));
      expect(companies.first['name'], equals('Company A'));

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(
        queueCount,
        equals(0),
        reason: 'Remote merge must never generate local push queue work.',
      );

      final storedCursor = await cursorRepository.getByEntityType(
        syncEntityTypeCompany,
      );

      expect(storedCursor, isNotNull);
      expect(storedCursor!.serverUuid, equals(finalCursor.serverUuid));
      expect(storedCursor.updatedAt, equals(finalCursor.updatedAt));

      expect(remote.requestedCursors.length, equals(2));
      expect(remote.requestedCursors.first, isNull);
      expect(
        remote.requestedCursors[1]?.serverUuid,
        equals(firstCursor.serverUuid),
      );
    },
  );

  test(
    'existing company is merged by server UUID without creating queue work',
    () async {
      const uuid = '33333333-3333-4333-8333-333333333333';

      final localId = _seedLocalCompany(db, serverUuid: uuid, name: 'Old Name');

      final remoteChange = _remoteChange(
        uuid: uuid,
        name: 'New Name',
        notes: 'remote-note',
        updatedAt: DateTime.utc(2026, 8, 13, 7),
      );

      final remote = _FakeRemoteCompanyRepository([
        RemoteCompanyChangesPage(
          items: [remoteChange],
          hasMore: false,
          nextCursor: _cursorFor(remoteChange),
        ),
      ]);

      final service = CompanyPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.inserted, equals(0));
      expect(result.updated, equals(1));

      final row = db
          .select(
            '''
SELECT
  id,
  server_uuid,
  name,
  notes,
  updated_at
FROM companies
WHERE id = ?
''',
            [localId],
          )
          .first;

      expect(row['server_uuid'], equals(uuid));
      expect(row['name'], equals('New Name'));
      expect(row['notes'], equals('remote-note'));
      expect(
        row['updated_at'],
        equals(remoteChange.updatedAt.millisecondsSinceEpoch),
      );

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));
    },
  );

  test(
    'remote company tombstone archives existing local row instead of hard deleting it',
    () async {
      const uuid = '44444444-4444-4444-8444-444444444444';

      final localId = _seedLocalCompany(
        db,
        serverUuid: uuid,
        name: 'Company To Delete',
      );

      final deletedAt = DateTime.utc(2026, 8, 13, 8);

      final remoteChange = _remoteChange(
        uuid: uuid,
        name: 'Company To Delete',
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      final remote = _FakeRemoteCompanyRepository([
        RemoteCompanyChangesPage(
          items: [remoteChange],
          hasMore: false,
          nextCursor: _cursorFor(remoteChange),
        ),
      ]);

      final service = CompanyPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.tombstonesApplied, equals(1));

      final row = db.select(
        '''
SELECT id, archived_at
FROM companies
WHERE id = ?
''',
        [localId],
      );

      expect(
        row.length,
        equals(1),
        reason:
            'Server delete must not hard-delete a company that can be referenced by cheques.',
      );

      expect(
        row.first['archived_at'],
        equals(deletedAt.millisecondsSinceEpoch),
      );
    },
  );

  test(
    'pending local company work blocks remote overwrite and cursor advancement',
    () async {
      const uuid = '55555555-5555-4555-8555-555555555555';

      final localId = _seedLocalCompany(
        db,
        serverUuid: uuid,
        name: 'Local Unsynced Name',
      );

      _enqueuePendingCompanyUpdate(db, localId);

      final remoteChange = _remoteChange(
        uuid: uuid,
        name: 'Remote Name',
        updatedAt: DateTime.utc(2026, 8, 13, 9),
      );

      final remote = _FakeRemoteCompanyRepository([
        RemoteCompanyChangesPage(
          items: [remoteChange],
          hasMore: false,
          nextCursor: _cursorFor(remoteChange),
        ),
      ]);

      final service = CompanyPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<CompanyPullBlockedByLocalChangesException>()),
      );

      final row = db
          .select(
            '''
SELECT name
FROM companies
WHERE id = ?
''',
            [localId],
          )
          .first;

      expect(row['name'], equals('Local Unsynced Name'));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCompany,
      );

      expect(
        cursor,
        isNull,
        reason: 'Cursor must not advance past an unsynced local change.',
      );
    },
  );

  test(
    'merge conflict rolls back all company changes and cursor atomically',
    () async {
      const firstUuid = '66666666-6666-4666-8666-666666666666';

      const unrelatedUuid = '77777777-7777-4777-8777-777777777777';

      _seedLocalCompany(db, serverUuid: firstUuid, name: 'Original A');

      _seedLocalCompany(db, serverUuid: unrelatedUuid, name: 'Collision Name');

      final firstChange = _remoteChange(
        uuid: firstUuid,
        name: 'Changed A',
        updatedAt: DateTime.utc(2026, 8, 13, 10),
      );

      final conflictingNewCompany = _remoteChange(
        uuid: '88888888-8888-4888-8888-888888888888',
        name: 'Collision Name',
        updatedAt: DateTime.utc(2026, 8, 13, 11),
      );

      final remote = _FakeRemoteCompanyRepository([
        RemoteCompanyChangesPage(
          items: [firstChange, conflictingNewCompany],
          hasMore: false,
          nextCursor: _cursorFor(conflictingNewCompany),
        ),
      ]);

      final service = CompanyPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<CompanyMergeConflictException>()),
      );

      final firstRow = db
          .select(
            '''
SELECT name
FROM companies
WHERE server_uuid = ?
''',
            [firstUuid],
          )
          .first;

      expect(
        firstRow['name'],
        equals('Original A'),
        reason: 'Earlier changes in the same entity merge must roll back too.',
      );

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCompany,
      );

      expect(
        cursor,
        isNull,
        reason:
            'Cursor and business-data merge must commit or roll back together.',
      );

      final totalCompanies =
          db.select('SELECT COUNT(*) AS count FROM companies').first['count']
              as int;

      expect(totalCompanies, equals(2));
    },
  );
}
