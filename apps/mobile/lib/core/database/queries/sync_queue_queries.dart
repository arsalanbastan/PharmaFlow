class SyncQueueQueries {
  const SyncQueueQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  entityType TEXT NOT NULL,

  entityId INTEGER NOT NULL,

  operation TEXT NOT NULL,

  status TEXT NOT NULL,

  retryCount INTEGER NOT NULL DEFAULT 0,

  createdAt INTEGER NOT NULL,

  lastAttemptAt INTEGER,

  errorMessage TEXT
);
''';

  static const String createIndexes = '''
CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created_at
ON sync_queue(status, createdAt);

CREATE INDEX IF NOT EXISTS idx_sync_queue_entity
ON sync_queue(entityType, entityId);
''';

  static const String insert = '''
INSERT INTO sync_queue (
  entityType,
  entityId,
  operation,
  status,
  retryCount,
  createdAt,
  lastAttemptAt,
  errorMessage
) VALUES (
  :entityType,
  :entityId,
  :operation,
  :status,
  :retryCount,
  :createdAt,
  :lastAttemptAt,
  :errorMessage
);
''';

  static const String findPending = '''
SELECT *
FROM sync_queue
WHERE status = :status
ORDER BY createdAt ASC, id ASC;
''';

  static const String markSynced = '''
UPDATE sync_queue
SET
  status = :status,
  lastAttemptAt = :lastAttemptAt,
  errorMessage = NULL
WHERE id = :id;
''';

  static const String markFailed = '''
UPDATE sync_queue
SET
  status = :status,
  retryCount = retryCount + 1,
  lastAttemptAt = :lastAttemptAt,
  errorMessage = :errorMessage
WHERE id = :id;
''';
}
