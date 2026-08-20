import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/bank_account_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/bank_account.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';

class _FakeRemoteBankAccountsRepository extends RemoteBankAccountsRepository {
  _FakeRemoteBankAccountsRepository(List<RemoteBankAccountChangesPage> pages)
    : _pages = Queue<RemoteBankAccountChangesPage>.of(pages),
      super(ApiClient());

  final Queue<RemoteBankAccountChangesPage> _pages;
  final List<SyncCursor?> requestedCursors = <SyncCursor?>[];

  @override
  Future<RemoteBankAccountChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteBankAccountsRepository.defaultChangesLimit,
  }) async {
    requestedCursors.add(cursor);

    if (_pages.isEmpty) {
      throw StateError('Fake remote has no more configured pages.');
    }

    return _pages.removeFirst();
  }
}

RemoteBankAccountChange _remoteChange({
  required String uuid,
  required String title,
  required DateTime updatedAt,
  DateTime? createdAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  String bankName = 'بانک تست',
  String accountHolder = 'داروخانه',
  String accountNumber = '123',
  String cardNumber = '456',
  String iban = 'IR789',
  String? note,
}) {
  return RemoteBankAccountChange(
    account: BankAccount(
      id: null,
      serverUuid: uuid,
      bankName: bankName,
      accountTitle: title,
      accountHolder: accountHolder,
      accountNumber: accountNumber,
      cardNumber: cardNumber,
      iban: iban,
      note: note,
      archivedAt: archivedAt,
      createdAt: createdAt ?? updatedAt.subtract(const Duration(days: 1)),
      updatedAt: updatedAt,
    ),
    deletedAt: deletedAt,
  );
}

SyncCursor _cursorFor(RemoteBankAccountChange change) {
  return SyncCursor(
    entityType: syncEntityTypeBankAccount,
    updatedAt: change.updatedAt,
    serverUuid: change.serverUuid,
  );
}

int _seedLocalBankAccount(
  Database db, {
  required String serverUuid,
  required String title,
}) {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  db.execute(
    '''
INSERT INTO bank_accounts (
  server_uuid,
  bank_name,
  account_title,
  account_holder,
  account_number,
  card_number,
  iban,
  note,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, 'بانک قدیمی', ?, 'داروخانه', '1', '2', 'IR3', NULL, NULL, ?, ?)
''',
    [serverUuid, title, now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

void _enqueuePendingBankUpdate(Database db, int bankId) {
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
      syncEntityTypeBankAccount,
      bankId,
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
    'initial paged bank pull inserts active account, ignores absent tombstone, and saves final cursor',
    () async {
      final first = _remoteChange(
        uuid: '11111111-1111-4111-8111-111111111111',
        title: 'حساب اول',
        updatedAt: DateTime.utc(2026, 8, 13, 5),
      );

      final tombstone = _remoteChange(
        uuid: '22222222-2222-4222-8222-222222222222',
        title: 'حساب حذف شده',
        updatedAt: DateTime.utc(2026, 8, 13, 6),
        deletedAt: DateTime.utc(2026, 8, 13, 6),
      );

      final firstCursor = _cursorFor(first);
      final finalCursor = _cursorFor(tombstone);

      final remote = _FakeRemoteBankAccountsRepository([
        RemoteBankAccountChangesPage(
          items: [first],
          hasMore: true,
          nextCursor: firstCursor,
        ),
        RemoteBankAccountChangesPage(
          items: [tombstone],
          hasMore: false,
          nextCursor: finalCursor,
        ),
      ]);

      final service = BankAccountPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.pagesFetched, equals(2));
      expect(result.changesReceived, equals(2));
      expect(result.inserted, equals(1));
      expect(result.tombstonesIgnored, equals(1));

      final rows = db.select(
        'SELECT server_uuid, account_title FROM bank_accounts ORDER BY id',
      );

      expect(rows.length, equals(1));
      expect(rows.first['server_uuid'], equals(first.serverUuid));
      expect(rows.first['account_title'], equals('حساب اول'));

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));

      final storedCursor = await cursorRepository.getByEntityType(
        syncEntityTypeBankAccount,
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
    'existing bank account is merged by server UUID without creating queue work',
    () async {
      const uuid = '33333333-3333-4333-8333-333333333333';

      final localId = _seedLocalBankAccount(
        db,
        serverUuid: uuid,
        title: 'عنوان قدیمی',
      );

      final change = _remoteChange(
        uuid: uuid,
        title: 'عنوان جدید',
        bankName: 'بانک جدید',
        iban: 'IR999',
        note: 'remote-note',
        updatedAt: DateTime.utc(2026, 8, 13, 7),
      );

      final remote = _FakeRemoteBankAccountsRepository([
        RemoteBankAccountChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = BankAccountPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.updated, equals(1));

      final row = db.select('SELECT * FROM bank_accounts WHERE id = ?', [
        localId,
      ]).first;

      expect(row['account_title'], equals('عنوان جدید'));
      expect(row['bank_name'], equals('بانک جدید'));
      expect(row['iban'], equals('IR999'));
      expect(row['note'], equals('remote-note'));

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));
    },
  );

  test(
    'pending local bank work blocks pull and leaves row and cursor unchanged',
    () async {
      const uuid = '44444444-4444-4444-8444-444444444444';

      final localId = _seedLocalBankAccount(
        db,
        serverUuid: uuid,
        title: 'Local Title',
      );

      _enqueuePendingBankUpdate(db, localId);

      final priorCursor = SyncCursor(
        entityType: syncEntityTypeBankAccount,
        updatedAt: DateTime.utc(2026, 8, 13, 4),
        serverUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );

      await cursorRepository.save(priorCursor);

      final change = _remoteChange(
        uuid: uuid,
        title: 'Remote Title',
        updatedAt: DateTime.utc(2026, 8, 13, 8),
      );

      final remote = _FakeRemoteBankAccountsRepository([
        RemoteBankAccountChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = BankAccountPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<BankAccountPullBlockedByLocalChangesException>()),
      );

      final title =
          db.select('SELECT account_title FROM bank_accounts WHERE id = ?', [
                localId,
              ]).first['account_title']
              as String;

      expect(title, equals('Local Title'));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeBankAccount,
      );

      expect(cursor!.serverUuid, equals(priorCursor.serverUuid));
      expect(cursor.updatedAt, equals(priorCursor.updatedAt));
    },
  );

  test(
    'server tombstone archives existing local bank account without push queue',
    () async {
      const uuid = '55555555-5555-4555-8555-555555555555';

      final localId = _seedLocalBankAccount(
        db,
        serverUuid: uuid,
        title: 'حساب فعال',
      );

      final deletedAt = DateTime.utc(2026, 8, 13, 9);
      final change = _remoteChange(
        uuid: uuid,
        title: 'حساب فعال',
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      final remote = _FakeRemoteBankAccountsRepository([
        RemoteBankAccountChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = BankAccountPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.tombstonesApplied, equals(1));

      final row = db.select(
        'SELECT archived_at FROM bank_accounts WHERE id = ?',
        [localId],
      ).first;

      expect(row['archived_at'], equals(deletedAt.millisecondsSinceEpoch));

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));
    },
  );
}
