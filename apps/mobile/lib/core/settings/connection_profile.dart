class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.useHttps,
    required this.apiVersion,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final bool useHttps;
  final String apiVersion;
  final int connectTimeout;
  final int receiveTimeout;

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? useHttps,
    String? apiVersion,
    int? connectTimeout,
    int? receiveTimeout,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      useHttps: useHttps ?? this.useHttps,
      apiVersion: apiVersion ?? this.apiVersion,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'useHttps': useHttps,
      'apiVersion': apiVersion,
      'connectTimeout': connectTimeout,
      'receiveTimeout': receiveTimeout,
    };
  }

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : 'default',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Default',
      host: (json['host'] as String?)?.trim().isNotEmpty == true
          ? (json['host'] as String).trim()
          : '192.168.1.215',
      port: _readInt(json['port'], fallback: 3000),
      useHttps: json['useHttps'] as bool? ?? false,
      apiVersion: (json['apiVersion'] as String?)?.trim().isNotEmpty == true
          ? (json['apiVersion'] as String).trim()
          : 'v1',
      connectTimeout: _readInt(json['connectTimeout'], fallback: 15000),
      receiveTimeout: _readInt(json['receiveTimeout'], fallback: 15000),
    );
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    return fallback;
  }
}

class ConnectionSettings {
  const ConnectionSettings({
    required this.activeProfileId,
    required this.profiles,
    required this.autoSync,
    required this.wifiOnly,
    this.displayName = 'ارسلان',
    this.greenThreshold = 600000000,
    this.orangeThreshold = 700000000,
    this.redThreshold = 800000000,
    this.largeAmountThreshold = 500000000,
    this.lastSuccessfulSyncAt,
    this.lastSyncAttemptAt,
    this.consecutiveConnectionFailures = 0,
    this.autoRetrySuspended = false,
    this.lastSyncUserSafeErrorMessage,
    this.lastSuccessfulCheck,
  });

  final String activeProfileId;
  final List<ConnectionProfile> profiles;
  final bool autoSync;
  final bool wifiOnly;
  final String displayName;
  final int greenThreshold;
  final int orangeThreshold;
  final int redThreshold;
  final int largeAmountThreshold;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastSyncAttemptAt;
  final int consecutiveConnectionFailures;
  final bool autoRetrySuspended;
  final String? lastSyncUserSafeErrorMessage;
  final DateTime? lastSuccessfulCheck;

  ConnectionProfile get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) {
        return profile;
      }
    }

    return profiles.first;
  }

  ConnectionSettings copyWith({
    String? activeProfileId,
    List<ConnectionProfile>? profiles,
    bool? autoSync,
    bool? wifiOnly,
    String? displayName,
    int? greenThreshold,
    int? orangeThreshold,
    int? redThreshold,
    int? largeAmountThreshold,
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
  }) {
    return ConnectionSettings(
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
      autoSync: autoSync ?? this.autoSync,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      displayName: displayName ?? this.displayName,
      greenThreshold: greenThreshold ?? this.greenThreshold,
      orangeThreshold: orangeThreshold ?? this.orangeThreshold,
      redThreshold: redThreshold ?? this.redThreshold,
      largeAmountThreshold: largeAmountThreshold ?? this.largeAmountThreshold,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeProfileId': activeProfileId,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'autoSync': autoSync,
      'wifiOnly': wifiOnly,
      'displayName': displayName,
      'greenThreshold': greenThreshold,
      'orangeThreshold': orangeThreshold,
      'redThreshold': redThreshold,
      'largeAmountThreshold': largeAmountThreshold,
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
      'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
      'consecutiveConnectionFailures': consecutiveConnectionFailures,
      'autoRetrySuspended': autoRetrySuspended,
      'lastSyncUserSafeErrorMessage': lastSyncUserSafeErrorMessage,
      'lastSuccessfulCheck': lastSuccessfulCheck?.toIso8601String(),
    };
  }

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) {
    final profilesJson = json['profiles'] as List<dynamic>?;
    final profiles = profilesJson == null || profilesJson.isEmpty
        ? [ConnectionSettingsDefaults.defaultProfile]
        : profilesJson
              .whereType<Map<String, dynamic>>()
              .map(ConnectionProfile.fromJson)
              .toList();

    final activeProfileId = (json['activeProfileId'] as String?)?.trim();

    final resolvedActiveId =
        profiles.any((profile) => profile.id == activeProfileId)
        ? activeProfileId!
        : profiles.first.id;

    return ConnectionSettings(
      activeProfileId: resolvedActiveId,
      profiles: profiles,
      autoSync: json['autoSync'] as bool? ?? false,
      wifiOnly: json['wifiOnly'] as bool? ?? false,
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : 'ارسلان',
      greenThreshold: _toPositiveInt(
        json['greenThreshold'],
        fallback: 600000000,
      ),
      orangeThreshold: _toPositiveInt(
        json['orangeThreshold'],
        fallback: 700000000,
      ),
      redThreshold: _toPositiveInt(json['redThreshold'], fallback: 800000000),
      largeAmountThreshold: _toPositiveInt(
        json['largeAmountThreshold'],
        fallback: 500000000,
      ),
      lastSuccessfulSyncAt: _tryParseDate(
        (json['lastSuccessfulSyncAt'] ?? json['lastSync']) as String?,
      ),
      lastSyncAttemptAt: _tryParseDate(json['lastSyncAttemptAt'] as String?),
      consecutiveConnectionFailures: _toPositiveOrZeroInt(
        json['consecutiveConnectionFailures'],
      ),
      autoRetrySuspended: json['autoRetrySuspended'] as bool? ?? false,
      lastSyncUserSafeErrorMessage:
          (json['lastSyncUserSafeErrorMessage'] as String?)?.trim(),
      lastSuccessfulCheck: _tryParseDate(
        json['lastSuccessfulCheck'] as String?,
      ),
    );
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  static int _toPositiveInt(Object? value, {required int fallback}) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is num && value > 0) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return fallback;
  }

  static int _toPositiveOrZeroInt(Object? value) {
    if (value is int && value >= 0) {
      return value;
    }

    if (value is num && value >= 0) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }

    return 0;
  }
}

abstract final class ConnectionSettingsDefaults {
  ConnectionSettingsDefaults._();

  static const ConnectionProfile defaultProfile = ConnectionProfile(
    id: 'default',
    name: 'Default',
    host: '192.168.1.215',
    port: 3000,
    useHttps: false,
    apiVersion: 'v1',
    connectTimeout: 15000,
    receiveTimeout: 15000,
  );

  static const ConnectionSettings defaultSettings = ConnectionSettings(
    activeProfileId: 'default',
    profiles: [defaultProfile],
    autoSync: false,
    wifiOnly: false,
  );
}
