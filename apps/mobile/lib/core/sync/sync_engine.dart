import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../network/api_client.dart';
import '../settings/connection_settings_repository.dart';
import 'sync_logger.dart';
import 'sync_service.dart';
import 'sync_state.dart';
import 'sync_status.dart';
import 'sync_trigger.dart';
import 'sync_trigger_dispatcher.dart';
import '../../data/repositories/local/local_bank_account_repository.dart';
import '../../data/repositories/local/local_company_repository.dart';
import '../../data/repositories/local/sync_queue_repository.dart';
import '../identity/bootstrap_result.dart';
import '../identity/identity_bootstrap_service.dart';

class SyncEngine {
  SyncEngine({
    required this._syncService,
    ApiClient? apiClient,
    required this._identityBootstrapService,
    required this._syncQueueRepository,
    required this._localCompanyRepository,
    required this._localBankAccountRepository,
    required this._connectionSettingsRepository,
    this._periodicInterval = const Duration(minutes: 2),
    Connectivity? connectivity,
  }) : _apiClient = apiClient ?? ApiClient(),
       _connectivity = connectivity ?? Connectivity();

  final SyncService _syncService;
  final ApiClient _apiClient;
  final IdentityBootstrapService _identityBootstrapService;
  final SyncQueueRepository _syncQueueRepository;
  final LocalCompanyRepository _localCompanyRepository;
  final LocalBankAccountRepository _localBankAccountRepository;
  final ConnectionSettingsRepository _connectionSettingsRepository;
  final Duration _periodicInterval;
  final Connectivity _connectivity;
  final SyncLogger _logger = SyncLogger.instance;
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  SyncState _state = const SyncState.initial();
  StreamSubscription<SyncTrigger>? _triggerSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicTimer;
  bool _started = false;
  bool _metadataHydrated = false;
  bool _isRunning = false;
  bool _runRequested = false;
  Completer<SyncServiceResult>? _runCompleter;

  static const List<Duration> _connectivityRetrySchedule = <Duration>[
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];

  SyncState get state => _state;
  Stream<SyncState> get states => _stateController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    await _syncQueueRepository.resetProcessingToPending();
    await _hydrateConnectivity();
    await _refreshStateCounts();
    await _hydrateSyncMetadata();

    _triggerSubscription = SyncTriggerDispatcher.instance.stream.listen((
      trigger,
    ) {
      unawaited(requestSync(trigger: trigger));
    });

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final isOnline = results.any(
        (result) => result != ConnectivityResult.none,
      );
      _emit(_state.copyWith(isOnline: isOnline));

      if (isOnline) {
        _logger.info('Connectivity restored. Scheduling sync.');
        unawaited(requestSync(trigger: SyncTrigger.connectivityRestored));
      }
    });

    _periodicTimer = Timer.periodic(_periodicInterval, (_) async {
      final hasPending = await _hasQueuedWork();
      if (hasPending) {
        _logger.debug('Periodic trigger found queued work. Scheduling sync.');
        unawaited(requestSync(trigger: SyncTrigger.periodic));
      }
    });

    _logger.info('SyncEngine started.');
    unawaited(requestSync(trigger: SyncTrigger.appStart));
  }

  Future<void> dispose() async {
    await _triggerSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    await _stateController.close();
  }

  Future<SyncServiceResult> syncNow() {
    return requestSync(trigger: SyncTrigger.manual);
  }

  Future<SyncServiceResult> retryManually() async {
    await _setConnectionFailureState(
      consecutiveFailures: 0,
      autoRetrySuspended: false,
    );
    return requestSync(trigger: SyncTrigger.manual);
  }

  Future<void> refreshState() async {
    await _refreshStateCounts();
  }

  Future<SyncServiceResult> requestSync({required SyncTrigger trigger}) async {
    _logger.info('Sync requested by trigger=${trigger.name}.');

    if (!_metadataHydrated) {
      await _hydrateSyncMetadata();
    }

    if (_state.autoRetrySuspended && trigger != SyncTrigger.manual) {
      _logger.info('Automatic sync ignored because auto retry is suspended.');
      _emit(_state.copyWith(syncStatus: SyncUiStatus.autoRetrySuspended));
      return const SyncServiceResult(
        totalPending: 0,
        processed: 0,
        succeeded: 0,
        failed: 0,
        performedServerCheck: false,
      );
    }

    if (_runCompleter != null) {
      _runRequested = true;
      _emit(_state.copyWith(syncStatus: SyncUiStatus.alreadyRunning));
      _logger.debug('Sync already running. Queued another execution request.');
      return _runCompleter!.future;
    }

    final completer = Completer<SyncServiceResult>();
    _runCompleter = completer;
    unawaited(_runLoop(completer));
    return completer.future;
  }

  Future<void> _runLoop(Completer<SyncServiceResult> completer) async {
    SyncServiceResult lastResult = const SyncServiceResult(
      totalPending: 0,
      processed: 0,
      succeeded: 0,
      failed: 0,
    );

    try {
      do {
        _runRequested = false;
        lastResult = await _runOnce();
      } while (_runRequested);

      completer.complete(lastResult);
    } catch (error, stackTrace) {
      _logger.error(
        'Synchronization loop failed.',
        error: error,
        stackTrace: stackTrace,
      );
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    } finally {
      _runCompleter = null;
    }
  }

  Future<SyncServiceResult> _runOnce() async {
    if (_isRunning) {
      _runRequested = true;
      return const SyncServiceResult(
        totalPending: 0,
        processed: 0,
        succeeded: 0,
        failed: 0,
      );
    }

    _isRunning = true;
    _emit(
      _state.copyWith(
        isSyncing: true,
        syncStatus: SyncUiStatus.syncing,
        clearLastError: true,
      ),
    );

    try {
      if (!_state.isOnline) {
        _logger.info('Sync skipped because device is offline. Queue retained.');
        await _handleConnectivityFailure(
          const SyncFailureDetails(
            type: SyncFailureType.serverConnectivity,
            userSafeMessage: 'عدم دسترسی به سرور',
            technicalMessage: 'ConnectivityPlus reported device offline.',
          ),
        );
        await _refreshStateCounts();
        return SyncServiceResult(
          totalPending: 0,
          processed: 0,
          succeeded: 0,
          failed: 0,
          serverUnavailable: true,
          failureDetails: _state.lastUserSafeErrorMessage == null
              ? null
              : const SyncFailureDetails(
                  type: SyncFailureType.serverConnectivity,
                  userSafeMessage: 'عدم دسترسی به سرور',
                  technicalMessage: 'ConnectivityPlus reported device offline.',
                ),
          performedServerCheck: false,
        );
      }

      final result = await _runWithConnectivityRetries();
      await _refreshStateCounts();
      return result;
    } catch (error, stackTrace) {
      final details = _syncService.classifyFailure(error);
      _emit(
        _state.copyWith(
          syncStatus: SyncUiStatus.failed,
          lastUserSafeErrorMessage: details.userSafeMessage,
          lastError: details.technicalMessage,
        ),
      );
      await _refreshStateCounts();
      _logger.error(
        'Synchronization cycle failed.',
        error: error,
        stackTrace: stackTrace,
      );
      return const SyncServiceResult(
        totalPending: 0,
        processed: 0,
        succeeded: 0,
        failed: 1,
      );
    } finally {
      _isRunning = false;
      final endedAs = _state.autoRetrySuspended
          ? SyncUiStatus.autoRetrySuspended
          : _state.syncStatus;
      _emit(
        _state.copyWith(
          isSyncing: false,
          bootstrapRunning: false,
          syncStatus: endedAs,
        ),
      );
    }
  }

  Future<SyncServiceResult> _runWithConnectivityRetries() async {
    SyncFailureDetails? lastConnectivityFailure;

    for (
      var attempt = 0;
      attempt < _connectivityRetrySchedule.length;
      attempt++
    ) {
      final delay = _connectivityRetrySchedule[attempt];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final attemptAt = DateTime.now();
      await _persistAttemptAt(attemptAt);

      final result = await _runSingleAttempt();

      if (!result.serverUnavailable) {
        final shouldUpdateSuccessfulSync =
            !result.hasFailures &&
            !result.wasAlreadyRunning &&
            result.performedServerCheck;

        if (shouldUpdateSuccessfulSync) {
          await _persistSuccessfulSyncAt(DateTime.now());
          await _setConnectionFailureState(
            consecutiveFailures: 0,
            autoRetrySuspended: false,
          );
          _emit(
            _state.copyWith(
              syncStatus: SyncUiStatus.success,
              clearLastUserSafeErrorMessage: true,
              clearLastError: true,
            ),
          );
        } else if (result.wasAlreadyRunning) {
          _emit(_state.copyWith(syncStatus: SyncUiStatus.alreadyRunning));
        } else if (result.hasFailures) {
          final safeMessage =
              result.failureDetails?.userSafeMessage ??
              'همگام سازی ناموفق بود.';
          _emit(
            _state.copyWith(
              syncStatus: SyncUiStatus.failed,
              lastUserSafeErrorMessage: safeMessage,
              lastError: result.failureDetails?.technicalMessage,
            ),
          );
        } else {
          _emit(_state.copyWith(syncStatus: SyncUiStatus.idle));
        }

        if (result.failureDetails?.type != SyncFailureType.serverConnectivity) {
          await _setConnectionFailureState(
            consecutiveFailures: 0,
            autoRetrySuspended: false,
          );
        }

        return result;
      }

      lastConnectivityFailure = result.failureDetails;
      final nextCount = _state.consecutiveConnectionFailures + 1;
      final shouldSuspend = nextCount >= _connectivityRetrySchedule.length;

      await _setConnectionFailureState(
        consecutiveFailures: nextCount,
        autoRetrySuspended: shouldSuspend,
      );

      final suspendedMessage = shouldSuspend
          ? 'عدم دسترسی به سرور؛ تلاش خودکار پس از ۳ بار ناموفق متوقف شد.'
          : 'عدم دسترسی به سرور';

      _emit(
        _state.copyWith(
          syncStatus: shouldSuspend
              ? SyncUiStatus.autoRetrySuspended
              : SyncUiStatus.serverUnavailable,
          lastUserSafeErrorMessage: suspendedMessage,
          lastError: lastConnectivityFailure?.technicalMessage,
        ),
      );

      if (shouldSuspend) {
        return SyncServiceResult(
          totalPending: result.totalPending,
          processed: result.processed,
          succeeded: result.succeeded,
          failed: result.failed,
          serverUnavailable: true,
          failureDetails:
              lastConnectivityFailure ??
              const SyncFailureDetails(
                type: SyncFailureType.serverConnectivity,
                userSafeMessage: 'عدم دسترسی به سرور',
                technicalMessage: 'Server connectivity attempts exhausted.',
              ),
          performedServerCheck: result.performedServerCheck,
          stoppedAtPhase: result.stoppedAtPhase,
        );
      }
    }

    return SyncServiceResult(
      totalPending: 0,
      processed: 0,
      succeeded: 0,
      failed: 1,
      serverUnavailable: true,
      failureDetails:
          lastConnectivityFailure ??
          const SyncFailureDetails(
            type: SyncFailureType.serverConnectivity,
            userSafeMessage: 'عدم دسترسی به سرور',
            technicalMessage: 'Server connectivity attempts exhausted.',
          ),
      performedServerCheck: false,
    );
  }

  Future<SyncServiceResult> _runSingleAttempt() async {
    final hasQueuedWork = await _hasQueuedWork();

    if (!hasQueuedWork) {
      _emit(_state.copyWith(syncStatus: SyncUiStatus.checkingServer));

      try {
        await _apiClient.checkHealth();
        return const SyncServiceResult(
          totalPending: 0,
          processed: 0,
          succeeded: 0,
          failed: 0,
          performedServerCheck: true,
        );
      } catch (error, stackTrace) {
        final details = _syncService.classifyFailure(error);
        _logger.error(
          'Server health check failed during empty-queue sync.',
          error: error,
          stackTrace: stackTrace,
        );

        if (details.type == SyncFailureType.serverConnectivity) {
          return SyncServiceResult(
            totalPending: 0,
            processed: 0,
            succeeded: 0,
            failed: 0,
            serverUnavailable: true,
            failureDetails: details,
            performedServerCheck: true,
          );
        }

        return SyncServiceResult(
          totalPending: 0,
          processed: 0,
          succeeded: 0,
          failed: 1,
          failureDetails: details,
          performedServerCheck: true,
        );
      }
    }

    try {
      await _ensureBootstrap();
      final result = await _syncService.sync();
      return result;
    } catch (error, stackTrace) {
      final details = _syncService.classifyFailure(error);
      _logger.error(
        'Sync attempt failed before queue processing completed.',
        error: error,
        stackTrace: stackTrace,
      );

      if (details.type == SyncFailureType.serverConnectivity) {
        return SyncServiceResult(
          totalPending: 0,
          processed: 0,
          succeeded: 0,
          failed: 0,
          serverUnavailable: true,
          failureDetails: details,
          performedServerCheck: true,
        );
      }

      return SyncServiceResult(
        totalPending: 0,
        processed: 0,
        succeeded: 0,
        failed: 1,
        failureDetails: details,
        performedServerCheck: true,
      );
    }
  }

  Future<void> _handleConnectivityFailure(SyncFailureDetails details) async {
    final nextCount = _state.consecutiveConnectionFailures + 1;
    final shouldSuspend = nextCount >= _connectivityRetrySchedule.length;

    await _setConnectionFailureState(
      consecutiveFailures: nextCount,
      autoRetrySuspended: shouldSuspend,
    );

    _emit(
      _state.copyWith(
        syncStatus: shouldSuspend
            ? SyncUiStatus.autoRetrySuspended
            : SyncUiStatus.serverUnavailable,
        lastUserSafeErrorMessage: shouldSuspend
            ? 'عدم دسترسی به سرور؛ تلاش خودکار پس از ۳ بار ناموفق متوقف شد.'
            : details.userSafeMessage,
        lastError: details.technicalMessage,
      ),
    );
  }

  Future<void> _ensureBootstrap() async {
    final hasCompleteIdentityMappings = await _hasCompleteIdentityMappings();
    if (hasCompleteIdentityMappings) {
      _logger.debug(
        'Bootstrap skipped: all server_uuid mappings already exist.',
      );
      return;
    }

    _emit(_state.copyWith(bootstrapRunning: true));
    _logger.info('Bootstrap started');

    try {
      final result = await _identityBootstrapService.bootstrap();
      _logBootstrapReport(result);
    } catch (error, stackTrace) {
      _logger.error(
        'Bootstrap failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> _hasQueuedWork() async {
    final pendingCount = await _syncQueueRepository.countByStatus(
      SyncStatus.pending,
    );
    final failedCount = await _syncQueueRepository.countByStatus(
      SyncStatus.failed,
    );

    return pendingCount > 0 || failedCount > 0;
  }

  Future<bool> _hasCompleteIdentityMappings() async {
    final companies = await _localCompanyRepository.getAll(
      includeArchived: true,
    );
    final bankAccounts = await _localBankAccountRepository.getAll(
      includeArchived: true,
    );

    final hasCompleteCompanyMappings = companies.every((company) {
      final serverUuid = company.serverUuid;
      return serverUuid != null && serverUuid.trim().isNotEmpty;
    });

    final hasCompleteBankMappings = bankAccounts.every((account) {
      final serverUuid = account.serverUuid;
      return serverUuid != null && serverUuid.trim().isNotEmpty;
    });

    return hasCompleteCompanyMappings && hasCompleteBankMappings;
  }

  Future<void> _refreshStateCounts() async {
    final pendingCount = await _syncQueueRepository.countByStatus(
      SyncStatus.pending,
    );
    final failedCount = await _syncQueueRepository.countByStatus(
      SyncStatus.failed,
    );

    _emit(
      _state.copyWith(pendingCount: pendingCount, failedCount: failedCount),
    );
  }

  Future<void> _hydrateSyncMetadata() async {
    final settings = await _connectionSettingsRepository.load();
    _metadataHydrated = true;
    _emit(
      _state.copyWith(
        lastSuccessfulSyncAt: settings.lastSuccessfulSyncAt,
        lastSyncAttemptAt: settings.lastSyncAttemptAt,
        consecutiveConnectionFailures: settings.consecutiveConnectionFailures,
        autoRetrySuspended: settings.autoRetrySuspended,
        lastUserSafeErrorMessage: settings.lastSyncUserSafeErrorMessage,
        syncStatus: settings.autoRetrySuspended
            ? SyncUiStatus.autoRetrySuspended
            : SyncUiStatus.idle,
      ),
    );
  }

  Future<void> _hydrateConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    _emit(_state.copyWith(isOnline: isOnline));
  }

  Future<void> _persistSuccessfulSyncAt(DateTime value) async {
    final settings = await _connectionSettingsRepository.load();
    await _connectionSettingsRepository.save(
      settings.copyWith(lastSuccessfulSyncAt: value),
    );
    _emit(_state.copyWith(lastSuccessfulSyncAt: value));
  }

  Future<void> _persistAttemptAt(DateTime value) async {
    final settings = await _connectionSettingsRepository.load();
    await _connectionSettingsRepository.save(
      settings.copyWith(lastSyncAttemptAt: value),
    );
    _emit(_state.copyWith(lastSyncAttemptAt: value));
  }

  Future<void> _setConnectionFailureState({
    required int consecutiveFailures,
    required bool autoRetrySuspended,
  }) async {
    final settings = await _connectionSettingsRepository.load();
    await _connectionSettingsRepository.save(
      settings.copyWith(
        consecutiveConnectionFailures: consecutiveFailures,
        autoRetrySuspended: autoRetrySuspended,
        lastSyncUserSafeErrorMessage: autoRetrySuspended
            ? 'عدم دسترسی به سرور؛ تلاش خودکار پس از ۳ بار ناموفق متوقف شد.'
            : _state.lastUserSafeErrorMessage,
      ),
    );

    _emit(
      _state.copyWith(
        consecutiveConnectionFailures: consecutiveFailures,
        autoRetrySuspended: autoRetrySuspended,
      ),
    );
  }

  void _logBootstrapReport(BootstrapResult result) {
    _logger.info('Companies:');
    _logger.info('matched = ${result.matchedCompanies.length}');
    _logger.info('conflicts = ${result.companyConflicts.length}');
    _logger.info('unresolved = ${result.companyUnresolved.length}');
    _logger.info('Bank accounts:');
    _logger.info('matched = ${result.matchedBankAccounts.length}');
    _logger.info('conflicts = ${result.bankConflicts.length}');
    _logger.info('unresolved = ${result.bankUnresolved.length}');
  }

  void _emit(SyncState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
