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
      port: (json['port'] as num?)?.toInt() ?? 3000,
      useHttps: json['useHttps'] as bool? ?? false,
      apiVersion: (json['apiVersion'] as String?)?.trim().isNotEmpty == true
          ? (json['apiVersion'] as String).trim()
          : 'v1',
      connectTimeout: (json['connectTimeout'] as num?)?.toInt() ?? 15000,
      receiveTimeout: (json['receiveTimeout'] as num?)?.toInt() ?? 15000,
    );
  }
}

class ConnectionSettings {
  const ConnectionSettings({
    required this.activeProfileId,
    required this.profiles,
    required this.autoSync,
    required this.wifiOnly,
    this.lastSync,
    this.lastSuccessfulCheck,
  });

  final String activeProfileId;
  final List<ConnectionProfile> profiles;
  final bool autoSync;
  final bool wifiOnly;
  final DateTime? lastSync;
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
    DateTime? lastSync,
    bool clearLastSync = false,
    DateTime? lastSuccessfulCheck,
    bool clearLastSuccessfulCheck = false,
  }) {
    return ConnectionSettings(
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
      autoSync: autoSync ?? this.autoSync,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      lastSync: clearLastSync ? null : (lastSync ?? this.lastSync),
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
      'lastSync': lastSync?.toIso8601String(),
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
      lastSync: _tryParseDate(json['lastSync'] as String?),
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
