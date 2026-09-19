class HealthDatabaseResponse {
  const HealthDatabaseResponse({this.status});

  final String? status;

  factory HealthDatabaseResponse.fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return HealthDatabaseResponse(status: _readString(json['status']));
    }

    return const HealthDatabaseResponse();
  }
}

class HealthResponse {
  const HealthResponse({
    this.status,
    this.service,
    this.version,
    this.environment,
    this.database,
    this.serverTime,
    this.responseDuration = Duration.zero,
  });

  final String? status;
  final String? service;
  final String? version;
  final String? environment;
  final HealthDatabaseResponse? database;
  final DateTime? serverTime;
  final Duration responseDuration;

  HealthResponse copyWith({
    String? status,
    String? service,
    String? version,
    String? environment,
    HealthDatabaseResponse? database,
    DateTime? serverTime,
    Duration? responseDuration,
  }) {
    return HealthResponse(
      status: status ?? this.status,
      service: service ?? this.service,
      version: version ?? this.version,
      environment: environment ?? this.environment,
      database: database ?? this.database,
      serverTime: serverTime ?? this.serverTime,
      responseDuration: responseDuration ?? this.responseDuration,
    );
  }

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: _readString(json['status']),
      service: _readString(json['service']),
      version: _readString(json['version']),
      environment: _readString(json['environment']),
      database: json.containsKey('database')
          ? HealthDatabaseResponse.fromJson(json['database'])
          : null,
      serverTime: _readDateTime(json['serverTime']),
    );
  }
}

String? _readString(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  return value.toString();
}

DateTime? _readDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }

  return null;
}
