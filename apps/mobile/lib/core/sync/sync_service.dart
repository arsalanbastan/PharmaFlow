import '../network/api_client.dart';
import '../../data/mappers/cash_payment_mapper.dart';
import '../../data/models/bank_account.dart';
import '../../data/models/cash_payment.dart';
import '../../data/models/cheque.dart';
import '../../data/models/company.dart';
import '../../data/repositories/local/local_bank_account_repository.dart';
import '../../data/repositories/local/local_cash_payment_repository.dart';
import '../../data/repositories/local/sync_queue_repository.dart';
import '../../data/repositories/local/local_cheque_repository.dart';
import '../../data/repositories/local/local_company_repository.dart';
import '../../data/repositories/remote/remote_bank_accounts_repository.dart';
import '../../data/repositories/remote/remote_cash_payment_repository.dart';
import '../../data/repositories/remote/remote_cheque_repository.dart';
import '../../data/repositories/remote/remote_company_repository.dart';
import 'bank_account_pull_merge_service.dart';
import 'cash_payment_attachment_pull_merge_service.dart';
import 'cash_payment_attachment_push_service.dart';
import 'cash_payment_pull_merge_service.dart';
import 'cheque_pull_merge_service.dart';
import 'cheque_attachment_pull_merge_service.dart';
import 'cheque_attachment_push_service.dart';
import 'cheque_sync_identity_resolver.dart';
import 'company_pull_merge_service.dart';
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

  // Public callback parameter intentionally maps to a private field.
  // ignore: prefer_initializing_formals
  SyncService({
    required this._syncQueueRepository,
    required this._localCompanyRepository,
    required this._localBankAccountRepository,
    required this._localChequeRepository,
    required this._identityResolver,
    required this._remoteCompanyRepository,
    required this._remoteBankAccountsRepository,
    required this._remoteChequeRepository,
    required this._chequeSyncIdentityResolver,
    this._companyPullMergeService,
    this._bankAccountPullMergeService,
    this._chequePullMergeService,
    ChequeAttachmentPushService? chequeAttachmentPushService,
    ChequeAttachmentPullMergeService? chequeAttachmentPullMergeService,
    this.onCompanyPullMerged,
    this.onBankAccountPullMerged,
    this.onChequePullMerged,
    this._localCashPaymentRepository,
    this._remoteCashPaymentRepository,
    this._cashPaymentPullMergeService,
    this.onCashPaymentPullMerged,
    CashPaymentAttachmentPushService? cashPaymentAttachmentPushService,
    CashPaymentAttachmentPullMergeService?
    cashPaymentAttachmentPullMergeService,
  }) : _chequeAttachmentPushService = chequeAttachmentPushService,
       _chequeAttachmentPullMergeService = chequeAttachmentPullMergeService,
       _cashPaymentAttachmentPushService = cashPaymentAttachmentPushService,
       _cashPaymentAttachmentPullMergeService =
           cashPaymentAttachmentPullMergeService;

  final SyncQueueRepository _syncQueueRepository;
  final LocalCompanyRepository _localCompanyRepository;
  final LocalBankAccountRepository _localBankAccountRepository;
  final LocalChequeRepository _localChequeRepository;
  final LocalCashPaymentRepository? _localCashPaymentRepository;
  final SyncIdentityResolver _identityResolver;
  final RemoteCompanyRepository _remoteCompanyRepository;
  final RemoteBankAccountsRepository _remoteBankAccountsRepository;
  final RemoteChequeRepository _remoteChequeRepository;
  final RemoteCashPaymentRepository? _remoteCashPaymentRepository;
  final ChequeSyncIdentityResolver _chequeSyncIdentityResolver;
  final CompanyPullMergeService? _companyPullMergeService;
  final BankAccountPullMergeService? _bankAccountPullMergeService;
  final ChequePullMergeService? _chequePullMergeService;
  final ChequeAttachmentPushService? _chequeAttachmentPushService;
  final ChequeAttachmentPullMergeService? _chequeAttachmentPullMergeService;
  final CashPaymentPullMergeService? _cashPaymentPullMergeService;
  final CashPaymentAttachmentPushService? _cashPaymentAttachmentPushService;
  final CashPaymentAttachmentPullMergeService?
  _cashPaymentAttachmentPullMergeService;
  final Future<void> Function(CompanyPullMergeResult result)?
  onCompanyPullMerged;
  final Future<void> Function(BankAccountPullMergeResult result)?
  onBankAccountPullMerged;
  final Future<void> Function(ChequePullMergeResult result)? onChequePullMerged;
  final Future<void> Function(CashPaymentPullMergeResult result)?
  onCashPaymentPullMerged;
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
      _logger.debug(
        'SyncService: no processable queue items ready; '
        'continuing with incremental pull.',
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

    final chequeAttachmentItems = candidates
        .where(
          (i) =>
              i.entityType.trim().toUpperCase() ==
              syncEntityTypeChequeAttachment,
        )
        .toList(growable: false);

    final cashPaymentItems = candidates
        .where(
          (i) => i.entityType.trim().toUpperCase() == syncEntityTypeCashPayment,
        )
        .toList(growable: false);

    final cashPaymentAttachmentItems = candidates
        .where(
          (i) =>
              i.entityType.trim().toUpperCase() ==
              syncEntityTypeCashPaymentAttachment,
        )
        .toList(growable: false);

    var totalProcessed = 0;
    var totalSucceeded = 0;
    var totalFailed = 0;
    var performedServerCheck = candidates.isNotEmpty;

    // --- Phase 1A: COMPANY PUSH ---
    _logger.info('COMPANY push start: ready=${companyItems.length}');
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
      'COMPANY push done: succeeded=${companyPhase.succeeded}'
      ' failed=${companyPhase.failed}',
    );

    if (companyPhase.failed > 0) {
      _logger.warning(
        'SYNC STOPPED after COMPANY push '
        '(${companyPhase.failed} failure(s)).'
        ' COMPANY pull, BANK_ACCOUNT (${bankAccountItems.length})'
        ' and CHEQUE (${chequeItems.length}) skipped.',
      );
      return SyncServiceResult(
        totalPending: pendingCount + failedCount,
        processed: totalProcessed,
        succeeded: totalSucceeded,
        failed: totalFailed,
        stoppedAtPhase: syncEntityTypeCompany,
        performedServerCheck: performedServerCheck,
      );
    }

    // --- Phase 1B: COMPANY PULL + MERGE ---
    final companyPullMergeService = _companyPullMergeService;
    if (companyPullMergeService != null) {
      performedServerCheck = true;
      _logger.info('COMPANY pull/merge start');

      try {
        final pullResult = await companyPullMergeService.pullAndMerge();

        _logger.info(
          'COMPANY pull/merge done: '
          'pages=${pullResult.pagesFetched} '
          'received=${pullResult.changesReceived} '
          'unique=${pullResult.uniqueChanges} '
          'inserted=${pullResult.inserted} '
          'updated=${pullResult.updated} '
          'tombstonesApplied=${pullResult.tombstonesApplied} '
          'tombstonesIgnored=${pullResult.tombstonesIgnored}',
        );

        final refreshCallback = onCompanyPullMerged;
        if (refreshCallback != null && pullResult.changedLocalData) {
          _logger.info('COMPANY refresh start');
          await refreshCallback(pullResult);
          _logger.info('COMPANY refresh done');
        }
      } catch (error, stackTrace) {
        final details = _classifyFailure(error);
        totalFailed += 1;

        _logger.error(
          'COMPANY pull/merge failed.',
          error: error,
          stackTrace: stackTrace,
        );

        _logger.warning(
          'SYNC STOPPED after COMPANY pull/merge failure.'
          ' BANK_ACCOUNT (${bankAccountItems.length})'
          ' and CHEQUE (${chequeItems.length}) skipped.',
        );

        return SyncServiceResult(
          totalPending: pendingCount + failedCount,
          processed: totalProcessed,
          succeeded: totalSucceeded,
          failed: totalFailed,
          stoppedAtPhase: syncEntityTypeCompany,
          serverUnavailable: details.type == SyncFailureType.serverConnectivity,
          failureDetails: details,
          performedServerCheck: true,
        );
      }
    } else {
      _logger.debug(
        'COMPANY pull/merge skipped because no pull service is configured.',
      );
    }

    // --- Phase 2A: BANK_ACCOUNT PUSH ---
    _logger.info('BANK_ACCOUNT push start: ready=${bankAccountItems.length}');
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
      'BANK_ACCOUNT push done: succeeded=${bankPhase.succeeded}'
      ' failed=${bankPhase.failed}',
    );

    if (bankPhase.failed > 0) {
      _logger.warning(
        'SYNC STOPPED after BANK_ACCOUNT push '
        '(${bankPhase.failed} failure(s)).'
        ' BANK_ACCOUNT pull and CHEQUE (${chequeItems.length}) skipped.',
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

    // --- Phase 2B: BANK_ACCOUNT PULL + MERGE ---
    final bankAccountPullMergeService = _bankAccountPullMergeService;
    if (bankAccountPullMergeService != null) {
      performedServerCheck = true;
      _logger.info('BANK_ACCOUNT pull/merge start');

      try {
        final pullResult = await bankAccountPullMergeService.pullAndMerge();

        _logger.info(
          'BANK_ACCOUNT pull/merge done: '
          'pages=${pullResult.pagesFetched} '
          'received=${pullResult.changesReceived} '
          'unique=${pullResult.uniqueChanges} '
          'inserted=${pullResult.inserted} '
          'updated=${pullResult.updated} '
          'tombstonesApplied=${pullResult.tombstonesApplied} '
          'tombstonesIgnored=${pullResult.tombstonesIgnored}',
        );

        final refreshCallback = onBankAccountPullMerged;
        if (refreshCallback != null && pullResult.changedLocalData) {
          _logger.info('BANK_ACCOUNT refresh start');
          await refreshCallback(pullResult);
          _logger.info('BANK_ACCOUNT refresh done');
        }
      } catch (error, stackTrace) {
        final details = _classifyFailure(error);
        totalFailed += 1;

        _logger.error(
          'BANK_ACCOUNT pull/merge failed.',
          error: error,
          stackTrace: stackTrace,
        );

        _logger.warning(
          'SYNC STOPPED after BANK_ACCOUNT pull/merge failure.'
          ' CHEQUE (${chequeItems.length}) skipped.',
        );

        return SyncServiceResult(
          totalPending: pendingCount + failedCount,
          processed: totalProcessed,
          succeeded: totalSucceeded,
          failed: totalFailed,
          stoppedAtPhase: syncEntityTypeBankAccount,
          serverUnavailable: details.type == SyncFailureType.serverConnectivity,
          failureDetails: details,
          performedServerCheck: true,
        );
      }
    } else {
      _logger.debug(
        'BANK_ACCOUNT pull/merge skipped because no pull service is configured.',
      );
    }

    // --- Phase 3A: CHEQUE PUSH ---
    _logger.info('CHEQUE push start: ready=${chequeItems.length}');
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
      'CHEQUE push done: succeeded=${chequePhase.succeeded}'
      ' failed=${chequePhase.failed}',
    );

    if (chequePhase.failed > 0) {
      _logger.warning(
        'CHEQUE pull/merge and CASH_PAYMENT '
        '(${cashPaymentItems.length}) skipped because CHEQUE push had '
        '${chequePhase.failed} failure(s).',
      );
    } else {
      // --- Phase 3B: CHEQUE PULL + MERGE ---
      final chequePullMergeService = _chequePullMergeService;

      if (chequePullMergeService != null) {
        performedServerCheck = true;
        _logger.info('CHEQUE pull/merge start');

        try {
          final pullResult = await chequePullMergeService.pullAndMerge();

          _logger.info(
            'CHEQUE pull/merge done: '
            'pages=${pullResult.pagesFetched} '
            'received=${pullResult.changesReceived} '
            'unique=${pullResult.uniqueChanges} '
            'inserted=${pullResult.inserted} '
            'updated=${pullResult.updated} '
            'tombstonesApplied=${pullResult.tombstonesApplied} '
            'tombstonesIgnored=${pullResult.tombstonesIgnored}',
          );

          final refreshCallback = onChequePullMerged;

          if (refreshCallback != null && pullResult.changedLocalData) {
            _logger.info('CHEQUE refresh start');
            await refreshCallback(pullResult);
            _logger.info('CHEQUE refresh done');
          }
        } catch (error, stackTrace) {
          final details = _classifyFailure(error);
          totalFailed += 1;

          _logger.error(
            'CHEQUE pull/merge failed.',
            error: error,
            stackTrace: stackTrace,
          );

          _logger.warning(
            'CASH_PAYMENT (${cashPaymentItems.length}) skipped because '
            'CHEQUE pull/merge failed.',
          );

          return SyncServiceResult(
            totalPending: pendingCount + failedCount,
            processed: totalProcessed,
            succeeded: totalSucceeded,
            failed: totalFailed,
            stoppedAtPhase: syncEntityTypeCheque,
            serverUnavailable:
                details.type == SyncFailureType.serverConnectivity,
            failureDetails: details,
            performedServerCheck: true,
          );
        }
      } else {
        _logger.debug(
          'CHEQUE pull/merge skipped because no pull service is configured.',
        );
      }
    }

    if (chequePhase.failed == 0) {
      // --- Phase 3C: CHEQUE_ATTACHMENT PUSH ---
      _logger.info(
        'CHEQUE_ATTACHMENT push start: '
        'ready=${chequeAttachmentItems.length}',
      );

      late final ({int processed, int succeeded, int failed})
      chequeAttachmentPhase;

      try {
        chequeAttachmentPhase = await _processPhase(chequeAttachmentItems);
      } on SyncConnectivityFailureException catch (error) {
        return SyncServiceResult(
          totalPending: pendingCount + failedCount,
          processed: totalProcessed + error.processed,
          succeeded: totalSucceeded + error.succeeded,
          failed: totalFailed + error.failed,
          stoppedAtPhase: syncEntityTypeChequeAttachment,
          serverUnavailable: true,
          failureDetails: error.details,
          performedServerCheck: true,
        );
      }

      totalProcessed += chequeAttachmentPhase.processed;
      totalSucceeded += chequeAttachmentPhase.succeeded;
      totalFailed += chequeAttachmentPhase.failed;

      _logger.info(
        'CHEQUE_ATTACHMENT push done: '
        'succeeded=${chequeAttachmentPhase.succeeded} '
        'failed=${chequeAttachmentPhase.failed}',
      );

      if (chequeAttachmentPhase.failed > 0) {
        _logger.warning(
          'CHEQUE_ATTACHMENT pull/merge skipped because attachment push had '
          '${chequeAttachmentPhase.failed} failure(s).',
        );
      } else {
        final attachmentPullMergeService = _chequeAttachmentPullMergeService;

        if (attachmentPullMergeService != null) {
          performedServerCheck = true;
          _logger.info('CHEQUE_ATTACHMENT pull/merge start');

          try {
            final pullResult = await attachmentPullMergeService.pullAndMerge();

            _logger.info(
              'CHEQUE_ATTACHMENT pull/merge done: '
              'pages=${pullResult.pagesFetched} '
              'received=${pullResult.changesReceived} '
              'unique=${pullResult.uniqueChanges} '
              'inserted=${pullResult.inserted} '
              'updated=${pullResult.updated} '
              'tombstonesApplied=${pullResult.tombstonesApplied} '
              'tombstonesIgnored=${pullResult.tombstonesIgnored}',
            );
          } catch (error, stackTrace) {
            final details = _classifyFailure(error);
            totalFailed += 1;

            _logger.error(
              'CHEQUE_ATTACHMENT pull/merge failed.',
              error: error,
              stackTrace: stackTrace,
            );

            return SyncServiceResult(
              totalPending: pendingCount + failedCount,
              processed: totalProcessed,
              succeeded: totalSucceeded,
              failed: totalFailed,
              stoppedAtPhase: syncEntityTypeChequeAttachment,
              serverUnavailable:
                  details.type == SyncFailureType.serverConnectivity,
              failureDetails: details,
              performedServerCheck: true,
            );
          }
        }
      }

      // --- Phase 4A: CASH_PAYMENT PUSH ---
      _logger.info('CASH_PAYMENT push start: ready=${cashPaymentItems.length}');

      late final ({int processed, int succeeded, int failed}) cashPaymentPhase;

      try {
        cashPaymentPhase = await _processPhase(cashPaymentItems);
      } on SyncConnectivityFailureException catch (error) {
        return SyncServiceResult(
          totalPending: pendingCount + failedCount,
          processed: totalProcessed + error.processed,
          succeeded: totalSucceeded + error.succeeded,
          failed: totalFailed + error.failed,
          stoppedAtPhase: syncEntityTypeCashPayment,
          serverUnavailable: true,
          failureDetails: error.details,
          performedServerCheck: true,
        );
      }

      totalProcessed += cashPaymentPhase.processed;
      totalSucceeded += cashPaymentPhase.succeeded;
      totalFailed += cashPaymentPhase.failed;

      _logger.info(
        'CASH_PAYMENT push done: '
        'succeeded=${cashPaymentPhase.succeeded} '
        'failed=${cashPaymentPhase.failed}',
      );

      if (cashPaymentPhase.failed > 0) {
        _logger.warning(
          'CASH_PAYMENT pull/merge skipped because CASH_PAYMENT push had '
          '${cashPaymentPhase.failed} failure(s).',
        );
      } else {
        // --- Phase 4B: CASH_PAYMENT PULL + MERGE ---
        final cashPaymentPullMergeService = _cashPaymentPullMergeService;

        if (cashPaymentPullMergeService != null) {
          performedServerCheck = true;
          _logger.info('CASH_PAYMENT pull/merge start');

          try {
            final pullResult = await cashPaymentPullMergeService.pullAndMerge();

            _logger.info(
              'CASH_PAYMENT pull/merge done: '
              'pages=${pullResult.pagesFetched} '
              'received=${pullResult.changesReceived} '
              'unique=${pullResult.uniqueChanges} '
              'inserted=${pullResult.inserted} '
              'updated=${pullResult.updated} '
              'tombstonesApplied=${pullResult.tombstonesApplied} '
              'tombstonesIgnored=${pullResult.tombstonesIgnored}',
            );

            final refreshCallback = onCashPaymentPullMerged;

            if (refreshCallback != null && pullResult.changedLocalData) {
              _logger.info('CASH_PAYMENT refresh start');
              await refreshCallback(pullResult);
              _logger.info('CASH_PAYMENT refresh done');
            }
          } catch (error, stackTrace) {
            final details = _classifyFailure(error);
            totalFailed += 1;

            _logger.error(
              'CASH_PAYMENT pull/merge failed.',
              error: error,
              stackTrace: stackTrace,
            );

            return SyncServiceResult(
              totalPending: pendingCount + failedCount,
              processed: totalProcessed,
              succeeded: totalSucceeded,
              failed: totalFailed,
              stoppedAtPhase: syncEntityTypeCashPayment,
              serverUnavailable:
                  details.type == SyncFailureType.serverConnectivity,
              failureDetails: details,
              performedServerCheck: true,
            );
          }
        } else {
          _logger.debug(
            'CASH_PAYMENT pull/merge skipped because no pull service '
            'is configured.',
          );
        }
      }

      if (cashPaymentPhase.failed == 0) {
        // --- Phase 5A: CASH_PAYMENT_ATTACHMENT PUSH ---
        _logger.info(
          'CASH_PAYMENT_ATTACHMENT push start: '
          'ready=${cashPaymentAttachmentItems.length}',
        );

        late final ({int processed, int succeeded, int failed})
        cashPaymentAttachmentPhase;

        try {
          cashPaymentAttachmentPhase = await _processPhase(
            cashPaymentAttachmentItems,
          );
        } on SyncConnectivityFailureException catch (error) {
          return SyncServiceResult(
            totalPending: pendingCount + failedCount,
            processed: totalProcessed + error.processed,
            succeeded: totalSucceeded + error.succeeded,
            failed: totalFailed + error.failed,
            stoppedAtPhase: syncEntityTypeCashPaymentAttachment,
            serverUnavailable: true,
            failureDetails: error.details,
            performedServerCheck: true,
          );
        }

        totalProcessed += cashPaymentAttachmentPhase.processed;
        totalSucceeded += cashPaymentAttachmentPhase.succeeded;
        totalFailed += cashPaymentAttachmentPhase.failed;

        _logger.info(
          'CASH_PAYMENT_ATTACHMENT push done: '
          'succeeded=${cashPaymentAttachmentPhase.succeeded} '
          'failed=${cashPaymentAttachmentPhase.failed}',
        );

        if (cashPaymentAttachmentPhase.failed > 0) {
          _logger.warning(
            'CASH_PAYMENT_ATTACHMENT pull/merge skipped because '
            'attachment push had '
            '${cashPaymentAttachmentPhase.failed} failure(s).',
          );
        } else {
          // --- Phase 5B: CASH_PAYMENT_ATTACHMENT PULL + MERGE ---
          final attachmentPullMergeService =
              _cashPaymentAttachmentPullMergeService;

          if (attachmentPullMergeService != null) {
            performedServerCheck = true;

            _logger.info('CASH_PAYMENT_ATTACHMENT pull/merge start');

            try {
              final pullResult = await attachmentPullMergeService
                  .pullAndMerge();

              _logger.info(
                'CASH_PAYMENT_ATTACHMENT pull/merge done: '
                'pages=${pullResult.pagesFetched} '
                'received=${pullResult.changesReceived} '
                'unique=${pullResult.uniqueChanges} '
                'inserted=${pullResult.inserted} '
                'updated=${pullResult.updated} '
                'tombstonesApplied=${pullResult.tombstonesApplied} '
                'tombstonesIgnored=${pullResult.tombstonesIgnored}',
              );
            } catch (error, stackTrace) {
              final details = _classifyFailure(error);

              totalFailed += 1;

              _logger.error(
                'CASH_PAYMENT_ATTACHMENT pull/merge failed.',
                error: error,
                stackTrace: stackTrace,
              );

              return SyncServiceResult(
                totalPending: pendingCount + failedCount,
                processed: totalProcessed,
                succeeded: totalSucceeded,
                failed: totalFailed,
                stoppedAtPhase: syncEntityTypeCashPaymentAttachment,
                serverUnavailable:
                    details.type == SyncFailureType.serverConnectivity,
                failureDetails: details,
                performedServerCheck: true,
              );
            }
          } else {
            _logger.debug(
              'CASH_PAYMENT_ATTACHMENT pull/merge skipped because '
              'no pull service is configured.',
            );
          }
        }
      }
    }

    _logger.info(
      'SYNC COMPLETE: processed=$totalProcessed'
      ' succeeded=$totalSucceeded failed=$totalFailed',
    );

    return SyncServiceResult(
      totalPending: pendingCount + failedCount,
      processed: totalProcessed,
      succeeded: totalSucceeded,
      failed: totalFailed,
      performedServerCheck: performedServerCheck,
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
      case syncEntityTypeChequeAttachment:
        return _syncChequeAttachmentItem(item, queueId);
      case syncEntityTypeCashPayment:
        return _syncCashPaymentItem(item, queueId);
      case syncEntityTypeCashPaymentAttachment:
        return _syncCashPaymentAttachmentItem(item, queueId);
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

  Future<bool> _syncCashPaymentItem(SyncQueueItem item, int queueId) async {
    final payment = await _requireCashPayment(item, queueId);

    if (payment == null) {
      return false;
    }

    final remoteRepository = _remoteCashPaymentRepository;

    if (remoteRepository == null) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage: 'Cash payment remote sync is not configured.',
      );

      return false;
    }

    switch (item.operation) {
      case SyncOperation.create:
        final requestedUuid = payment.serverUuid?.trim();

        if (requestedUuid == null || requestedUuid.isEmpty) {
          throw SyncIdentityMappingException(
            'CashPayment CREATE has no client UUID for local id '
            '${payment.id}.',
          );
        }

        final returnedUuid = await remoteRepository.create(
          await _toApiCashPaymentPayload(payment, serverUuid: requestedUuid),
        );

        if (!_sameUuid(requestedUuid, returnedUuid)) {
          throw SyncIdentityMappingException(
            'CashPayment CREATE identity mismatch for local id '
            '${payment.id}: requested=$requestedUuid '
            'returned=$returnedUuid. Queue item NOT marked synced.',
          );
        }

        await _syncQueueRepository.markSynced(item.id!);

        /*
         * requestDelete may happen while CREATE is already PROCESSING.
         * In that case LocalCashPaymentRepository intentionally leaves
         * CREATE intact. Once idempotent CREATE succeeds, convert the
         * local delete intent into a follow-up remote DELETE.
         */
        final latestPayment = await _localCashPaymentRepository?.findById(
          payment.id!,
        );

        if (latestPayment?.deleteRequestedAt != null) {
          await _syncQueueRepository.add(
            SyncQueueItem(
              entityType: syncEntityTypeCashPayment,
              entityId: payment.id!,
              operation: SyncOperation.delete,
              status: SyncStatus.pending,
              retryCount: 0,
              createdAt: DateTime.now(),
            ),
          );
        }

        return true;

      case SyncOperation.update:
        final serverUuid = _requireCashPaymentServerUuid(payment);

        await remoteRepository.update(
          serverUuid,
          await _toApiCashPaymentPayload(payment),
        );

        await _syncQueueRepository.markSynced(item.id!);

        return true;

      case SyncOperation.delete:
        final serverUuid = _requireCashPaymentServerUuid(payment);

        try {
          await remoteRepository.delete(serverUuid);
        } on ApiHttpException catch (error) {
          if (!_isIdempotentDeleteSuccess(error)) {
            rethrow;
          }
        }

        await _syncQueueRepository.deleteQueueItem(item.id!);

        return true;
    }
  }

  Future<bool> _syncCashPaymentAttachmentItem(
    SyncQueueItem item,
    int queueId,
  ) async {
    final pushService = _cashPaymentAttachmentPushService;

    if (pushService == null) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage: 'Cash payment attachment remote sync is not configured.',
      );

      return false;
    }

    return pushService.push(item);
  }

  Future<bool> _syncChequeAttachmentItem(
    SyncQueueItem item,
    int queueId,
  ) async {
    final pushService = _chequeAttachmentPushService;

    if (pushService == null) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage: 'Cheque attachment remote sync is not configured.',
      );

      return false;
    }

    return pushService.push(item);
  }

  Future<bool> _syncCompanyItem(SyncQueueItem item, int queueId) async {
    final company = await _requireCompany(item, queueId);
    if (company == null) {
      return false;
    }

    final serverUuid = await _identityResolver.resolveCompanyUuid(company.id!);

    switch (item.operation) {
      case SyncOperation.create:
        final returnedUuid = await _remoteCompanyRepository
            .createWithClientUuid(
              _toApiCompanyPayload(company, serverUuid: serverUuid),
            );

        if (!_sameUuid(serverUuid, returnedUuid)) {
          throw SyncIdentityMappingException(
            'Company CREATE identity mismatch for local id ${company.id}: '
            'requested=$serverUuid returned=$returnedUuid. '
            'Queue item NOT marked synced.',
          );
        }

        await _syncQueueRepository.markSynced(item.id!);
        return true;

      case SyncOperation.update:
        await _remoteCompanyRepository.updateByServerUuid(
          serverUuid,
          _toApiCompanyPayload(company),
        );
        await _syncQueueRepository.markSynced(item.id!);
        return true;

      case SyncOperation.delete:
        await _syncQueueRepository.markFailed(
          queueId,
          errorMessage: 'Unsupported operation DELETE for COMPANY.',
        );
        return false;
    }
  }

  Future<bool> _syncBankAccountItem(SyncQueueItem item, int queueId) async {
    final bankAccount = await _requireBankAccount(item, queueId);
    if (bankAccount == null) {
      return false;
    }

    final serverUuid = await _identityResolver.resolveBankAccountUuid(
      bankAccount.id!,
    );

    switch (item.operation) {
      case SyncOperation.create:
        final returnedUuid = await _remoteBankAccountsRepository
            .createWithClientUuid(
              _toApiBankAccountPayload(bankAccount, serverUuid: serverUuid),
            );

        if (!_sameUuid(serverUuid, returnedUuid)) {
          throw SyncIdentityMappingException(
            'BankAccount CREATE identity mismatch for local id '
            '${bankAccount.id}: requested=$serverUuid '
            'returned=$returnedUuid. Queue item NOT marked synced.',
          );
        }

        await _syncQueueRepository.markSynced(item.id!);
        return true;

      case SyncOperation.update:
        await _remoteBankAccountsRepository.updateByServerUuid(
          serverUuid,
          _toApiBankAccountPayload(bankAccount),
        );
        await _syncQueueRepository.markSynced(item.id!);
        return true;

      case SyncOperation.delete:
        await _syncQueueRepository.markFailed(
          queueId,
          errorMessage: 'Unsupported operation DELETE for BANK_ACCOUNT.',
        );
        return false;
    }
  }

  Future<CashPayment?> _requireCashPayment(
    SyncQueueItem item,
    int queueId,
  ) async {
    final localRepository = _localCashPaymentRepository;

    if (localRepository == null) {
      await _syncQueueRepository.markFailed(
        queueId,
        errorMessage: 'Cash payment local sync is not configured.',
      );

      return null;
    }

    final payment = await localRepository.findById(item.entityId);

    if (payment != null && payment.id != null) {
      return payment;
    }

    _logger.warning(
      'Queue item $queueId marked FAILED: '
      'cash payment ${item.entityId} not found locally.',
    );

    await _syncQueueRepository.markFailed(
      queueId,
      errorMessage: 'Cash payment ${item.entityId} not found locally.',
    );

    return null;
  }

  String _requireCashPaymentServerUuid(CashPayment payment) {
    final serverUuid = payment.serverUuid?.trim();

    if (serverUuid == null || serverUuid.isEmpty) {
      throw SyncIdentityMappingException(
        'CashPayment local id ${payment.id} has no server UUID.',
      );
    }

    return serverUuid;
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
    final requestedUuid = cheque.serverUuid?.trim();
    final hasClientUuid = requestedUuid != null && requestedUuid.isNotEmpty;

    final payload = await _toApiChequePayload(
      cheque,
      serverUuid: hasClientUuid ? requestedUuid : null,
    );
    final returnedUuid = await _remoteChequeRepository.create(payload);

    final trimmedReturnedUuid = returnedUuid?.trim();
    if (trimmedReturnedUuid == null || trimmedReturnedUuid.isEmpty) {
      throw SyncIdentityMappingException(
        'Cheque CREATE: backend returned no server UUID for local id ${cheque.id}.'
        ' Queue item NOT marked synced.',
      );
    }

    if (hasClientUuid) {
      if (!_sameUuid(requestedUuid, trimmedReturnedUuid)) {
        throw SyncIdentityMappingException(
          'Cheque CREATE identity mismatch for local id ${cheque.id}: '
          'requested=$requestedUuid returned=$trimmedReturnedUuid. '
          'Queue item NOT marked synced.',
        );
      }
    } else {
      /*
       * Backward compatibility for legacy rows created before client-generated
       * cheque UUIDs were introduced.
       */
      await _localChequeRepository.updateServerUuid(
        id: cheque.id,
        serverUuid: trimmedReturnedUuid,
      );
    }

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

  Future<Map<String, dynamic>> _toApiChequePayload(
    Cheque cheque, {
    String? serverUuid,
  }) async {
    final json = cheque.toJson();
    final companyUuid = await _identityResolver.resolveCompanyUuid(
      cheque.companyId,
    );
    final bankAccountUuid = await _identityResolver.resolveBankAccountUuid(
      cheque.bankAccountId,
    );

    final payload = <String, dynamic>{
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
      'archivedAt': cheque.archivedAt?.toUtc().toIso8601String(),
    };

    if (serverUuid != null) {
      payload['id'] = serverUuid;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _toApiCashPaymentPayload(
    CashPayment payment, {
    String? serverUuid,
  }) async {
    final companyUuid = await _identityResolver.resolveCompanyUuid(
      payment.companyId,
    );

    final bankAccountUuid = await _identityResolver.resolveBankAccountUuid(
      payment.bankAccountId,
    );

    final payload = <String, dynamic>{
      'amount': payment.amountRial,
      'paymentDate': payment.paymentDate.toUtc().toIso8601String(),
      'companyId': companyUuid,
      'bankAccountId': bankAccountUuid,
      'paymentMethod': CashPaymentMapper.paymentMethodToWireValue(
        payment.paymentMethod,
      ),
      'trackingNumber': payment.trackingNumber,
      'description': payment.description,
      'notes': payment.notes,
      'archivedAt': payment.archivedAt?.toUtc().toIso8601String(),
    };

    if (serverUuid != null) {
      payload['id'] = serverUuid;
    }

    return payload;
  }

  Map<String, dynamic> _toApiCompanyPayload(
    Company company, {
    String? serverUuid,
  }) {
    final payload = <String, dynamic>{
      'name': company.name,
      'nationalId': company.nationalId,
      'economicCode': company.economicCode,
      'bankName': company.bankName,
      'accountNumber': company.accountNumber,
      'cardNumber': company.cardNumber,
      'shebaNumber': company.shebaNumber,
      'notes': company.notes,
      'visitorName': company.visitorName,
      'visitorPhone': company.visitorPhone,
      'accountantName': company.accountantName,
      'accountantPhone': company.accountantPhone,
      'archivedAt': company.archivedAt?.toUtc().toIso8601String(),
    };

    if (serverUuid != null) {
      payload['id'] = serverUuid;
    }

    return payload;
  }

  bool _sameUuid(String expected, String actual) {
    return expected.trim().toLowerCase() == actual.trim().toLowerCase();
  }

  Map<String, dynamic> _toApiBankAccountPayload(
    BankAccount account, {
    String? serverUuid,
  }) {
    final payload = <String, dynamic>{
      'bankName': account.bankName,
      'accountTitle': account.accountTitle,
      'accountHolder': account.accountHolder,
      'accountNumber': account.accountNumber,
      'cardNumber': account.cardNumber,
      'shebaNumber': account.iban,
      'notes': account.note,
      'archivedAt': account.archivedAt?.toUtc().toIso8601String(),
    };

    if (serverUuid != null) {
      payload['id'] = serverUuid;
    }

    return payload;
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
    if (error is ChequeAttachmentPullBlockedByLocalChangesException ||
        error is ChequeAttachmentMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'تغییرات محلی صورتحساب‌های چک هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ChequeAttachmentPushException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'فایل صورتحساب چک برای همگام‌سازی معتبر نیست.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ChequeAttachmentPullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام‌سازی صورتحساب‌های چک نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CashPaymentAttachmentPullBlockedByLocalChangesException ||
        error is CashPaymentAttachmentMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage:
            'تغییرات محلی ضمیمه‌های واریز نقدی هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CashPaymentAttachmentPushException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'فایل ضمیمه واریز نقدی برای همگام سازی معتبر نیست.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CashPaymentAttachmentPullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام سازی ضمیمه‌های واریز نقدی نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CashPaymentPullBlockedByLocalChangesException ||
        error is CashPaymentMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'تغییرات محلی واریزهای نقدی هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CashPaymentPullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام سازی واریزهای نقدی نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }
    if (error is BankAccountPullBlockedByLocalChangesException ||
        error is BankAccountMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'تغییرات محلی حساب‌های بانکی هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ChequePullBlockedByLocalChangesException ||
        error is ChequeMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'تغییرات محلی چک‌ها هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is BankAccountPullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام سازی حساب‌های بانکی نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is ChequePullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام سازی چک‌ها نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CompanyPullBlockedByLocalChangesException ||
        error is CompanyMergeConflictException) {
      return SyncFailureDetails(
        type: SyncFailureType.localData,
        userSafeMessage: 'تغییرات محلی شرکت‌ها هنوز همگام نشده است.',
        technicalMessage: error.toString(),
      );
    }

    if (error is CompanyPullMergeException) {
      return SyncFailureDetails(
        type: SyncFailureType.httpApi,
        userSafeMessage: 'پاسخ همگام سازی شرکت‌ها نامعتبر است.',
        technicalMessage: error.toString(),
      );
    }

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
