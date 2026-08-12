import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pharmaflow/core/config/app_config.dart';
import 'package:pharmaflow/core/config/app_environment.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/identity/identity_bootstrap_service.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_engine.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
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

  final cheques = await localChequeRepository.getAll(
    includeArchived: true,
    includeCancelled: true,
  );

  if (cheques.isEmpty) {
    stdout.writeln('Cleanup result: no local cheques found.');
    exit(0);
  }

  final resolvedServerUuids = <int, String>{};
  for (final cheque in cheques) {
    final serverUuid = await chequeIdentityResolver.resolveServerUuid(cheque);
    resolvedServerUuids[cheque.id] = serverUuid;
  }

  for (final cheque in cheques) {
    await localChequeRepository.requestDelete(cheque.id);
  }

  final syncResult = await engine.syncNow();

  final localRemaining = await localChequeRepository.getAll(
    includeArchived: true,
    includeCancelled: true,
  );
  final remoteRemaining = await remoteChequeRepository.getAll();
  final remoteDeletedStillPresent = remoteRemaining
      .where((remoteCheque) {
        return resolvedServerUuids.values.contains(remoteCheque.id);
      })
      .toList(growable: false);

  final pendingCount = await syncQueueRepository.countByStatus(
    SyncStatus.pending,
  );
  final failedCount = await syncQueueRepository.countByStatus(
    SyncStatus.failed,
  );
  final processingCount = await syncQueueRepository.countByStatus(
    SyncStatus.processing,
  );

  stdout.writeln('Cleanup result');
  stdout.writeln('requestedDeleteCount = ${cheques.length}');
  stdout.writeln('syncProcessed = ${syncResult.processed}');
  stdout.writeln('syncSucceeded = ${syncResult.succeeded}');
  stdout.writeln('syncFailed = ${syncResult.failed}');
  stdout.writeln('localRemaining = ${localRemaining.length}');
  stdout.writeln(
    'backendRemainingMatched = ${remoteDeletedStillPresent.length}',
  );
  stdout.writeln('queuePending = $pendingCount');
  stdout.writeln('queueFailed = $failedCount');
  stdout.writeln('queueProcessing = $processingCount');
  exit(0);
}
