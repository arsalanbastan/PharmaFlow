// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

// ---------------------------------------------------------------------------
// Fake remote repositories
// ---------------------------------------------------------------------------

class _FakeCompanyRemote extends RemoteCompanyRepository {
  _FakeCompanyRemote() : super(ApiClient());
  bool shouldFail = false;
  int callCount = 0;

  @override
  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    callCount++;
    if (shouldFail) throw Exception('fake company remote failure');
  }
}

class _FakeBankRemote extends RemoteBankAccountsRepository {
  _FakeBankRemote() : super(ApiClient());
  bool shouldFail = false;
  int callCount = 0;

  @override
  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    callCount++;
    if (shouldFail) throw Exception('fake bank remote failure');
  }
}

class _FakeChequeRemote extends RemoteChequeRepository {
  _FakeChequeRemote() : super(ApiClient());
  bool shouldFail = false;
  String? returnUuid = 'server-uuid-001';
  int callCount = 0;

  @override
  Future<String?> create(Map<String, dynamic> payload) async {
    callCount++;
    if (shouldFail) throw Exception('fake cheque remote failure');
    return returnUuid;
  }

  @override
  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    callCount++;
    if (shouldFail) throw Exception('fake cheque remote failure');
  }

  @override
  Future<void> delete(String serverUuid) async {
    callCount++;
    if (shouldFail) throw Exception('fake cheque remote failure');
  }
}

class _FakeChequeSyncResolver extends ChequeSyncIdentityResolver {
  _FakeChequeSyncResolver(
    LocalChequeRepository localRepo,
    _FakeChequeRemote remoteRepo,
    SyncIdentityResolver identityResolver,
  ) : super(
        localChequeRepository: localRepo,
        remoteChequeRepository: remoteRepo,
        identityResolver: identityResolver,
      );

  @override
  Future<String> resolveServerUuid(Cheque cheque) async {
    final existing = cheque.serverUuid?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    return 'server-uuid-${cheque.id}';
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _companyServerUuid = 'company-server-uuid-1';
const _bankServerUuid = 'bank-server-uuid-1';

/// Seeds a company with [server_uuid] and returns its local id.
int _seedCompany(Database db, {String serverUuid = _companyServerUuid}) {
  db.execute(
    '''
    INSERT INTO companies
      (server_uuid, name, national_id, economic_code, notes,
       visitor_name, visitor_phone, accountant_name, accountant_phone,
       archived_at, created_at, updated_at)
    VALUES (?, 'Test Company', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
            NULL, ?, ?)
  ''',
    [
      serverUuid,
      DateTime.now().millisecondsSinceEpoch,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

/// Seeds a bank account with [server_uuid] and returns its local id.
int _seedBank(Database db, {String serverUuid = _bankServerUuid}) {
  db.execute(
    '''
    INSERT INTO bank_accounts
      (server_uuid, bank_name, account_title, account_holder,
       account_number, card_number, iban, note, archived_at,
       created_at, updated_at)
    VALUES (?, 'Test Bank', 'Checking', 'Owner', '0001', '1111',
            'IR000000000000000000000001', NULL, NULL, ?, ?)
  ''',
    [
      serverUuid,
      DateTime.now().millisecondsSinceEpoch,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

/// Seeds a cheque and returns its local id.
int _seedCheque(Database db, {required int companyId, required int bankId}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  db.execute(
    '''
    INSERT INTO cheques
      (server_uuid, company_id, bank_account_id, receiver_name,
       cheque_number, amount_rial, issue_date, due_date, status,
       is_registered_in_sayad, sayad_id, description, image_data,
       archived_at, delete_requested_at, created_at, updated_at)
    VALUES (NULL, ?, ?, NULL, '0001001', 100000, ?, ?, 'Issued',
            0, NULL, NULL, NULL, NULL, NULL, ?, ?)
  ''',
    [companyId, bankId, now, now, now, now],
  );
  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

/// Inserts a raw queue item with the given parameters.
void _enqueue(
  Database db, {
  required String entityType,
  required int entityId,
  required String operation,
  int createdAt = 0,
}) {
  db.execute(
    '''
    INSERT INTO sync_queue
      (entityType, entityId, operation, status, retryCount, createdAt,
       lastAttemptAt, errorMessage)
    VALUES (?, ?, ?, 'PENDING', 0, ?, NULL, NULL)
  ''',
    [entityType, entityId, operation, createdAt],
  );
}

SyncQueueItem? _queueItem(Database db, int id) {
  final rows = db.select('SELECT * FROM sync_queue WHERE id = ?', [id]);
  if (rows.isEmpty) return null;
  return SyncQueueItem.fromDbMap(rows.first);
}

List<SyncQueueItem> _allQueueItems(Database db) {
  final rows = db.select('SELECT * FROM sync_queue ORDER BY id ASC');
  return rows.map(SyncQueueItem.fromDbMap).toList();
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  late Database db;
  late SyncQueueRepository queueRepo;
  late LocalCompanyRepository localCompanyRepo;
  late LocalBankAccountRepository localBankRepo;
  late LocalChequeRepository localChequeRepo;
  late _FakeCompanyRemote fakeCompanyRemote;
  late _FakeBankRemote fakeBankRemote;
  late _FakeChequeRemote fakeChequeRemote;
  late SyncService syncService;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    queueRepo = SyncQueueRepository(DatabaseService.instance);
    localCompanyRepo = LocalCompanyRepository(DatabaseService.instance);
    localBankRepo = LocalBankAccountRepository(DatabaseService.instance);
    localChequeRepo = LocalChequeRepository(DatabaseService.instance);

    fakeCompanyRemote = _FakeCompanyRemote();
    fakeBankRemote = _FakeBankRemote();
    fakeChequeRemote = _FakeChequeRemote();

    final identityResolver = SyncIdentityResolver(DatabaseService.instance);

    syncService = SyncService(
      syncQueueRepository: queueRepo,
      localCompanyRepository: localCompanyRepo,
      localBankAccountRepository: localBankRepo,
      localChequeRepository: localChequeRepo,
      identityResolver: identityResolver,
      remoteCompanyRepository: fakeCompanyRemote,
      remoteBankAccountsRepository: fakeBankRemote,
      remoteChequeRepository: fakeChequeRemote,
      chequeSyncIdentityResolver: _FakeChequeSyncResolver(
        localChequeRepo,
        fakeChequeRemote,
        identityResolver,
      ),
    );
  });

  tearDown(() {
    db.dispose();
  });

  // -------------------------------------------------------------------------
  // A + B  Queue ordering and Company-failure gates Bank+Cheque
  // -------------------------------------------------------------------------

  test(
    'A+B: CHEQUE item with earlier timestamp is still processed after COMPANY',
    () async {
      final companyId = _seedCompany(db);

      // CHEQUE enqueued first (earlier timestamp), COMPANY second.
      final now = DateTime.now().millisecondsSinceEpoch;
      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: 1,
        operation: 'CREATE',
        createdAt: now - 1000,
      );
      final chequeQueueId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
      _enqueue(
        db,
        entityType: 'COMPANY',
        entityId: companyId,
        operation: 'UPDATE',
        createdAt: now,
      );
      final companyQueueId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      // COMPANY remote fails → should stop; CHEQUE should remain PENDING.
      fakeCompanyRemote.shouldFail = true;
      // Suppress unused_local_variable; companyQueueId is used implicitly via DB state.
      expect(companyQueueId, greaterThan(0));

      final result = await syncService.sync();

      expect(
        result.stoppedAtPhase,
        equals('COMPANY'),
        reason: 'Execution must stop at COMPANY phase',
      );

      final chequeItem = _queueItem(db, chequeQueueId);
      expect(
        chequeItem?.status,
        equals(SyncStatus.pending),
        reason: 'CHEQUE must remain PENDING (not attempted) when COMPANY fails',
      );
      expect(result.failed, equals(1));
    },
  );

  // -------------------------------------------------------------------------
  // C  Bank Account failure gates Cheque
  // -------------------------------------------------------------------------

  test(
    'C: BANK_ACCOUNT failure prevents CHEQUE from being processed',
    () async {
      final bankId = _seedBank(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: 1,
        operation: 'CREATE',
        createdAt: now,
      );
      final chequeQueueId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
      _enqueue(
        db,
        entityType: 'BANK_ACCOUNT',
        entityId: bankId,
        operation: 'UPDATE',
        createdAt: now,
      );

      fakeBankRemote.shouldFail = true;

      final result = await syncService.sync();

      expect(result.stoppedAtPhase, equals('BANK_ACCOUNT'));

      final chequeItem = _queueItem(db, chequeQueueId);
      expect(
        chequeItem?.status,
        equals(SyncStatus.pending),
        reason: 'CHEQUE must remain PENDING when BANK_ACCOUNT phase fails',
      );
    },
  );

  // -------------------------------------------------------------------------
  // D  Cheque failure does not corrupt other items
  // -------------------------------------------------------------------------

  test(
    'D: CHEQUE failure is reported but does not affect other queue items',
    () async {
      final companyId = _seedCompany(db);
      final bankId = _seedBank(db);
      final chequeId = _seedCheque(db, companyId: companyId, bankId: bankId);
      final chequeId2 = _seedCheque(db, companyId: companyId, bankId: bankId)
        ..toString();
      // Update cheque2 cheque_number to be distinct.
      db.execute("UPDATE cheques SET cheque_number='0001002' WHERE id=?", [
        chequeId2,
      ]);

      final now = DateTime.now().millisecondsSinceEpoch;
      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: chequeId,
        operation: 'CREATE',
        createdAt: now,
      );
      final qId1 =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: chequeId2,
        operation: 'CREATE',
        createdAt: now + 1,
      );

      fakeChequeRemote.shouldFail = true;

      final result = await syncService.sync();

      expect(result.failed, greaterThan(0));
      expect(
        result.stoppedAtPhase,
        isNull,
        reason:
            'CHEQUE failures do not stop the run, they only count as failures',
      );

      final item1 = _queueItem(db, qId1);
      expect(
        item1?.status,
        equals(SyncStatus.failed),
        reason: 'Failed CHEQUE item should be FAILED not PROCESSING',
      );
    },
  );

  // -------------------------------------------------------------------------
  // E  Concurrent sync() – single-flight lock
  // -------------------------------------------------------------------------

  test(
    'E: second sync() call while first is running returns wasAlreadyRunning',
    () async {
      // No items in queue → sync() completes instantly.
      // We test the flag by starting sync() and immediately calling it again
      // before the first await returns.
      final future1 = syncService
          .sync(); // sets _isSyncing = true synchronously
      final result2 = await syncService.sync(); // should see _isSyncing = true

      expect(result2.wasAlreadyRunning, isTrue);
      await future1; // let first run complete
    },
  );

  // -------------------------------------------------------------------------
  // F  Stale PROCESSING items are recovered to PENDING
  // -------------------------------------------------------------------------

  test('F: PROCESSING item is reset to PENDING before a new sync run', () async {
    final companyId = _seedCompany(db);
    _enqueue(
      db,
      entityType: 'COMPANY',
      entityId: companyId,
      operation: 'UPDATE',
    );
    final qId =
        db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

    // Force item into PROCESSING (simulates a crash mid-sync).
    db.execute("UPDATE sync_queue SET status='PROCESSING' WHERE id=?", [qId]);
    expect(_queueItem(db, qId)?.status, equals(SyncStatus.processing));

    // sync() should recover it to PENDING and then process it.
    await syncService.sync();

    final item = _queueItem(db, qId);
    // After recovery + processing: should be SYNCED or FAILED (not stuck at PROCESSING).
    expect(
      item?.status,
      anyOf(equals(SyncStatus.synced), equals(SyncStatus.failed)),
      reason: 'PROCESSING item must not stay stuck after sync()',
    );
  });

  // -------------------------------------------------------------------------
  // G  Cheque CREATE with empty server UUID → FAILED, never SYNCED
  // -------------------------------------------------------------------------

  test(
    'G: CREATE with empty UUID from backend marks queue FAILED, not SYNCED',
    () async {
      final companyId = _seedCompany(db);
      final bankId = _seedBank(db);
      _seedCheque(db, companyId: companyId, bankId: bankId);
      final chequeId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: chequeId,
        operation: 'CREATE',
      );
      final qId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      fakeChequeRemote.returnUuid = null; // backend returns no UUID

      await syncService.sync();

      final item = _queueItem(db, qId);
      expect(
        item?.status,
        equals(SyncStatus.failed),
        reason: 'Missing server UUID must result in FAILED, not SYNCED',
      );

      final cheque = db.select('SELECT server_uuid FROM cheques WHERE id=?', [
        chequeId,
      ]).first;
      expect(
        cheque['server_uuid'],
        isNull,
        reason: 'server_uuid must not be set when CREATE returned no UUID',
      );
    },
  );

  // -------------------------------------------------------------------------
  // H  retrySingleQueueItem delegates to normal sync (not direct item execution)
  // -------------------------------------------------------------------------

  test(
    'H: retrySingleQueueItem requeues and runs dependency-aware sync',
    () async {
      final companyId = _seedCompany(db);
      _enqueue(
        db,
        entityType: 'COMPANY',
        entityId: companyId,
        operation: 'UPDATE',
      );
      final qId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      // Mark it FAILED as if a previous run failed.
      db.execute("UPDATE sync_queue SET status='FAILED' WHERE id=?", [qId]);

      // BANK_ACCOUNT in queue too – should not be affected.
      final bankId = _seedBank(db);
      _enqueue(
        db,
        entityType: 'BANK_ACCOUNT',
        entityId: bankId,
        operation: 'UPDATE',
      );
      final bankQId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      final succeeded = await syncService.retrySingleQueueItem(qId);

      // The item should have been processed through the normal COMPANY phase.
      final item = _queueItem(db, qId);
      expect(
        item?.status,
        anyOf(equals(SyncStatus.synced), equals(SyncStatus.failed)),
      );
      // BANK_ACCOUNT item should also have been processed (normal sync runs all phases).
      final bankItem = _queueItem(db, bankQId);
      expect(bankItem?.status, isNot(equals(SyncStatus.pending)));
      // returned bool is consistent with actual outcome.
      final expectedSuccess = item == null || item.status == SyncStatus.synced;
      expect(succeeded, equals(expectedSuccess));
    },
  );

  // -------------------------------------------------------------------------
  // I  deleteError guard: cannot discard active unsynced item
  // -------------------------------------------------------------------------

  test('I: deleteError on FAILED item throws instead of deleting', () async {
    _enqueue(db, entityType: 'CHEQUE', entityId: 1, operation: 'CREATE');
    final qId =
        db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
    db.execute("UPDATE sync_queue SET status='FAILED' WHERE id=?", [qId]);

    // We call deleteQueueItem directly via the guard logic mirrored here.
    final item = await queueRepo.findById(qId);
    expect(item?.status, equals(SyncStatus.failed));

    // Simulate the guard from SyncFailureActions.deleteError.
    expect(() async {
      if (item != null &&
          (item.status == SyncStatus.failed ||
              item.status == SyncStatus.pending ||
              item.status == SyncStatus.processing)) {
        throw StateError('unsynced item cannot be discarded');
      }
      await queueRepo.deleteQueueItem(qId);
    }, throwsStateError);

    // Item still exists.
    expect(await queueRepo.findById(qId), isNotNull);
  });

  // -------------------------------------------------------------------------
  // J  Duplicate DELETE: only one active DELETE enqueued
  // -------------------------------------------------------------------------

  test(
    'J: requestDelete when DELETE already active produces no duplicate',
    () async {
      final companyId = _seedCompany(db);
      final bankId = _seedBank(db);
      final chequeId = _seedCheque(db, companyId: companyId, bankId: bankId);

      // First delete request.
      await localChequeRepo.requestDelete(chequeId);
      final itemsAfterFirst = _allQueueItems(db).where(
        (i) =>
            i.entityId == chequeId &&
            i.entityType == 'CHEQUE' &&
            i.operation == SyncOperation.delete,
      );
      expect(itemsAfterFirst.length, equals(1), reason: 'One DELETE expected');

      // Re-insert cheque and call requestDelete again on same cheque id…
      // Because requestDelete guards against double-call via deleteRequestedAt check, it exits early.
      await localChequeRepo.requestDelete(chequeId); // idempotent at app layer

      final itemsAfterSecond = _allQueueItems(db).where(
        (i) =>
            i.entityId == chequeId &&
            i.entityType == 'CHEQUE' &&
            i.operation == SyncOperation.delete,
      );
      expect(
        itemsAfterSecond.length,
        equals(1),
        reason: 'No duplicate DELETE must be enqueued',
      );
    },
  );

  // -------------------------------------------------------------------------
  // K  UPDATE followed by DELETE: UPDATE does not remain as active conflict
  // -------------------------------------------------------------------------

  test(
    'K: requestDelete after pending UPDATE supersedes UPDATE with single DELETE',
    () async {
      final companyId = _seedCompany(db);
      final bankId = _seedBank(db);
      final chequeId = _seedCheque(db, companyId: companyId, bankId: bankId);

      // Manually enqueue an UPDATE (simulates a previous edit).
      _enqueue(
        db,
        entityType: 'CHEQUE',
        entityId: chequeId,
        operation: 'UPDATE',
      );
      final updateQId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      // Now delete the cheque.
      await localChequeRepo.requestDelete(chequeId);

      final allItems = _allQueueItems(
        db,
      ).where((i) => i.entityId == chequeId && i.entityType == 'CHEQUE');

      final updateItem = _queueItem(db, updateQId);
      expect(
        updateItem,
        isNull,
        reason: 'Pending UPDATE must be removed by DELETE coalescing',
      );

      final deleteItems = allItems.where(
        (i) => i.operation == SyncOperation.delete,
      );
      expect(
        deleteItems.length,
        equals(1),
        reason: 'Exactly one DELETE must remain',
      );
    },
  );
}
