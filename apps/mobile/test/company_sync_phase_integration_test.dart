import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/company_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

class _FakeCompanyRemote extends RemoteCompanyRepository {
  _FakeCompanyRemote() : super(ApiClient());

  final List<RemoteCompanyChangesPage> pages = <RemoteCompanyChangesPage>[];
  Object? pullError;
  int updateCalls = 0;
  Map<String, dynamic>? lastUpdatePayload;

  @override
  Future<RemoteCompanyChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteCompanyRepository.defaultChangesLimit,
  }) async {
    final error = pullError;

    if (error != null) {
      throw error;
    }

    if (pages.isEmpty) {
      return RemoteCompanyChangesPage(
        items: const <RemoteCompanyChange>[],
        hasMore: false,
        nextCursor: cursor,
      );
    }

    return pages.removeAt(0);
  }

  @override
  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    updateCalls += 1;
    lastUpdatePayload = Map<String, dynamic>.from(payload);
  }
}

RemoteCompanyChange _remoteCompanyChange({
  required String uuid,
  required String name,
  required DateTime updatedAt,
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
      archivedAt: null,
      createdAt: updatedAt.subtract(const Duration(days: 1)),
      updatedAt: updatedAt,
    ),
    deletedAt: null,
  );
}

RemoteCompanyChangesPage _singlePage(RemoteCompanyChange change) {
  return RemoteCompanyChangesPage(
    items: <RemoteCompanyChange>[change],
    hasMore: false,
    nextCursor: SyncCursor(
      entityType: syncEntityTypeCompany,
      updatedAt: change.updatedAt,
      serverUuid: change.serverUuid,
    ),
  );
}

int _seedCompany(Database db, {required String uuid, required String name}) {
  final now = DateTime.utc(2026, 8, 13, 6).millisecondsSinceEpoch;

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
    <Object?>[uuid, name, now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

int _seedBankAccount(Database db) {
  final now = DateTime.utc(2026, 8, 13, 6).millisecondsSinceEpoch;

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
VALUES (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Test Bank',
  'Main',
  'Owner',
  '1',
  '2',
  'IR1',
  NULL,
  NULL,
  ?,
  ?
)
''',
    <Object?>[now, now],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

void _enqueue(
  Database db, {
  required String entityType,
  required int entityId,
  required SyncOperation operation,
}) {
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
    <Object?>[
      entityType,
      entityId,
      operation.dbValue,
      SyncStatus.pending.dbValue,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}

void main() {
  late Database db;
  late SyncQueueRepository queueRepository;
  late LocalCompanyRepository localCompanyRepository;
  late LocalBankAccountRepository localBankAccountRepository;
  late LocalChequeRepository localChequeRepository;
  late SyncIdentityResolver identityResolver;
  late _FakeCompanyRemote companyRemote;
  late RemoteBankAccountsRepository bankRemote;
  late RemoteChequeRepository chequeRemote;
  late SyncCursorRepository cursorRepository;
  late CompanyPullMergeService companyPullMergeService;
  late SyncService syncService;
  late int companyRefreshCalls;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    queueRepository = SyncQueueRepository(DatabaseService.instance);
    localCompanyRepository = LocalCompanyRepository(DatabaseService.instance);
    localBankAccountRepository = LocalBankAccountRepository(
      DatabaseService.instance,
    );
    localChequeRepository = LocalChequeRepository(DatabaseService.instance);
    identityResolver = SyncIdentityResolver(DatabaseService.instance);

    companyRemote = _FakeCompanyRemote();
    bankRemote = RemoteBankAccountsRepository(ApiClient());
    chequeRemote = RemoteChequeRepository(ApiClient());

    cursorRepository = SyncCursorRepository(DatabaseService.instance);

    companyRefreshCalls = 0;

    companyPullMergeService = CompanyPullMergeService(
      databaseService: DatabaseService.instance,
      remoteRepository: companyRemote,
      cursorRepository: cursorRepository,
    );

    syncService = SyncService(
      syncQueueRepository: queueRepository,
      localCompanyRepository: localCompanyRepository,
      localBankAccountRepository: localBankAccountRepository,
      localChequeRepository: localChequeRepository,
      identityResolver: identityResolver,
      remoteCompanyRepository: companyRemote,
      remoteBankAccountsRepository: bankRemote,
      remoteChequeRepository: chequeRemote,
      chequeSyncIdentityResolver: ChequeSyncIdentityResolver(
        localChequeRepository: localChequeRepository,
        remoteChequeRepository: chequeRemote,
        identityResolver: identityResolver,
      ),
      companyPullMergeService: companyPullMergeService,
      onCompanyPullMerged: (result) async {
        companyRefreshCalls += 1;
      },
    );
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'empty queue still performs COMPANY pull and merges remote data',
    () async {
      final change = _remoteCompanyChange(
        uuid: '11111111-1111-4111-8111-111111111111',
        name: 'Remote Company',
        notes: 'from-server',
        updatedAt: DateTime.utc(2026, 8, 13, 7),
      );

      companyRemote.pages.add(_singlePage(change));

      final result = await syncService.sync();

      expect(result.hasFailures, isFalse);
      expect(result.processed, equals(0));
      expect(result.performedServerCheck, isTrue);
      expect(
        companyRefreshCalls,
        equals(1),
        reason: 'Changed COMPANY data must trigger refresh before next phase.',
      );

      final rows = db.select(
        '''
SELECT server_uuid, name, notes
FROM companies
WHERE server_uuid = ?
''',
        <Object?>[change.serverUuid],
      );

      expect(rows.length, equals(1));
      expect(rows.first['name'], equals('Remote Company'));
      expect(rows.first['notes'], equals('from-server'));

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCompany,
      );

      expect(cursor, isNotNull);
      expect(cursor!.serverUuid, equals(change.serverUuid));
    },
  );

  test('COMPANY push completes before COMPANY pull merge', () async {
    const uuid = '22222222-2222-4222-8222-222222222222';

    final companyId = _seedCompany(db, uuid: uuid, name: 'Local Name');

    _enqueue(
      db,
      entityType: syncEntityTypeCompany,
      entityId: companyId,
      operation: SyncOperation.update,
    );

    final remoteChange = _remoteCompanyChange(
      uuid: uuid,
      name: 'Server Name',
      notes: 'server-version',
      updatedAt: DateTime.utc(2026, 8, 13, 8),
    );

    companyRemote.pages.add(_singlePage(remoteChange));

    final result = await syncService.sync();

    expect(result.hasFailures, isFalse);
    expect(companyRemote.updateCalls, equals(1));
    expect(
      companyRefreshCalls,
      equals(1),
      reason: 'Merged COMPANY update must refresh dependent providers.',
    );

    final pushedPayload = companyRemote.lastUpdatePayload;
    expect(pushedPayload, isNotNull);
    expect(
      pushedPayload!.containsKey('updatedAt'),
      isFalse,
      reason: 'Server updatedAt must remain server-owned.',
    );
    expect(pushedPayload.containsKey('notes'), isTrue);
    expect(pushedPayload['notes'], isNull);
    expect(pushedPayload.containsKey('archivedAt'), isTrue);
    expect(pushedPayload['archivedAt'], isNull);

    final queueRow = db
        .select(
          '''
SELECT status
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
''',
          <Object?>[syncEntityTypeCompany, companyId],
        )
        .first;

    expect(queueRow['status'], equals(SyncStatus.synced.dbValue));

    final companyRow = db
        .select(
          '''
SELECT name, notes, updated_at
FROM companies
WHERE id = ?
''',
          <Object?>[companyId],
        )
        .first;

    expect(companyRow['name'], equals('Server Name'));
    expect(companyRow['notes'], equals('server-version'));
    expect(
      companyRow['updated_at'],
      equals(remoteChange.updatedAt.millisecondsSinceEpoch),
    );
  });

  test(
    'COMPANY pull connectivity failure stops before BANK_ACCOUNT push',
    () async {
      final bankId = _seedBankAccount(db);

      _enqueue(
        db,
        entityType: syncEntityTypeBankAccount,
        entityId: bankId,
        operation: SyncOperation.update,
      );

      companyRemote.pullError = const ApiNetworkException(
        'company pull unreachable',
      );

      final result = await syncService.sync();

      expect(result.serverUnavailable, isTrue);
      expect(result.stoppedAtPhase, equals(syncEntityTypeCompany));
      expect(result.failed, equals(1));

      final bankQueueRow = db
          .select(
            '''
SELECT status
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
''',
            <Object?>[syncEntityTypeBankAccount, bankId],
          )
          .first;

      expect(
        bankQueueRow['status'],
        equals(SyncStatus.pending.dbValue),
        reason: 'BANK_ACCOUNT must remain untouched when COMPANY pull fails.',
      );
    },
  );
}
