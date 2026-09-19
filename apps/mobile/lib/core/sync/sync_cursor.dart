class SyncCursor {
  const SyncCursor({
    required this.entityType,
    required this.updatedAt,
    required this.serverUuid,
  });

  final String entityType;
  final DateTime updatedAt;
  final String serverUuid;

  SyncCursor copyWith({
    String? entityType,
    DateTime? updatedAt,
    String? serverUuid,
  }) {
    return SyncCursor(
      entityType: entityType ?? this.entityType,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUuid: serverUuid ?? this.serverUuid,
    );
  }

  @override
  String toString() {
    return 'SyncCursor('
        'entityType: $entityType, '
        'updatedAt: ${updatedAt.toUtc().toIso8601String()}, '
        'serverUuid: $serverUuid'
        ')';
  }
}
