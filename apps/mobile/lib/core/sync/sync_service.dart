import '../network/api_client.dart';
import '../../data/models/bank_account.dart';
import '../../data/models/cheque.dart';
import '../../data/models/company.dart';
import '../../data/repositories/local/local_bank_account_repository.dart';
import '../../data/repositories/local/sync_queue_repository.dart';
import '../../data/repositories/local/local_cheque_repository.dart';
import '../../data/repositories/local/local_company_repository.dart';
import '../../data/repositories/remote/remote_bank_accounts_repository.dart';
import '../../data/repositories/remote/remote_cheque_repository.dart';
import '../../data/repositories/remote/remote_company_repository.dart';
import 'cheque_sync_identity_resolver.dart';
import 'sync_identity_resolver.dart';
import 'sync_logger.dart';
import 'sync_operation.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

enum SyncFailureType { serverConnectivity, httpApi, localData, unknown }

class SyncFailureDetails {
  const SyncFailureDetails({
    required this.type,
    required this.userSafeMessage,
    required this.technicalMessage,
  });

  final SyncFailureType type;
  final String userSafeMessage;
  final String technicalMessage;
}

class SyncConnectivityFailureException implements Exception {
  const SyncConnectivityFailureException({
    required this.details,
    required this.processed,
    required this.succeeded,
    required this.failed,
  });

  final SyncFailureDetails details;
  final int processed;
  final int succeeded;
  final int failed;
}

class SyncServiceResult {
  const SyncServiceResult({
    required this.totalPending,
    required this.processed,
    required this.succeeded,
    required this.failed,
    this.wasAlreadyRunning = false,
    this.stoppedAtPhase,
    this.serverUnavailable = false,
    this.failureDetails,
    this.performedServerCheck = false,
  });

  final int totalPending;
  final int processed;
  final int succeeded;
  final int failed;
  // True when sync() was invoked while a previous run was already in progress.
  final bool wasAlreadyRunning;
  // Non-null when execution stopped early due to a dependency-phase failure.
  final String? stoppedAtPhase;
  final bool serverUnavailable;
  final SyncFailureDetails? failureDetails;
  final bool performedServerCheck;

  bool get hasFailures => failed > 0;
}

class SyncService {
  static const Duration _baseRetryDelay = Duration(seconds: 5);

  SyncService({
    required this._syncQueueRepository,
    required LocalCompanyRepository localCompanyRepository,
    required this._localBankAccountRepository,
    required this._localChequeRepository,
    required this._identityResolver,
    required this._remoteCompanyRepository,
    required this._remoteBankAccountsRepository,
    required this._remoteChequeRepository,
    required this._chequeSyncIdentityResolver,
  }) : _localCompanyRepository = localCompanyRepository;

  final SyncQueueRepository _syncQueueRepository;
  final LocalCompanyRepository _localCompanyRepository;
  final LocalBankAccountRepository _localBankAccountRepository;
  final LocalChequeRepository _localChequeRepository;
  final SyncIdentityResolver _identityResolver;
  final RemoteCompanyRepository _remoteCompanyRepository;
  final RemoteBankAccountsRepository _remoteBankAccountsRepository;
  final RemoteChequeRepository _remoteChequeRepository;
  final ChequeSyncIdentityResolver _chequeSyncIdentityResolver;
  final SyncLogger _logger = SyncLogger.instance;
  bool _isSyncing = false;

  /// Requeues [queueId] to PENDING then runs the dependency-aware sync.
  /// Returns true when that specific item ends in SYNCED or is removed (successful DELETE).
  Future<bool> retrySingleQueueItem(int queueId) async {
    final item = await _syncQueueRepository.findById(queueId);
    if (item == null) {
      return false;
    }

    await _syncQueueRepository.retryQueueItem(queueId);
    await sync();

    final updated = await _syncQueueRepository.findById(queueId);
    return updated == null || updated.status == SyncStatus.synced;
  }

  Future<SyncServiceResult> sync() async {
    if (_isSyncing) {
      _logger.debug('SyncService.sync() skipped: already running.');
      return const SyncServiceResult(
        totalPending: 0,
        processed: 0,
        succeeded: 0,
        failed: 0,
        wasAlreadyRunning: true,
        performedServerCheck: false,
      );
    }

    _isSyncing = true;
    try {
      // Recover stale PROCESSING items from a prior interrupted run.
      await _syncQueueRepository.resetProcessingToPending();
      return await _runPhasedSync();
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncServiceResult> _runPhasedSync() async {
    _logger.info('SYNC START');

    final pendingCount = await _syncQueueRepository.countByStatus(
      SyncStatus.pending,
    );
    final failedCount = await _syncQueueRepository.countByStatus(
      SyncStatus.failed,
    );

    _logger.debug('queue snapshot: pending=$pendingCount failed=$failedCount');

    final processable = await _syncQueueRepository.getProcessable();
    final candidates = processable.where(_isReadyForAttempt).toList();

    if (candidates.isEmpty) {
      _logger.debug('SyncService: no processable queue items ready.');
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: 0,
        succeeded: 0,
        failed: 0,
        performedServerCheck: false,
      );
    }

    // Split into dependency phases; ordering within each phase is preserved
    // from the query (createdAt ASC, id ASC).
    final companyItems = candidates
        .where(
          (i) => i.entityType.trim().toUpperCase() == syncEntityTypeCompany,
        )
        .toList(growable: false);
    final bankAccountItems = candidates
        .where(
          (i) => i.entityType.trim().toUpperCase() == syncEntityTypeBankAccount,
        )
        .toList(growable: false);
    final chequeItems = candidates
        .where((i) => i.entityType.trim().toUpperCase() == syncEntityTypeCheque)
        .toList(growable: false);

    var totalProcessed = 0;
    var totalSucceeded = 0;
    var totalFailed = 0;

    // --- Phase 1: COMPANY ---
    _logger.info('COMPANY phase start: ready=${companyItems.length}');
    late final ({int processed, int succeeded, int failed}) companyPhase;
    try {
      companyPhase = await _processPhase(companyItems);
    } on SyncConnectivityFailureException catch (error) {
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed + error.processed,
        succeeded: totalSucceeded + error.succeeded,
        failed: totalFailed + error.failed,
        stoppedAtPhase: syncEntityTypeCompany,
        serverUnavailable: true,
        failureDetails: error.details,
        performedServerCheck: true,
      );
    }
    totalProcessed += companyPhase.processed;
    totalSucceeded += companyPhase.succeeded;
    totalFailed += companyPhase.failed;
    _logger.info(
      'COMPANY phase done: succeeded=${companyPhase.succeeded}'
      ' failed=${companyPhase.failed}',
    );

    if (companyPhase.failed > 0) {
      _logger.warning(
        'SYNC STOPPED after COMPANY phase (${companyPhase.failed} failure(s)).'
        ' BANK_ACCOUNT (${bankAccountItems.length})'
        ' and CHEQUE (${chequeItems.length}) skipped.',
      );
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed,
        succeeded: totalSucceeded,
        failed: totalFailed,
        stoppedAtPhase: syncEntityTypeCompany,
        performedServerCheck: true,
      );
    }

    // --- Phase 2: BANK_ACCOUNT ---
    _logger.info('BANK_ACCOUNT phase start: ready=${bankAccountItems.length}');
    late final ({int processed, int succeeded, int failed}) bankPhase;
    try {
      bankPhase = await _processPhase(bankAccountItems);
    } on SyncConnectivityFailureException catch (error) {
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed + error.processed,
        succeeded: totalSucceeded + error.succeeded,
        failed: totalFailed + error.failed,
        stoppedAtPhase: syncEntityTypeBankAccount,
        serverUnavailable: true,
        failureDetails: error.details,
        performedServerCheck: true,
      );
    }
    totalProcessed += bankPhase.processed;
    totalSucceeded += bankPhase.succeeded;
    totalFailed += bankPhase.failed;
    _logger.info(
      'BANK_ACCOUNT phase done: succeeded=${bankPhase.succeeded}'
      ' failed=${bankPhase.failed}',
    );

    if (bankPhase.failed > 0) {
      _logger.warning(
        'SYNC STOPPED after BANK_ACCOUNT phase (${bankPhase.failed} failure(s)).'
        ' CHEQUE (${chequeItems.length}) skipped.',
      );
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed,
        succeeded: totalSucceeded,
        failed: totalFailed,
        stoppedAtPhase: syncEntityTypeBankAccount,
        performedServerCheck: true,
      );
    }

    // --- Phase 3: CHEQUE ---
    _logger.info('CHEQUE phase start: ready=${chequeItems.length}');
    late final ({int processed, int succeeded, int failed}) chequePhase;
    try {
      chequePhase = await _processPhase(chequeItems);
    } on SyncConnectivityFailureException catch (error) {
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed + error.processed,
        succeeded: totalSucceeded + error.succeeded,
        failed: totalFailed + error.failed,
        stoppedAtPhase: syncEntityTypeCheque,
        serverUnavailable: true,
        failureDetails: error.details,
        performedServerCheck: true,
      );
    }
    totalProcessed += chequePhase.processed;
    totalSucceeded += chequePhase.succeeded;
    totalFailed += chequePhase.failed;
    _logger.info(
      'CHEQUE phase done: succeeded=${chequePhase.succeeded}'
      ' failed=${chequePhase.failed}',
    );

    _logger.info(
      'SYNC COMPLETE: processed=$totalProcessed'
      ' succeeded=$totalSucceeded failed=$totalFailed',
    );

    return SyncServiceResult(
      totalPending: pendingCount + failedCount,
      processed: totalProcessed,
      succeeded: totalSucceeded,
      failed: totalFailed,
      performedServerCheck: true,
    );
  }

  Future<({int processed, int succeeded, int failed})> _processPhase(
    List<SyncQueueItem> items,
  ) async {
    var processed = 0;
    var succeeded = 0;
    var failed = 0;

    for (final item in items) {
      final queueId = item.id;

      if (queueId == null) {
        _logger.warning(
          'Skipping queue item with null id:'
          ' entityType=${item.entityType}, entityId=${item.entityId}',
        );
        continue;
      }

      processed++;

      try {
        await _syncQueueRepository.markProcessing(queueId);
        final handled = await _syncQueueItem(item, queueId);
        if (handled) {
          succeeded++;
        } else {
          failed++;
        }
      } catch (error, stackTrace) {
        final details = _classifyFailure(error);
        failed++;

        await _syncQueueRepository.markFailed(
          queueId,
          errorMessage: details.userSafeMessage,
        );

        _logger.error(
          'Queue item $queueId failed during ${item.operation.dbValue}.',
          error: error,
          stackTrace: stackTrace,
        );

        if (details.type == SyncFailureType.serverConnectivity) {
          throw SyncConnectivityFailureException(
            details: details,
            processed: processed,
            succeeded: succeeded,
            failed: failed,
          );
        }
      }
    }

    return (processed: processed, succeeded: succeeded, failed: failed);
  }

  Future<Cheque?> _requireCheque(SyncQueueItem item, int queueId) async {
    final cheque = await _localChequeRepository.findById(item.entityId);
    if (cheque != null) {
      return cheque;
    }

    _logger.warning(
      'Queue item $queueId marked FAILED: cheque ${item.entityId} not found locally.',
    );
    await _syncQueueRepository.markFailed(
      queueId,
      errorMessage: 'Cheque ${item.entityId} not found locally.',
    );
    return null;
  }

  Future<bool> _syncQueueItem(SyncQueueItem item, int queueId) async {
    final entityType = item.entityType.trim().toUpperCase();

    switch (entityType) {
      case syncEntityTypeCheque:
        return _syncChequeItem(item, queueId);
      case syncEntityTypeCompany:
        return _syncCompanyItem(item, queueId);
      case syncEntityTypeBankAccount:
        return _syncBankAccountItem(item, queueId);
      default:
        await _syncQueueRepository.markFailed(
          queueId,
          errorMessage: 'Unsupported sync entity type: ${item.entityType}',
        );
        return false;
    }
  }

  Future<bool> _syncChequeItem(SyncQueueItem item, int queueId) async {
    final cheque = await _requireCheque(item, queueId);
    if (cheque == null) {
      return false;
    }

    switch (item.operation) {
      case SyncOperation.create:
        await _syncCreate(item, cheque);
        return true;
      case SyncOperation.update:
        await _syncUpdate(item, cheque);
        return true;
      case SyncOperation.delete:
        await _syncDelete(item, cheque);
        return true;
    }
  }

  Future<bool> _syncCompanyItem(SyncQueueItem item, int queueId) async {
    if (item.operation != SyncOperation.update) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage:
            'Unsupported operation ${item.operation.dbValue} for COMPANY.',
      );
      return false;
    }

    final company = await _requireCompany(item, queueId);
    if (company == null) {
      return false;
    }

    final serverUuid = await _identityResolver.resolveCompanyUuid(company.id!);
    await _remoteCompanyRepository.updateByServerUuid(
      serverUuid,
      _toApiCompanyPayload(company),
    );
    await _syncQueueRepository.markSynced(item.id!);
    return true;
  }

  Future<bool> _syncBankAccountItem(SyncQueueItem item, int queueId) async {
    if (item.operation != SyncOperation.update) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage:
            'Unsupported operation ${item.operation.dbValue} for BANK_ACCOUNT.',
      );
      return false;
    }

    final bankAccount = await _requireBankAccount(item, queueId);
    if (bankAccount == null) {
      return false;
    }

    final serverUuid = await _identityResolver.resolveBankAccountUuid(
      bankAccount.id!,
    );
    await _remoteBankAccountsRepository.updateByServerUuid(
      serverUuid,
      _toApiBankAccountPayload(bankAccount),
    );
    await _syncQueueRepository.markSynced(item.id!);
    return true;
  }

  Future<Company?> _requireCompany(SyncQueueItem item, int queueId) async {
    final company = await _localCompanyRepository.findById(item.entityId);
    if (company != null && company.id != null) {
      return company;
    }

    _logger.warning(
      'Queue item $queueId marked FAILED: company ${item.entityId} not found locally.',
    );
    await _syncQueueRepository.markFailed(
      queueId,
      errorMessage: 'Company ${item.entityId} not found locally.',
    );
    return null;
  }

  Future<BankAccount?> _requireBankAccount(
    SyncQueueItem item,
    int queueId,
  ) async {
    final account = await _localBankAccountRepository.findById(item.entityId);
    if (account != null && account.id != null) {
      return account;
    }

    _logger.warning(
      'Queue item $queueId marked FAILED: bank account ${item.entityId} not found locally.',
    );
    await _syncQueueRepository.markFailed(
      queueId,
      errorMessage: 'Bank account ${item.entityId} not found locally.',
    );
    return null;
  }

  Future<void> _syncCreate(SyncQueueItem item, Cheque cheque) async {
    final payload = await _toApiChequePayload(cheque);
    final serverUuid = await _remoteChequeRepository.create(payload);

    final trimmedUuid = serverUuid?.trim();
    if (trimmedUuid == null || trimmedUuid.isEmpty) {
      // Backend did not return a UUID: the cheque exists remotely but we have
      // no identity. Fail the queue item so the operator can investigate.
      throw SyncIdentityMappingException(
        'Cheque CREATE: backend returned no server UUID for local id ${cheque.id}.'
        ' Queue item NOT marked synced.',
      );
    }

    await _localChequeRepository.updateServerUuid(
      id: cheque.id,
      serverUuid: trimmedUuid,
    );
    await _syncQueueRepository.markSynced(item.id!);
  }

  Future<void> _syncUpdate(SyncQueueItem item, Cheque cheque) async {
    final serverUuid = await _chequeSyncIdentityResolver.resolveServerUuid(
      cheque,
    );
    final payload = await _toApiChequePayload(cheque);
    await _remoteChequeRepository.update(serverUuid, payload);
    await _syncQueueRepository.markSynced(item.id!);
  }

  Future<void> _syncDelete(SyncQueueItem item, Cheque cheque) async {
    final serverUuid = await _resolveServerUuidForDelete(cheque);

    try {
      await _remoteChequeRepository.delete(serverUuid);
    } on ApiHttpException catch (error) {
      if (!_isIdempotentDeleteSuccess(error)) {
        rethrow;
      }
    }

    // For soft-deleted records, successful delete removes the queue task only.
    await _syncQueueRepository.deleteQueueItem(item.id!);
  }

  Future<String> _resolveServerUuidForDelete(Cheque cheque) async {
    final existing = cheque.serverUuid?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bankAccountUuid = await _identityResolver.resolveBankAccountUuid(
      cheque.bankAccountId,
    );
    final normalizedChequeNumber = cheque.chequeNumber.trim();

    final remoteCheques = await _remoteChequeRepository.getAll();
    final candidates = remoteCheques
        .where((remoteCheque) {
          return remoteCheque.bankAccountId.trim() == bankAccountUuid &&
              remoteCheque.chequeNumber.trim() == normalizedChequeNumber;
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw SyncIdentityMappingException(
        'Cheque local id ${cheque.id} has no unique remote UUID match for DELETE.',
      );
    }

    if (candidates.length > 1) {
      throw SyncIdentityMappingException(
        'Cheque local id ${cheque.id} resolved to multiple remote UUID candidates for DELETE.',
      );
    }

    final resolved = candidates.first.id.trim();
    await _localChequeRepository.updateServerUuid(
      id: cheque.id,
      serverUuid: resolved,
    );
    return resolved;
  }

  Future<Map<String, dynamic>> _toApiChequePayload(Cheque cheque) async {
    final json = cheque.toJson();
    final companyUuid = await _identityResolver.resolveCompanyUuid(
      cheque.companyId,
    );
    final bankAccountUuid = await _identityResolver.resolveBankAccountUuid(
      cheque.bankAccountId,
    );

    return {
      'chequeNumber': cheque.chequeNumber,
      'amount': cheque.amountRial,
      'chequeDate': cheque.issueDate.toIso8601String(),
      'dueDate': cheque.dueDate.toIso8601String(),
      'companyId': companyUuid,
      'bankAccountId': bankAccountUuid,
      'status': _apiStatus(cheque.status),
      'isRegisteredInSayad': cheque.isRegisteredInSayad,
      'sayadId': cheque.sayadId,
      'description': cheque.description,
      'imageData': json['imageData'],
    };
  }

  Map<String, dynamic> _toApiCompanyPayload(Company company) {
    return {
      'name': company.name,
      'nationalId': company.nationalId,
      'economicCode': company.economicCode,
      'notes': company.notes,
      'visitorName': company.visitorName,
      'visitorPhone': company.visitorPhone,
      'accountantName': company.accountantName,
      'accountantPhone': company.accountantPhone,
      'archivedAt': company.archivedAt?.toIso8601String(),
      'updatedAt': company.updatedAt.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _toApiBankAccountPayload(BankAccount account) {
    return {
      'bankName': account.bankName,
      'accountTitle': account.accountTitle,
      'accountHolder': account.accountHolder,
      'accountNumber': account.accountNumber,
      'cardNumber': account.cardNumber,
      'iban': account.iban,
      'note': account.note,
      'archivedAt': account.archivedAt?.toIso8601String(),
      'updatedAt': account.updatedAt.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  String _apiStatus(ChequeStatus status) {
    switch (status) {
      case ChequeStatus.issued:
        return 'Issued';
      case ChequeStatus.registered:
        return 'Registered';
      case ChequeStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool _isIdempotentDeleteSuccess(ApiHttpException error) {
    return error.statusCode == 404 || error.statusCode == 410;
  }

  bool _isReadyForAttempt(SyncQueueItem item) {
    if (item.status == SyncStatus.pending) {
      return true;
    }

    if (item.status != SyncStatus.failed) {
      return false;
    }

    final lastAttemptAt = item.lastAttemptAt;
    if (lastAttemptAt == null) {
      return true;
    }

    final exponent = item.retryCount <= 0 ? 0 : item.retryCount - 1;
    final multiplier = 1 << exponent.clamp(0, 10);
    final backoff = _baseRetryDelay * multiplier;
    final nextAttemptAt = lastAttemptAt.add(backoff);
    final isReady = !nextAttemptAt.isAfter(DateTime.now());

    if (!isReady) {
      _logger.debug(
        'Skipping queue item ${item.id} until backoff expires at ${nextAttemptAt.toIso8601String()}.',
      );
    }

    return isReady;
  }

  SyncFailureDetails classifyFailure(Object error) {
    return _classifyFailure(error);
  }

  SyncFailureDetails _classifyFailure(Object error) {
    if (error is SyncIdentityMappingException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'خطای داده محلی در همگام سازی.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ApiNetworkException || error is ApiTimeoutException) {
      return SyncFailureDetails(
        type: SyncFailureType.serverConnectivity,
        userSafeMessage: 'عدم دسترسی به سرور',
        technicalMessage: error.toString(),
      );
    }

    if (error is ApiHttpException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'خطای پاسخ سرور (${error.statusCode})',
        technicalMessage: error.toString(),
      );
    }

    if (error is ApiDecodingException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ سرور نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ApiUnknownException || error is ApiException) {
      return SyncFailureDetails(
        type: SyncFailureType.unknown,
        userSafeMessage: 'همگام سازی با خطای پیش بینی نشده مواجه شد.',
        technicalMessage: error.toString(),
      );
    }

    return SyncFailureDetails(
      type: SyncFailureType.unknown,
      userSafeMessage: 'همگام سازی با خطای پیش بینی نشده مواجه شد.',
      technicalMessage: error.toString(),
    );
  }
}
