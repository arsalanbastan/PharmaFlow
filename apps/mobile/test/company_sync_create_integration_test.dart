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
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

class _FakeCompanyRemote extends RemoteCompanyRepository {
  _FakeCompanyRemote() : super(ApiClient());

  String? forcedReturnedUuid;
  int createCalls = 0;
  final List<Map<String, dynamic>> createPayloads = <Map<String, dynamic>>[];

  @override
  Future<String> createWithClientUuid(Map<String, dynamic> payload) async {
    createCalls += 1;
    createPayloads.add(Map<String, dynamic>.from(payload));

    final requestedUuid = payload['id'];
    if (requestedUuid is! String || requestedUuid.trim().isEmpty) {
      throw StateError('Test received Company CREATE without client UUID.');
    }

    return forcedReturnedUuid ?? requestedUuid.trim();
  }
}

Company _newCompany(String name, {String? notes}) {
  final now = DateTime.now();

  return Company(
    id: null,
    serverUuid: null,
    name: name,
    nationalId: null,
    economicCode: null,
    notes: notes,
    visitorName: null,
    visitorPhone: null,
    accountantName: null,
    accountantPhone: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

List<SyncQueueItem> _companyQueueItems(Database db, int companyId) {
  final rows = db.select(
    '''
SELECT *
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
ORDER BY id ASC
''',
    <Object?>[syncEntityTypeCompany, companyId],
  );

  return rows
      .map((row) => SyncQueueItem.fromDbMap(row))
      .toList(growable: false);
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
  late SyncService syncService;

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
    );
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'COMPANY CREATE sends the locally generated UUID and marks queue SYNCED only after matching response',
    () async {
      final companyId = await localCompanyRepository.insert(
        _newCompany(
          'Create Integration Success',
          notes: 'latest-local-snapshot',
        ),
      );

      final beforeSync = await localCompanyRepository.findById(companyId);
      expect(beforeSync, isNotNull);

      final localUuid = beforeSync!.serverUuid;
      expect(localUuid, isNotNull);
      expect(localUuid!.trim(), isNotEmpty);

      final beforeQueue = _companyQueueItems(db, companyId);
      expect(beforeQueue.length, equals(1));
      expect(beforeQueue.single.operation, SyncOperation.create);
      expect(beforeQueue.single.status, SyncStatus.pending);

      final result = await syncService.sync();

      expect(result.hasFailures, isFalse);
      expect(result.processed, equals(1));
      expect(result.succeeded, equals(1));
      expect(companyRemote.createCalls, equals(1));

      expect(companyRemote.createPayloads.length, equals(1));
      final payload = companyRemote.createPayloads.single;
      expect(payload['id'], equals(localUuid));
      expect(payload['name'], equals('Create Integration Success'));
      expect(payload['notes'], equals('latest-local-snapshot'));

      final afterQueue = _companyQueueItems(db, companyId);
      expect(afterQueue.length, equals(1));
      expect(afterQueue.single.operation, SyncOperation.create);
      expect(afterQueue.single.status, SyncStatus.synced);

      final afterSync = await localCompanyRepository.findById(companyId);
      expect(afterSync, isNotNull);
      expect(afterSync!.serverUuid, equals(localUuid));
    },
  );

  test(
    'COMPANY CREATE UUID mismatch leaves the local UUID intact and marks queue FAILED',
    () async {
      final companyId = await localCompanyRepository.insert(
        _newCompany('Create Integration Mismatch'),
      );

      final beforeSync = await localCompanyRepository.findById(companyId);
      expect(beforeSync, isNotNull);

      final localUuid = beforeSync!.serverUuid;
      expect(localUuid, isNotNull);
      expect(localUuid!.trim(), isNotEmpty);

      companyRemote.forcedReturnedUuid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

      final result = await syncService.sync();

      expect(result.hasFailures, isTrue);
      expect(result.processed, equals(1));
      expect(result.succeeded, equals(0));
      expect(result.failed, equals(1));
      expect(result.stoppedAtPhase, equals(syncEntityTypeCompany));
      expect(companyRemote.createCalls, equals(1));

      final payload = companyRemote.createPayloads.single;
      expect(payload['id'], equals(localUuid));

      final afterQueue = _companyQueueItems(db, companyId);
      expect(afterQueue.length, equals(1));
      expect(afterQueue.single.operation, SyncOperation.create);
      expect(afterQueue.single.status, SyncStatus.failed);

      final afterSync = await localCompanyRepository.findById(companyId);
      expect(afterSync, isNotNull);
      expect(
        afterSync!.serverUuid,
        equals(localUuid),
        reason:
            'A mismatched server response must never replace local identity.',
      );
    },
  );
}
