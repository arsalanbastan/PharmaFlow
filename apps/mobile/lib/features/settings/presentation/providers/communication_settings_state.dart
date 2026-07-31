import '../../../../core/settings/connection_profile.dart';

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
    required this.lastSync,
    required this.lastSuccessfulCheck,
    required this.connectionStatus,
    required this.databaseStatus,
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
      lastSync: null,
      lastSuccessfulCheck: null,
      connectionStatus: 'Not tested',
      databaseStatus: 'Unknown',
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
  final DateTime? lastSync;
  final DateTime? lastSuccessfulCheck;
  final String connectionStatus;
  final String databaseStatus;
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
    DateTime? lastSync,
    bool clearLastSync = false,
    DateTime? lastSuccessfulCheck,
    bool clearLastSuccessfulCheck = false,
    String? connectionStatus,
    String? databaseStatus,
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
      lastSync: clearLastSync ? null : (lastSync ?? this.lastSync),
      lastSuccessfulCheck: clearLastSuccessfulCheck
          ? null
          : (lastSuccessfulCheck ?? this.lastSuccessfulCheck),
      connectionStatus: connectionStatus ?? this.connectionStatus,
      databaseStatus: databaseStatus ?? this.databaseStatus,
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
