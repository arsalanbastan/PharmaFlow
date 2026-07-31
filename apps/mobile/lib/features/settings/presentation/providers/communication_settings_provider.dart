import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/config/endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/settings/connection_profile.dart';
import '../../../../core/settings/connection_settings_repository.dart';
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
    lastSync: state.lastSync,
    lastSuccessfulCheck: state.lastSuccessfulCheck,
  );

  return AppConfig(currentEnvironment: environment, settings: settings);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(appConfig: config);
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
      lastSync: settings.lastSync,
      lastSuccessfulCheck: settings.lastSuccessfulCheck,
      connectionStatus: 'Not tested',
      databaseStatus: 'Unknown',
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
      clearResponseTime: true,
    );

    final watch = Stopwatch()..start();
    final apiClient = _ref.read(apiClientProvider);

    try {
      final payload = await apiClient.get(Endpoints.health);
      watch.stop();

      final now = DateTime.now();
      await _settingsRepository.save(_buildSettings(lastSuccessfulCheck: now));

      final dbStatus = _extractDatabaseStatus(payload);

      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Connected',
        databaseStatus: dbStatus,
        responseTime: watch.elapsedMilliseconds,
        lastSuccessfulCheck: now,
        errorMessage: 'Connection test passed.',
      );
    } on ApiException catch (error) {
      watch.stop();
      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Unreachable',
        databaseStatus: 'Unknown',
        responseTime: watch.elapsedMilliseconds,
        errorMessage: _friendlyNetworkError(error),
      );
    } catch (_) {
      watch.stop();
      state = state.copyWith(
        isTesting: false,
        connectionStatus: 'Unreachable',
        databaseStatus: 'Unknown',
        responseTime: watch.elapsedMilliseconds,
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

  String _extractDatabaseStatus(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final directStatus = payload['databaseStatus'];
      if (directStatus is String && directStatus.trim().isNotEmpty) {
        return directStatus;
      }

      final db = payload['database'];
      if (db is Map<String, dynamic>) {
        final nestedStatus = db['status'];
        if (nestedStatus is String && nestedStatus.trim().isNotEmpty) {
          return nestedStatus;
        }
      }

      final altDb = payload['db'];
      if (altDb is Map<String, dynamic>) {
        final nestedStatus = altDb['status'];
        if (nestedStatus is String && nestedStatus.trim().isNotEmpty) {
          return nestedStatus;
        }
      }

      final status = payload['status'];
      if (status is String && status.trim().isNotEmpty) {
        return status;
      }
    }

    return 'Healthy';
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

  ConnectionSettings _buildSettings({DateTime? lastSuccessfulCheck}) {
    final profile = _profileFromState(state).copyWith(id: _activeProfileId);

    return ConnectionSettings(
      activeProfileId: _activeProfileId,
      profiles: [profile],
      autoSync: state.autoSync,
      wifiOnly: state.wifiOnly,
      lastSync: state.lastSync,
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
