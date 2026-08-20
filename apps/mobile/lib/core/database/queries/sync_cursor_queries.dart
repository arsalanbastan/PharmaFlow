class SyncCursorQueries {
  const SyncCursorQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS sync_cursors (
  entity_type TEXT PRIMARY KEY,
  updated_at INTEGER NOT NULL,
  server_uuid TEXT NOT NULL
);
''';

  static const String findByEntityType = '''
SELECT
  entity_type,
  updated_at,
  server_uuid
FROM sync_cursors
WHERE entity_type = ?
LIMIT 1;
''';

  static const String upsert = '''
INSERT INTO sync_cursors (
  entity_type,
  updated_at,
  server_uuid
)
VALUES (?, ?, ?)
ON CONFLICT(entity_type) DO UPDATE SET
  updated_at = excluded.updated_at,
  server_uuid = excluded.server_uuid;
''';
}
