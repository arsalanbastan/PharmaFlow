import '../../../../core/settings/connection_profile.dart';
import '../../../../core/network/models/health_response.dart';

class CommunicationSettingsState {
  const CommunicationSettingsState({
    required this.isLoading,
    required this.isSaving,
    required this.isTesting,
    required this.profileName,
    required this.host,
    required this.port,
    required this.apiVersion,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.useHttps,
    required this.autoSync,
    required this.wifiOnly,
    required this.lastSuccessfulSyncAt,
    required this.lastSyncAttemptAt,
    required this.consecutiveConnectionFailures,
    required this.autoRetrySuspended,
    required this.lastSyncUserSafeErrorMessage,
    required this.lastSuccessfulCheck,
    required this.connectionStatus,
    required this.databaseStatus,
    this.healthResponse,
    this.responseTime,
    this.errorMessage,
  });

  factory CommunicationSettingsState.initial() {
    return const CommunicationSettingsState(
      isLoading: true,
      isSaving: false,
      isTesting: false,
      profileName: '',
      host: '',
      port: '3000',
      apiVersion: 'v1',
      connectTimeout: '15000',
      receiveTimeout: '15000',
      useHttps: false,
      autoSync: false,
      wifiOnly: false,
      lastSuccessfulSyncAt: null,
      lastSyncAttemptAt: null,
      consecutiveConnectionFailures: 0,
      autoRetrySuspended: false,
      lastSyncUserSafeErrorMessage: null,
      lastSuccessfulCheck: null,
      connectionStatus: 'Not tested',
      databaseStatus: 'Unknown',
      healthResponse: null,
    );
  }

  final bool isLoading;
  final bool isSaving;
  final bool isTesting;
  final String profileName;
  final String host;
  final String port;
  final String apiVersion;
  final String connectTimeout;
  final String receiveTimeout;
  final bool useHttps;
  final bool autoSync;
  final bool wifiOnly;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastSyncAttemptAt;
  final int consecutiveConnectionFailures;
  final bool autoRetrySuspended;
  final String? lastSyncUserSafeErrorMessage;
  final DateTime? lastSuccessfulCheck;
  final String connectionStatus;
  final String databaseStatus;
  final HealthResponse? healthResponse;
  final int? responseTime;
  final String? errorMessage;

  CommunicationSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isTesting,
    String? profileName,
    String? host,
    String? port,
    String? apiVersion,
    String? connectTimeout,
    String? receiveTimeout,
    bool? useHttps,
    bool? autoSync,
    bool? wifiOnly,
    DateTime? lastSuccessfulSyncAt,
    bool clearLastSuccessfulSyncAt = false,
    DateTime? lastSyncAttemptAt,
    bool clearLastSyncAttemptAt = false,
    int? consecutiveConnectionFailures,
    bool? autoRetrySuspended,
    String? lastSyncUserSafeErrorMessage,
    bool clearLastSyncUserSafeErrorMessage = false,
    DateTime? lastSuccessfulCheck,
    bool clearLastSuccessfulCheck = false,
    String? connectionStatus,
    String? databaseStatus,
    HealthResponse? healthResponse,
    bool clearHealthResponse = false,
    int? responseTime,
    bool clearResponseTime = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CommunicationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isTesting: isTesting ?? this.isTesting,
      profileName: profileName ?? this.profileName,
      host: host ?? this.host,
      port: port ?? this.port,
      apiVersion: apiVersion ?? this.apiVersion,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      useHttps: useHttps ?? this.useHttps,
      autoSync: autoSync ?? this.autoSync,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      lastSuccessfulSyncAt: clearLastSuccessfulSyncAt
          ? null
          : (lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt),
      lastSyncAttemptAt: clearLastSyncAttemptAt
          ? null
          : (lastSyncAttemptAt ?? this.lastSyncAttemptAt),
      consecutiveConnectionFailures:
          consecutiveConnectionFailures ?? this.consecutiveConnectionFailures,
      autoRetrySuspended: autoRetrySuspended ?? this.autoRetrySuspended,
      lastSyncUserSafeErrorMessage: clearLastSyncUserSafeErrorMessage
          ? null
          : (lastSyncUserSafeErrorMessage ?? this.lastSyncUserSafeErrorMessage),
      lastSuccessfulCheck: clearLastSuccessfulCheck
          ? null
          : (lastSuccessfulCheck ?? this.lastSuccessfulCheck),
      connectionStatus: connectionStatus ?? this.connectionStatus,
      databaseStatus: databaseStatus ?? this.databaseStatus,
      healthResponse: clearHealthResponse
          ? null
          : (healthResponse ?? this.healthResponse),
      responseTime: clearResponseTime
          ? null
          : (responseTime ?? this.responseTime),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  ConnectionProfile toProfile(ConnectionProfile baseProfile) {
    return baseProfile.copyWith(
      name: profileName.trim().isEmpty ? baseProfile.name : profileName.trim(),
      host: host.trim(),
      port: int.parse(port.trim()),
      useHttps: useHttps,
      apiVersion: apiVersion.trim(),
      connectTimeout: int.parse(connectTimeout.trim()),
      receiveTimeout: int.parse(receiveTimeout.trim()),
    );
  }
}
