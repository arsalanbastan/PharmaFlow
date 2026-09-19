import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:pharmaflow/core/config/app_config.dart';
import 'package:pharmaflow/core/config/app_environment.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/identity/identity_bootstrap_service.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_engine.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();

  final settingsRepository = ConnectionSettingsRepository();
  final settings = await settingsRepository.load();
  final apiClient = ApiClient(
    appConfig: AppConfig(
      currentEnvironment: AppEnvironment.development,
      settings: settings,
    ),
  );

  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );
  final localBankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );
  final localChequeRepository = LocalChequeRepository(DatabaseService.instance);
  final syncQueueRepository = SyncQueueRepository(DatabaseService.instance);
  final syncIdentityResolver = SyncIdentityResolver(DatabaseService.instance);
  final remoteCompanyRepository = RemoteCompanyRepository(apiClient);
  final remoteBankAccountsRepository = RemoteBankAccountsRepository(apiClient);
  final remoteChequeRepository = RemoteChequeRepository(apiClient);
  final chequeIdentityResolver = ChequeSyncIdentityResolver(
    localChequeRepository: localChequeRepository,
    remoteChequeRepository: remoteChequeRepository,
    identityResolver: syncIdentityResolver,
  );

  final engine = SyncEngine(
    syncService: SyncService(
      syncQueueRepository: syncQueueRepository,
      localCompanyRepository: localCompanyRepository,
      localBankAccountRepository: localBankAccountRepository,
      localChequeRepository: localChequeRepository,
      identityResolver: syncIdentityResolver,
      remoteCompanyRepository: remoteCompanyRepository,
      remoteBankAccountsRepository: remoteBankAccountsRepository,
      remoteChequeRepository: remoteChequeRepository,
      chequeSyncIdentityResolver: chequeIdentityResolver,
    ),
    identityBootstrapService: IdentityBootstrapService(
      apiClient: apiClient,
      localCompanyRepository: localCompanyRepository,
      localBankAccountRepository: localBankAccountRepository,
    ),
    syncQueueRepository: syncQueueRepository,
    localCompanyRepository: localCompanyRepository,
    localBankAccountRepository: localBankAccountRepository,
    connectionSettingsRepository: settingsRepository,
  );

  final allCheques = await localChequeRepository.getAll(
    includeArchived: true,
    includeCancelled: true,
  );

  if (allCheques.isEmpty) {
    print(
      jsonEncode({
        'deletedChequeIds': <int>[],
        'queueEntriesCreated': <Map<String, Object?>>[],
        'syncResult': {
          'processed': 0,
          'succeeded': 0,
          'failed': 0,
          'postgresStillContainsAny': false,
          'sqliteStillContainsAny': false,
          'orphanQueueItemsForTargets': 0,
        },
        'remainingFailedCount': 0,
      }),
    );
    return;
  }

  final targets = [...allCheques]
    ..sort((a, b) {
      final byCreated = b.createdAt.compareTo(a.createdAt);
      if (byCreated != 0) return byCreated;
      return b.id.compareTo(a.id);
    });

  final selected = targets.take(7).toList(growable: false);
  final selectedIds = selected.map((c) => c.id).toSet();

  final selectedServerUuids = <int, String?>{};
  for (final cheque in selected) {
    String? serverUuid = cheque.serverUuid?.trim();
    if (serverUuid == null || serverUuid.isEmpty) {
      try {
        serverUuid = await chequeIdentityResolver.resolveServerUuid(cheque);
      } catch (_) {
        serverUuid = null;
      }
    }
    selectedServerUuids[cheque.id] = serverUuid;
  }

  final enqueueStartedAt = DateTime.now().millisecondsSinceEpoch;

  for (final cheque in selected) {
    await localChequeRepository.requestDelete(cheque.id);
  }

  final queueRowsStmt = DatabaseService.instance.database.prepare('''
SELECT
  id,
  entityType,
  entityId,
  operation,
  status,
  retryCount,
  errorMessage,
  createdAt,
  lastAttemptAt
FROM sync_queue
WHERE entityType = :entityType
  AND operation = :operation
  AND createdAt >= :createdAt
ORDER BY id ASC;
''');

  final createdDeleteRows = queueRowsStmt.selectWith(
    StatementParameters.named({
      ':entityType': 'CHEQUE',
      ':operation': SyncOperation.delete.dbValue,
      ':createdAt': enqueueStartedAt,
    }),
  );
  queueRowsStmt.dispose();

  final createdQueueEntries = createdDeleteRows
      .where((row) => selectedIds.contains(row['entityId'] as int))
      .map(
        (row) => {
          'id': row['id'],
          'entityType': row['entityType'],
          'entityId': row['entityId'],
          'operation': row['operation'],
          'status': row['status'],
          'retryCount': row['retryCount'],
          'lastError': row['errorMessage'],
          'createdAt': row['createdAt'],
          'updatedAt': row['lastAttemptAt'],
        },
      )
      .toList(growable: false);

  final syncResult = await engine.syncNow();

  final localMissingChecks = <int, bool>{};
  for (final id in selectedIds) {
    localMissingChecks[id] = (await localChequeRepository.findById(id)) == null;
  }

  final remoteAll = await remoteChequeRepository.getAll();
  final remoteIds = remoteAll.map((item) => item.id).toSet();
  var postgresStillContainsAny = false;
  for (final uuid in selectedServerUuids.values) {
    if (uuid == null || uuid.isEmpty) {
      continue;
    }
    if (remoteIds.contains(uuid)) {
      postgresStillContainsAny = true;
      break;
    }
  }

  final failedRowsStmt = DatabaseService.instance.database.prepare('''
SELECT id, entityType, entityId, operation, status, retryCount, errorMessage, createdAt, lastAttemptAt
FROM sync_queue
WHERE entityType = :entityType
  AND operation = :operation
  AND status = :status
ORDER BY id ASC;
''');

  final failedRows = failedRowsStmt.selectWith(
    StatementParameters.named({
      ':entityType': 'CHEQUE',
      ':operation': SyncOperation.delete.dbValue,
      ':status': SyncStatus.failed.dbValue,
    }),
  );
  failedRowsStmt.dispose();

  final failedForTargets = failedRows
      .where((row) => selectedIds.contains(row['entityId'] as int))
      .length;

  final remainingFailedCount = await syncQueueRepository.countByStatus(
    SyncStatus.failed,
  );

  final sqliteStillContainsAny = localMissingChecks.values.any(
    (isMissing) => !isMissing,
  );

  print(
    const JsonEncoder.withIndent('  ').convert({
      'deletedChequeIds': [for (final c in selected) c.id],
      'queueEntriesCreated': createdQueueEntries,
      'syncResult': {
        'processed': syncResult.processed,
        'succeeded': syncResult.succeeded,
        'failed': syncResult.failed,
        'sqliteStillContainsAny': sqliteStillContainsAny,
        'postgresStillContainsAny': postgresStillContainsAny,
        'orphanQueueItemsForTargets': failedForTargets,
      },
      'remainingFailedCount': remainingFailedCount,
    }),
  );
}
