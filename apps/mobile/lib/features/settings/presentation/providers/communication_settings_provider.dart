import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/identity/identity_bootstrap_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/sync/cheque_sync_identity_resolver.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/sync/sync_identity_resolver.dart';
import '../../../../core/sync/sync_state.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../core/settings/connection_profile.dart';
import '../../../../core/settings/connection_settings_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../data/repositories/local/sync_queue_repository.dart';
import '../../../../data/repositories/remote/remote_bank_accounts_repository.dart';
import '../../../../data/repositories/remote/remote_cheque_repository.dart';
import '../../../../data/repositories/remote/remote_company_repository.dart';
import 'communication_settings_state.dart';

final connectionSettingsRepositoryProvider =
    Provider<ConnectionSettingsRepository>((ref) {
      return ConnectionSettingsRepository();
    });

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.development;
});

final communicationSettingsProvider =
    StateNotifierProvider<
      CommunicationSettingsNotifier,
      CommunicationSettingsState
    >((ref) {
      return CommunicationSettingsNotifier(
        ref: ref,
        settingsRepository: ref.watch(connectionSettingsRepositoryProvider),
      )..load();
    });

final appConfigProvider = Provider<AppConfig>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final state = ref.watch(communicationSettingsProvider);
  final profile = _profileFromState(state);

  final settings = ConnectionSettings(
    activeProfileId: profile.id,
    profiles: [profile],
    autoSync: state.autoSync,
    wifiOnly: state.wifiOnly,
    lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
    lastSyncAttemptAt: state.lastSyncAttemptAt,
    consecutiveConnectionFailures: state.consecutiveConnectionFailures,
    autoRetrySuspended: state.autoRetrySuspended,
    lastSyncUserSafeErrorMessage: state.lastSyncUserSafeErrorMessage,
    lastSuccessfulCheck: state.lastSuccessfulCheck,
  );

  return AppConfig(currentEnvironment: environment, settings: settings);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(appConfig: config);
});

final identityBootstrapServiceProvider = Provider<IdentityBootstrapService>((
  ref,
) {
  return IdentityBootstrapService(
    apiClient: ref.watch(apiClientProvider),
    localCompanyRepository: LocalCompanyRepository(DatabaseService.instance),
    localBankAccountRepository: LocalBankAccountRepository(
      DatabaseService.instance,
    ),
  );
});

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(DatabaseService.instance);
});

final syncWorkerServiceProvider = Provider<SyncService>((ref) {
  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );
  final localBankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );
  final localChequeRepository = LocalChequeRepository(DatabaseService.instance);
  final syncIdentityResolver = SyncIdentityResolver(DatabaseService.instance);
  final remoteCompanyRepository = RemoteCompanyRepository(
    ref.watch(apiClientProvider),
  );
  final remoteBankAccountsRepository = RemoteBankAccountsRepository(
    ref.watch(apiClientProvider),
  );
  final remoteChequeRepository = RemoteChequeRepository(
    ref.watch(apiClientProvider),
  );

  return SyncService(
    syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
    localCompanyRepository: localCompanyRepository,
    localBankAccountRepository: localBankAccountRepository,
    localChequeRepository: localChequeRepository,
    identityResolver: syncIdentityResolver,
    remoteCompanyRepository: remoteCompanyRepository,
    remoteBankAccountsRepository: remoteBankAccountsRepository,
    remoteChequeRepository: remoteChequeRepository,
    chequeSyncIdentityResolver: ChequeSyncIdentityResolver(
      localChequeRepository: localChequeRepository,
      remoteChequeRepository: remoteChequeRepository,
      identityResolver: syncIdentityResolver,
    ),
  );
});

final syncServiceProvider = Provider<SyncEngine>((ref) {
  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );
  final localBankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );
  final engine = SyncEngine(
    syncService: ref.watch(syncWorkerServiceProvider),
    apiClient: ref.watch(apiClientProvider),
    identityBootstrapService: ref.watch(identityBootstrapServiceProvider),
    syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
    localCompanyRepository: localCompanyRepository,
    localBankAccountRepository: localBankAccountRepository,
    connectionSettingsRepository: ref.watch(
      connectionSettingsRepositoryProvider,
    ),
  );

  ref.onDispose(() {
    unawaited(engine.dispose());
  });

  return engine;
});

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncServiceProvider);
  return () async* {
    yield engine.state;
    yield* engine.states;
  }();
});

class CommunicationSettingsNotifier
    extends StateNotifier<CommunicationSettingsState> {
  CommunicationSettingsNotifier({
    required this._ref,
    required this._settingsRepository,
  }) : super(CommunicationSettingsState.initial());

  final Ref _ref;
  final ConnectionSettingsRepository _settingsRepository;
  String _activeProfileId = ConnectionSettingsDefaults.defaultProfile.id;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final settings = await _settingsRepository.load();
    final profile = settings.activeProfile;
    _activeProfileId = profile.id;

    state = state.copyWith(
      isLoading: false,
      profileName: profile.name,
      host: profile.host,
      port: profile.port.toString(),
      apiVersion: profile.apiVersion,
      useHttps: profile.useHttps,
      connectTimeout: profile.connectTimeout.toString(),
      receiveTimeout: profile.receiveTimeout.toString(),
      autoSync: settings.autoSync,
      wifiOnly: settings.wifiOnly,
      lastSuccessfulSyncAt: settings.lastSuccessfulSyncAt,
      lastSyncAttemptAt: settings.lastSyncAttemptAt,
      consecutiveConnectionFailures: settings.consecutiveConnectionFailures,
      autoRetrySuspended: settings.autoRetrySuspended,
      lastSyncUserSafeErrorMessage: settings.lastSyncUserSafeErrorMessage,
      lastSuccessfulCheck: settings.lastSuccessfulCheck,
      connectionStatus: 'Not tested',
      databaseStatus: 'Unknown',
      healthResponse: null,
      clearResponseTime: true,
    );
  }

  void updateProfileName(String value) {
    state = state.copyWith(profileName: value);
  }

  void updateHost(String value) {
    state = state.copyWith(host: value);
  }

  void updatePort(String value) {
    state = state.copyWith(port: value);
  }

  void updateApiVersion(String value) {
    state = state.copyWith(apiVersion: value);
  }

  void updateConnectTimeout(String value) {
    state = state.copyWith(connectTimeout: value);
  }

  void updateReceiveTimeout(String value) {
    state = state.copyWith(receiveTimeout: value);
  }

  void setUseHttps(bool value) {
    state = state.copyWith(useHttps: value);
  }

  void setAutoSync(bool value) {
    state = state.copyWith(autoSync: value);
  }

  void setWifiOnly(bool value) {
    state = state.copyWith(wifiOnly: value);
  }

  Future<void> onSyncCompletedSuccessfully() async {
    final now = DateTime.now();

    await _settingsRepository.save(_buildSettings(lastSuccessfulSyncAt: now));

    state = state.copyWith(lastSuccessfulSyncAt: now, clearError: true);
  }

  void updateLastSuccessfulSyncAt(DateTime value) {
    final current = state.lastSuccessfulSyncAt;

    if (current != null && current == value) {
      return;
    }

    state = state.copyWith(lastSuccessfulSyncAt: value, clearError: true);
  }

  void updateLastSyncAttemptAt(DateTime value) {
    final current = state.lastSyncAttemptAt;

    if (current != null && current == value) {
      return;
    }

    state = state.copyWith(lastSyncAttemptAt: value, clearError: true);
  }

  Future<void> save() async {
    final validatedError = _validateInputs();

    if (validatedError != null) {
      state = state.copyWith(errorMessage: validatedError);
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _settingsRepository.save(_buildSettings());

      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Settings saved successfully.',
      );
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Saving settings failed. Please try again.',
      );
    }
  }

  Future<void> testConnection() async {
    await save();

    if (state.errorMessage != null &&
        state.errorMessage != 'Settings saved successfully.') {
      return;
    }

    state = state.copyWith(
      isTesting: true,
      clearError: true,
      connectionStatus: 'Testing...',
      databaseStatus: 'Checking...',
      healthResponse: null,
      clearResponseTime: true,
    );

    final apiClient = _buildApiClientForCurrentState();

    try {
      final health = await apiClient.checkHealth();

      final now = DateTime.now();
      await _settingsRepository.save(_buildSettings(lastSuccessfulCheck: now));

      final dbStatus = health.database?.status?.trim().isNotEmpty == true
          ? health.database!.status!.trim()
          : 'Unknown';

      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Connected',
        databaseStatus: dbStatus,
        healthResponse: health,
        responseTime: health.responseDuration.inMilliseconds,
        lastSuccessfulCheck: now,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Failed',
        databaseStatus: 'Unknown',
        clearHealthResponse: true,
        clearResponseTime: true,
        errorMessage: _friendlyNetworkError(error),
      );
    } catch (_) {
      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Failed',
        databaseStatus: 'Unknown',
        clearHealthResponse: true,
        clearResponseTime: true,
        errorMessage:
            'Connection test failed. Please check your server settings.',
      );
    }
  }

  String? _validateInputs() {
    if (state.profileName.trim().isEmpty) {
      return 'Profile name is required.';
    }

    if (state.host.trim().isEmpty) {
      return 'Server host is required.';
    }

    final port = int.tryParse(state.port.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Port must be a number between 1 and 65535.';
    }

    if (state.apiVersion.trim().isEmpty) {
      return 'API version is required.';
    }

    final connectTimeout = int.tryParse(state.connectTimeout.trim());
    if (connectTimeout == null || connectTimeout < 100) {
      return 'Connect timeout must be at least 100 ms.';
    }

    final receiveTimeout = int.tryParse(state.receiveTimeout.trim());
    if (receiveTimeout == null || receiveTimeout < 100) {
      return 'Receive timeout must be at least 100 ms.';
    }

    return null;
  }

  String _friendlyNetworkError(ApiException error) {
    if (error is ApiTimeoutException) {
      return 'Connection timed out. Please verify timeout settings or server availability.';
    }

    if (error is ApiNetworkException) {
      return 'Server is unreachable. Check host, port, and local network access.';
    }

    if (error is ApiHttpException) {
      return 'Server responded with error ${error.statusCode}. Please check API health endpoint.';
    }

    return 'Connection test failed. Please review communication settings.';
  }

  ApiClient _buildApiClientForCurrentState() {
    final environment = _ref.read(appEnvironmentProvider);
    final settings = _buildSettings();

    return ApiClient(
      appConfig: AppConfig(currentEnvironment: environment, settings: settings),
    );
  }

  ConnectionSettings _buildSettings({
    DateTime? lastSuccessfulSyncAt,
    DateTime? lastSyncAttemptAt,
    DateTime? lastSuccessfulCheck,
  }) {
    final profile = _profileFromState(state).copyWith(id: _activeProfileId);

    return ConnectionSettings(
      activeProfileId: _activeProfileId,
      profiles: [profile],
      autoSync: state.autoSync,
      wifiOnly: state.wifiOnly,
      lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? state.lastSuccessfulSyncAt,
      lastSyncAttemptAt: lastSyncAttemptAt ?? state.lastSyncAttemptAt,
      consecutiveConnectionFailures: state.consecutiveConnectionFailures,
      autoRetrySuspended: state.autoRetrySuspended,
      lastSyncUserSafeErrorMessage: state.lastSyncUserSafeErrorMessage,
      lastSuccessfulCheck: lastSuccessfulCheck ?? state.lastSuccessfulCheck,
    );
  }
}

ConnectionProfile _profileFromState(CommunicationSettingsState state) {
  final defaults = ConnectionSettingsDefaults.defaultProfile;

  final profileName = state.profileName.trim();
  final host = state.host.trim();
  final apiVersion = state.apiVersion.trim();
  final port = int.tryParse(state.port.trim());
  final connectTimeout = int.tryParse(state.connectTimeout.trim());
  final receiveTimeout = int.tryParse(state.receiveTimeout.trim());

  return ConnectionProfile(
    id: defaults.id,
    name: profileName.isEmpty ? defaults.name : profileName,
    host: host.isEmpty ? defaults.host : host,
    port: port ?? defaults.port,
    useHttps: state.useHttps,
    apiVersion: apiVersion.isEmpty ? defaults.apiVersion : apiVersion,
    connectTimeout: connectTimeout ?? defaults.connectTimeout,
    receiveTimeout: receiveTimeout ?? defaults.receiveTimeout,
  );
}
