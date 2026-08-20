import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cheque_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';

class _FakeRemoteChequeRepository extends RemoteChequeRepository {
  _FakeRemoteChequeRepository(List<RemoteChequeChangesPage> pages)
    : _pages = Queue<RemoteChequeChangesPage>.of(pages),
      super(ApiClient());

  final Queue<RemoteChequeChangesPage> _pages;
  final List<SyncCursor?> requestedCursors = <SyncCursor?>[];

  @override
  Future<RemoteChequeChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteChequeRepository.defaultChangesLimit,
  }) async {
    requestedCursors.add(cursor);

    if (_pages.isEmpty) {
      throw StateError('Fake remote has no more configured pages.');
    }

    return _pages.removeFirst();
  }
}

RemoteChequeRecord _remoteCheque({
  required String id,
  required String companyUuid,
  required String bankUuid,
  required DateTime updatedAt,
  String chequeNumber = '1001',
  num amount = 1500000,
  String status = 'Issued',
  bool isRegisteredInSayad = false,
  DateTime? deletedAt,
  DateTime? archivedAt,
  String? sayadId,
  String? description,
  String? imageData,
}) {
  return RemoteChequeRecord(
    id: id,
    companyId: companyUuid,
    bankAccountId: bankUuid,
    chequeNumber: chequeNumber,
    amount: amount,
    chequeDate: updatedAt.subtract(const Duration(days: 2)),
    dueDate: updatedAt.add(const Duration(days: 10)),
    status: status,
    isRegisteredInSayad: isRegisteredInSayad,
    sayadId: sayadId,
    imageData: imageData,
    description: description,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: updatedAt.subtract(const Duration(days: 3)),
    updatedAt: updatedAt,
  );
}

SyncCursor _cursorFor(RemoteChequeRecord cheque) {
  return SyncCursor(
    entityType: syncEntityTypeCheque,
    updatedAt: cheque.updatedAt,
    serverUuid: cheque.id,
  );
}

int _seedCompany(Database db, String uuid) {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

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
VALUES (?, 'Company', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
''',
    [uuid, now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

int _seedBank(Database db, String uuid) {
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
VALUES (?, 'Bank', 'Main', 'Owner', '1', '2', 'IR3', NULL, NULL, ?, ?)
''',
    [uuid, now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

int _seedCheque(
  Database db, {
  required String chequeUuid,
  required int companyId,
  required int bankId,
  String receiverName = 'Legacy Receiver',
}) {
  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  db.execute(
    '''
INSERT INTO cheques (
  server_uuid,
  company_id,
  bank_account_id,
  receiver_name,
  cheque_number,
  amount_rial,
  issue_date,
  due_date,
  status,
  is_registered_in_sayad,
  sayad_id,
  description,
  image_data,
  archived_at,
  delete_requested_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, 'OLD', 1, ?, ?, 'Issued', 0, NULL, NULL, NULL, NULL, NULL, ?, ?)
''',
    [chequeUuid, companyId, bankId, receiverName, now, now, now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

void _enqueuePendingChequeUpdate(Database db, int chequeId) {
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
      syncEntityTypeCheque,
      chequeId,
      SyncOperation.update.dbValue,
      SyncStatus.pending.dbValue,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}

void main() {
  late Database db;
  late SyncCursorRepository cursorRepository;

  const companyUuid = '11111111-1111-4111-8111-111111111111';
  const bankUuid = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);
    cursorRepository = SyncCursorRepository(DatabaseService.instance);

    _seedCompany(db, companyUuid);
    _seedBank(db, bankUuid);
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'initial cheque pull inserts by dependency UUID, creates no queue work, and saves cursor',
    () async {
      final change = _remoteCheque(
        id: '33333333-3333-4333-8333-333333333333',
        companyUuid: companyUuid,
        bankUuid: bankUuid,
        updatedAt: DateTime.utc(2026, 8, 13, 10),
        imageData: base64Encode(<int>[1, 2, 3]),
      );

      final remote = _FakeRemoteChequeRepository([
        RemoteChequeChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = ChequePullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.inserted, equals(1));

      final rows = db.select('SELECT * FROM cheques WHERE server_uuid = ?', [
        change.id,
      ]);

      expect(rows.length, equals(1));
      expect(rows.first['cheque_number'], equals('1001'));
      expect(rows.first['amount_rial'], equals(1500000));
      expect(rows.first['is_registered_in_sayad'], equals(0));
      expect(rows.first['delete_requested_at'], isNull);

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCheque,
      );

      expect(cursor, isNotNull);
      expect(cursor!.serverUuid, equals(change.id));
      expect(cursor.updatedAt, equals(change.updatedAt));
    },
  );

  test(
    'existing cheque merge updates Sayad fields and preserves local-only receiver name',
    () async {
      const chequeUuid = '44444444-4444-4444-8444-444444444444';

      final companyId =
          db.select('SELECT id FROM companies').first['id'] as int;
      final bankId =
          db.select('SELECT id FROM bank_accounts').first['id'] as int;

      final localId = _seedCheque(
        db,
        chequeUuid: chequeUuid,
        companyId: companyId,
        bankId: bankId,
      );

      final change = _remoteCheque(
        id: chequeUuid,
        companyUuid: companyUuid,
        bankUuid: bankUuid,
        updatedAt: DateTime.utc(2026, 8, 13, 11),
        chequeNumber: 'NEW-1001',
        amount: 2500000,
        status: 'Registered',
        isRegisteredInSayad: true,
        sayadId: '1234567890123456',
        description: 'remote description',
      );

      final remote = _FakeRemoteChequeRepository([
        RemoteChequeChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = ChequePullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.updated, equals(1));

      final row = db.select('SELECT * FROM cheques WHERE id = ?', [
        localId,
      ]).first;

      expect(row['cheque_number'], equals('NEW-1001'));
      expect(row['amount_rial'], equals(2500000));
      expect(row['status'], equals('Registered'));
      expect(row['is_registered_in_sayad'], equals(1));
      expect(row['sayad_id'], equals('1234567890123456'));
      expect(row['receiver_name'], equals('Legacy Receiver'));
      expect(row['description'], equals('remote description'));
    },
  );

  test(
    'pending local cheque work blocks pull and leaves row and cursor unchanged',
    () async {
      const chequeUuid = '55555555-5555-4555-8555-555555555555';

      final companyId =
          db.select('SELECT id FROM companies').first['id'] as int;
      final bankId =
          db.select('SELECT id FROM bank_accounts').first['id'] as int;

      final localId = _seedCheque(
        db,
        chequeUuid: chequeUuid,
        companyId: companyId,
        bankId: bankId,
      );

      _enqueuePendingChequeUpdate(db, localId);

      final priorCursor = SyncCursor(
        entityType: syncEntityTypeCheque,
        updatedAt: DateTime.utc(2026, 8, 13, 9),
        serverUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );

      await cursorRepository.save(priorCursor);

      final change = _remoteCheque(
        id: chequeUuid,
        companyUuid: companyUuid,
        bankUuid: bankUuid,
        updatedAt: DateTime.utc(2026, 8, 13, 12),
        chequeNumber: 'REMOTE',
      );

      final remote = _FakeRemoteChequeRepository([
        RemoteChequeChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = ChequePullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<ChequePullBlockedByLocalChangesException>()),
      );

      final chequeNumber =
          db.select('SELECT cheque_number FROM cheques WHERE id = ?', [
                localId,
              ]).first['cheque_number']
              as String;

      expect(chequeNumber, equals('OLD'));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCheque,
      );

      expect(cursor!.serverUuid, equals(priorCursor.serverUuid));
      expect(cursor.updatedAt, equals(priorCursor.updatedAt));
    },
  );

  test(
    'server cheque tombstone archives existing row and clears local delete intent without queue work',
    () async {
      const chequeUuid = '66666666-6666-4666-8666-666666666666';

      final companyId =
          db.select('SELECT id FROM companies').first['id'] as int;
      final bankId =
          db.select('SELECT id FROM bank_accounts').first['id'] as int;

      final localId = _seedCheque(
        db,
        chequeUuid: chequeUuid,
        companyId: companyId,
        bankId: bankId,
      );

      final deletedAt = DateTime.utc(2026, 8, 13, 13);
      final change = _remoteCheque(
        id: chequeUuid,
        companyUuid: companyUuid,
        bankUuid: bankUuid,
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );

      final remote = _FakeRemoteChequeRepository([
        RemoteChequeChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = ChequePullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      final result = await service.pullAndMerge();

      expect(result.tombstonesApplied, equals(1));

      final row = db.select(
        'SELECT archived_at, delete_requested_at FROM cheques WHERE id = ?',
        [localId],
      ).first;

      expect(row['archived_at'], equals(deletedAt.millisecondsSinceEpoch));
      expect(row['delete_requested_at'], isNull);

      final queueCount =
          db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
              as int;

      expect(queueCount, equals(0));
    },
  );

  test(
    'missing dependency UUID blocks cheque merge and does not advance cursor',
    () async {
      final change = _remoteCheque(
        id: '77777777-7777-4777-8777-777777777777',
        companyUuid: '88888888-8888-4888-8888-888888888888',
        bankUuid: bankUuid,
        updatedAt: DateTime.utc(2026, 8, 13, 14),
      );

      final remote = _FakeRemoteChequeRepository([
        RemoteChequeChangesPage(
          items: [change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ]);

      final service = ChequePullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<ChequeMergeConflictException>()),
      );

      final chequeCount =
          db.select('SELECT COUNT(*) AS count FROM cheques').first['count']
              as int;

      expect(chequeCount, equals(0));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCheque,
      );

      expect(cursor, isNull);
    },
  );
}
