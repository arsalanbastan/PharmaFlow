import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/identity/identity_bootstrap_service.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/network/models/health_response.dart';
import 'package:pharmaflow/core/settings/connection_profile.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_engine.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_state.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/core/sync/sync_trigger.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient({required this.onCheckHealth});

  final Future<HealthResponse> Function() onCheckHealth;
  int healthCheckCalls = 0;

  @override
  Future<HealthResponse> checkHealth() async {
    healthCheckCalls += 1;
    return onCheckHealth();
  }
}

class _ConfigurableCompanyRemote extends RemoteCompanyRepository {
  _ConfigurableCompanyRemote() : super(ApiClient());

  Object? throwError;
  int callCount = 0;

  @override
  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    callCount += 1;
    final error = throwError;
    if (error != null) {
      throw error;
    }
  }
}

class _ConfigurableBankRemote extends RemoteBankAccountsRepository {
  _ConfigurableBankRemote() : super(ApiClient());

  Object? throwError;
  int callCount = 0;

  @override
  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    callCount += 1;
    final error = throwError;
    if (error != null) {
      throw error;
    }
  }
}

class _ConfigurableChequeRemote extends RemoteChequeRepository {
  _ConfigurableChequeRemote() : super(ApiClient());

  Object? throwCreateError;
  int createCount = 0;
  int updateCount = 0;

  @override
  Future<String?> create(Map<String, dynamic> payload) async {
    createCount += 1;
    final error = throwCreateError;
    if (error != null) {
      throw error;
    }
    return 'server-cheque-uuid';
  }

  @override
  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    updateCount += 1;
  }
}

class _StubSyncService extends SyncService {
  _StubSyncService({
    required super.syncQueueRepository,
    required super.localCompanyRepository,
    required super.localBankAccountRepository,
    required super.localChequeRepository,
    required super.identityResolver,
    required super.remoteCompanyRepository,
    required super.remoteBankAccountsRepository,
    required super.remoteChequeRepository,
    required super.chequeSyncIdentityResolver,
  });

  int syncCalls = 0;
  Future<SyncServiceResult> Function()? onSync;

  @override
  Future<SyncServiceResult> sync() async {
    syncCalls += 1;
    final handler = onSync;
    if (handler != null) {
      return handler();
    }
    return super.sync();
  }
}

class _FakeChequeResolver extends ChequeSyncIdentityResolver {
  _FakeChequeResolver(
    LocalChequeRepository localRepo,
    _ConfigurableChequeRemote remoteRepo,
    SyncIdentityResolver identityResolver,
  ) : super(
        localChequeRepository: localRepo,
        remoteChequeRepository: remoteRepo,
        identityResolver: identityResolver,
      );

  @override
  Future<String> resolveServerUuid(Cheque cheque) async {
    final existing = cheque.serverUuid?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    return 'server-uuid-${cheque.id}';
  }
}

void main() {
  late Database db;
  late SyncQueueRepository queueRepo;
  late LocalCompanyRepository localCompanyRepo;
  late LocalBankAccountRepository localBankRepo;
  late LocalChequeRepository localChequeRepo;
  late SyncIdentityResolver identityResolver;
  late _ConfigurableCompanyRemote companyRemote;
  late _ConfigurableBankRemote bankRemote;
  late _ConfigurableChequeRemote chequeRemote;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    queueRepo = SyncQueueRepository(DatabaseService.instance);
    localCompanyRepo = LocalCompanyRepository(DatabaseService.instance);
    localBankRepo = LocalBankAccountRepository(DatabaseService.instance);
    localChequeRepo = LocalChequeRepository(DatabaseService.instance);
    identityResolver = SyncIdentityResolver(DatabaseService.instance);

    companyRemote = _ConfigurableCompanyRemote();
    bankRemote = _ConfigurableBankRemote();
    chequeRemote = _ConfigurableChequeRemote();
  });

  tearDown(() {
    db.dispose();
  });

  group('SyncService connectivity stop and queue safety', () {
    test(
      'global connectivity failure stops run immediately and preserves unprocessed queue items',
      () async {
        final service = SyncService(
          syncQueueRepository: queueRepo,
          localCompanyRepository: localCompanyRepo,
          localBankAccountRepository: localBankRepo,
          localChequeRepository: localChequeRepo,
          identityResolver: identityResolver,
          remoteCompanyRepository: companyRemote,
          remoteBankAccountsRepository: bankRemote,
          remoteChequeRepository: chequeRemote,
          chequeSyncIdentityResolver: _FakeChequeResolver(
            localChequeRepo,
            chequeRemote,
            identityResolver,
          ),
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        db.execute(
          '''
          INSERT INTO companies (
            server_uuid,name,national_id,economic_code,notes,visitor_name,visitor_phone,
            accountant_name,accountant_phone,archived_at,created_at,updated_at
          ) VALUES ('company-uuid', 'Company A', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
          ''',
          [now, now],
        );
        final companyId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
          INSERT INTO bank_accounts (
            server_uuid,bank_name,account_title,account_holder,account_number,
            card_number,iban,note,archived_at,created_at,updated_at
          ) VALUES ('bank-uuid', 'Bank A', 'Title A', 'Holder', '1', '2', 'IR1', NULL, NULL, ?, ?)
          ''',
          [now, now],
        );
        final bankId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
          INSERT INTO cheques (
            server_uuid,company_id,bank_account_id,receiver_name,cheque_number,amount_rial,
            issue_date,due_date,status,is_registered_in_sayad,sayad_id,description,image_data,
            archived_at,delete_requested_at,created_at,updated_at
          ) VALUES (NULL, ?, ?, NULL, '1001', 1000, ?, ?, 'Issued', 0, NULL, NULL, NULL, NULL, NULL, ?, ?)
          ''',
          [companyId, bankId, now, now, now, now],
        );
        final chequeId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
          INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
          VALUES ('COMPANY', ?, 'UPDATE', 'PENDING', 0, ?)
          ''',
          [companyId, now],
        );
        final companyQueueId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
          INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
          VALUES ('BANK_ACCOUNT', ?, 'UPDATE', 'PENDING', 0, ?)
          ''',
          [bankId, now + 1],
        );
        final bankQueueId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
          INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
          VALUES ('CHEQUE', ?, 'CREATE', 'PENDING', 0, ?)
          ''',
          [chequeId, now + 2],
        );
        final chequeQueueId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        companyRemote.throwError = const ApiNetworkException('unreachable');

        final result = await service.sync();

        expect(result.serverUnavailable, isTrue);
        expect(result.stoppedAtPhase, equals('COMPANY'));
        expect(
          result.failureDetails?.type,
          equals(SyncFailureType.serverConnectivity),
        );

        final companyRow = db.select(
          'SELECT status FROM sync_queue WHERE id = ?',
          [companyQueueId],
        );
        final bankRow = db.select(
          'SELECT status FROM sync_queue WHERE id = ?',
          [bankQueueId],
        );
        final chequeRow = db.select(
          'SELECT status FROM sync_queue WHERE id = ?',
          [chequeQueueId],
        );

        expect(companyRow.first['status'], equals(SyncStatus.failed.dbValue));
        expect(bankRow.first['status'], equals(SyncStatus.pending.dbValue));
        expect(chequeRow.first['status'], equals(SyncStatus.pending.dbValue));
        expect(bankRemote.callCount, equals(0));
        expect(chequeRemote.createCount + chequeRemote.updateCount, equals(0));
      },
    );

    test(
      'HTTP 400 is not server-unavailable and remains HTTP/API classified',
      () async {
        final service = SyncService(
          syncQueueRepository: queueRepo,
          localCompanyRepository: localCompanyRepo,
          localBankAccountRepository: localBankRepo,
          localChequeRepository: localChequeRepo,
          identityResolver: identityResolver,
          remoteCompanyRepository: companyRemote,
          remoteBankAccountsRepository: bankRemote,
          remoteChequeRepository: chequeRemote,
          chequeSyncIdentityResolver: _FakeChequeResolver(
            localChequeRepo,
            chequeRemote,
            identityResolver,
          ),
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        db.execute(
          '''
        INSERT INTO companies (
          server_uuid,name,national_id,economic_code,notes,visitor_name,visitor_phone,
          accountant_name,accountant_phone,archived_at,created_at,updated_at
        ) VALUES ('company-uuid', 'Company A', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
        ''',
          [now, now],
        );
        final companyId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        db.execute(
          '''
        INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
        VALUES ('COMPANY', ?, 'UPDATE', 'PENDING', 0, ?)
        ''',
          [companyId, now],
        );

        companyRemote.throwError = const ApiHttpException(
          statusCode: 400,
          message: 'bad request',
        );

        final result = await service.sync();

        expect(result.serverUnavailable, isFalse);
        expect(result.hasFailures, isTrue);
        expect(result.stoppedAtPhase, equals('COMPANY'));
      },
    );
  });

  group('SyncEngine truthful metadata and retry suspension', () {
    late ConnectionSettingsRepository settingsRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsRepo = ConnectionSettingsRepository();
    });

    Future<SyncEngine> buildEngine({
      required SyncService syncService,
      required _FakeApiClient apiClient,
    }) async {
      final identityBootstrapService = IdentityBootstrapService(
        apiClient: apiClient,
        localCompanyRepository: localCompanyRepo,
        localBankAccountRepository: localBankRepo,
      );

      return SyncEngine(
        syncService: syncService,
        apiClient: apiClient,
        identityBootstrapService: identityBootstrapService,
        syncQueueRepository: queueRepo,
        localCompanyRepository: localCompanyRepo,
        localBankAccountRepository: localBankRepo,
        connectionSettingsRepository: settingsRepo,
      );
    }

    Future<SyncService> buildStubService({
      required Future<SyncServiceResult> Function() onSync,
    }) async {
      final stub = _StubSyncService(
        syncQueueRepository: queueRepo,
        localCompanyRepository: localCompanyRepo,
        localBankAccountRepository: localBankRepo,
        localChequeRepository: localChequeRepo,
        identityResolver: identityResolver,
        remoteCompanyRepository: companyRemote,
        remoteBankAccountsRepository: bankRemote,
        remoteChequeRepository: chequeRemote,
        chequeSyncIdentityResolver: _FakeChequeResolver(
          localChequeRepo,
          chequeRemote,
          identityResolver,
        ),
      );
      stub.onSync = onSync;
      return stub;
    }

    test(
      'failed attempt updates lastSyncAttemptAt but preserves lastSuccessfulSyncAt and suspends after three connectivity failures',
      () async {
        final oldSuccess = DateTime(2026, 1, 1, 10, 0, 0);
        final initial = ConnectionSettingsDefaults.defaultSettings.copyWith(
          lastSuccessfulSyncAt: oldSuccess,
        );
        await settingsRepo.save(initial);

        final apiClient = _FakeApiClient(
          onCheckHealth: () async {
            throw const ApiNetworkException('no route to host');
          },
        );

        final stubService = await buildStubService(
          onSync: () async {
            return const SyncServiceResult(
              totalPending: 0,
              processed: 0,
              succeeded: 0,
              failed: 0,
            );
          },
        );

        final engine = await buildEngine(
          syncService: stubService,
          apiClient: apiClient,
        );

        final result = await engine.syncNow();
        final saved = await settingsRepo.load();

        expect(result.serverUnavailable, isTrue);
        expect(apiClient.healthCheckCalls, equals(3));
        expect(saved.lastSuccessfulSyncAt, equals(oldSuccess));
        expect(saved.lastSyncAttemptAt, isNotNull);
        expect(saved.consecutiveConnectionFailures, equals(3));
        expect(saved.autoRetrySuspended, isTrue);
        expect(
          engine.state.syncStatus,
          equals(SyncUiStatus.autoRetrySuspended),
        );
      },
    );

    test(
      'suspended automatic retry does not restart on non-manual triggers',
      () async {
        final suspended = ConnectionSettingsDefaults.defaultSettings.copyWith(
          consecutiveConnectionFailures: 3,
          autoRetrySuspended: true,
        );
        await settingsRepo.save(suspended);

        final apiClient = _FakeApiClient(
          onCheckHealth: () async => const HealthResponse(status: 'ok'),
        );

        final stubService = await buildStubService(
          onSync: () async {
            return const SyncServiceResult(
              totalPending: 0,
              processed: 0,
              succeeded: 0,
              failed: 0,
              performedServerCheck: true,
            );
          },
        );

        final engine = await buildEngine(
          syncService: stubService,
          apiClient: apiClient,
        );

        await engine.requestSync(trigger: SyncTrigger.periodic);
        await engine.requestSync(trigger: SyncTrigger.connectivityRestored);

        expect(apiClient.healthCheckCalls, equals(0));
        expect(engine.state.autoRetrySuspended, isTrue);
      },
    );

    test(
      'manual retry clears suspension and runs a normal sync attempt',
      () async {
        final suspended = ConnectionSettingsDefaults.defaultSettings.copyWith(
          consecutiveConnectionFailures: 3,
          autoRetrySuspended: true,
        );
        await settingsRepo.save(suspended);

        final apiClient = _FakeApiClient(
          onCheckHealth: () async => const HealthResponse(status: 'ok'),
        );

        final stubService =
            await buildStubService(
                  onSync: () async {
                    return const SyncServiceResult(
                      totalPending: 1,
                      processed: 1,
                      succeeded: 1,
                      failed: 0,
                      performedServerCheck: true,
                    );
                  },
                )
                as _StubSyncService;

        final now = DateTime.now().millisecondsSinceEpoch;
        db.execute(
          '''
        INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
        VALUES ('COMPANY', 1, 'UPDATE', 'PENDING', 0, ?)
        ''',
          [now],
        );

        final engine = await buildEngine(
          syncService: stubService,
          apiClient: apiClient,
        );

        final result = await engine.retryManually();
        final saved = await settingsRepo.load();

        expect(result.hasFailures, isFalse);
        expect(stubService.syncCalls, equals(1));
        expect(saved.autoRetrySuspended, isFalse);
        expect(saved.consecutiveConnectionFailures, equals(0));
      },
    );

    test('HTTP 500 response is not classified as server-unavailable', () async {
      final apiClient = _FakeApiClient(
        onCheckHealth: () async {
          throw const ApiHttpException(
            statusCode: 500,
            message: 'server error',
          );
        },
      );

      final stubService = await buildStubService(
        onSync: () async {
          return const SyncServiceResult(
            totalPending: 0,
            processed: 0,
            succeeded: 0,
            failed: 0,
          );
        },
      );

      final engine = await buildEngine(
        syncService: stubService,
        apiClient: apiClient,
      );

      final result = await engine.syncNow();
      final saved = await settingsRepo.load();

      expect(result.serverUnavailable, isFalse);
      expect(result.hasFailures, isTrue);
      expect(apiClient.healthCheckCalls, equals(1));
      expect(saved.consecutiveConnectionFailures, equals(0));
      expect(saved.autoRetrySuspended, isFalse);
    });

    test(
      'alreadyRunning result does not update lastSuccessfulSyncAt',
      () async {
        final oldSuccess = DateTime(2026, 2, 2, 10, 0, 0);
        await settingsRepo.save(
          ConnectionSettingsDefaults.defaultSettings.copyWith(
            lastSuccessfulSyncAt: oldSuccess,
          ),
        );

        final apiClient = _FakeApiClient(
          onCheckHealth: () async => const HealthResponse(status: 'ok'),
        );

        final stubService = await buildStubService(
          onSync: () async {
            return const SyncServiceResult(
              totalPending: 1,
              processed: 0,
              succeeded: 0,
              failed: 0,
              wasAlreadyRunning: true,
              performedServerCheck: true,
            );
          },
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        db.execute(
          '''
        INSERT INTO sync_queue (entityType, entityId, operation, status, retryCount, createdAt)
        VALUES ('COMPANY', 1, 'UPDATE', 'PENDING', 0, ?)
        ''',
          [now],
        );

        final engine = await buildEngine(
          syncService: stubService,
          apiClient: apiClient,
        );

        await engine.syncNow();
        final saved = await settingsRepo.load();
        expect(saved.lastSuccessfulSyncAt, equals(oldSuccess));
      },
    );

    test(
      'successful sync after previous failures resets counters and updates lastSuccessfulSyncAt',
      () async {
        await settingsRepo.save(
          ConnectionSettingsDefaults.defaultSettings.copyWith(
            consecutiveConnectionFailures: 3,
            autoRetrySuspended: true,
            lastSuccessfulSyncAt: DateTime(2026, 1, 1, 0, 0, 0),
          ),
        );

        final apiClient = _FakeApiClient(
          onCheckHealth: () async => const HealthResponse(status: 'ok'),
        );

        final stubService = await buildStubService(
          onSync: () async {
            return const SyncServiceResult(
              totalPending: 0,
              processed: 0,
              succeeded: 0,
              failed: 0,
              performedServerCheck: true,
            );
          },
        );

        final engine = await buildEngine(
          syncService: stubService,
          apiClient: apiClient,
        );

        final result = await engine.retryManually();
        final saved = await settingsRepo.load();

        expect(result.hasFailures, isFalse);
        expect(saved.lastSuccessfulSyncAt, isNotNull);
        expect(saved.consecutiveConnectionFailures, equals(0));
        expect(saved.autoRetrySuspended, isFalse);
        expect(engine.state.syncStatus, equals(SyncUiStatus.success));
      },
    );
  });
}
