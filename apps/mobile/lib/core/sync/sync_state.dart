enum SyncUiStatus {
  idle,
  checkingServer,
  syncing,
  success,
  serverUnavailable,
  failed,
  autoRetrySuspended,
  alreadyRunning,
}

class SyncState {
  const SyncState({
    required this.isSyncing,
    required this.isOnline,
    required this.pendingCount,
    required this.failedCount,
    required this.lastSuccessfulSyncAt,
    required this.lastSyncAttemptAt,
    required this.consecutiveConnectionFailures,
    required this.autoRetrySuspended,
    required this.syncStatus,
    required this.lastUserSafeErrorMessage,
    required this.lastError,
    required this.bootstrapRunning,
  });

  const SyncState.initial()
    : isSyncing = false,
      isOnline = true,
      pendingCount = 0,
      failedCount = 0,
      lastSuccessfulSyncAt = null,
      lastSyncAttemptAt = null,
      consecutiveConnectionFailures = 0,
      autoRetrySuspended = false,
      syncStatus = SyncUiStatus.idle,
      lastUserSafeErrorMessage = null,
      lastError = null,
      bootstrapRunning = false;

  final bool isSyncing;
  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastSyncAttemptAt;
  final int consecutiveConnectionFailures;
  final bool autoRetrySuspended;
  final SyncUiStatus syncStatus;
  final String? lastUserSafeErrorMessage;
  final String? lastError;
  final bool bootstrapRunning;

  SyncState copyWith({
    bool? isSyncing,
    bool? isOnline,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSuccessfulSyncAt,
    bool clearLastSuccessfulSyncAt = false,
    DateTime? lastSyncAttemptAt,
    bool clearLastSyncAttemptAt = false,
    int? consecutiveConnectionFailures,
    bool? autoRetrySuspended,
    SyncUiStatus? syncStatus,
    String? lastUserSafeErrorMessage,
    bool clearLastUserSafeErrorMessage = false,
    String? lastError,
    bool clearLastError = false,
    bool? bootstrapRunning,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSuccessfulSyncAt: clearLastSuccessfulSyncAt
          ? null
          : (lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt),
      lastSyncAttemptAt: clearLastSyncAttemptAt
          ? null
          : (lastSyncAttemptAt ?? this.lastSyncAttemptAt),
      consecutiveConnectionFailures:
          consecutiveConnectionFailures ?? this.consecutiveConnectionFailures,
      autoRetrySuspended: autoRetrySuspended ?? this.autoRetrySuspended,
      syncStatus: syncStatus ?? this.syncStatus,
      lastUserSafeErrorMessage: clearLastUserSafeErrorMessage
          ? null
          : (lastUserSafeErrorMessage ?? this.lastUserSafeErrorMessage),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      bootstrapRunning: bootstrapRunning ?? this.bootstrapRunning,
    );
  }
}
