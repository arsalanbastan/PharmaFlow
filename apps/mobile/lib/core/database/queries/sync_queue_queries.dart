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

  static const String findProcessable = '''
SELECT *
FROM sync_queue
WHERE status IN (:pendingStatus, :failedStatus)
ORDER BY createdAt ASC, id ASC;
''';

  static const String findFailedNewest = '''
SELECT *
FROM sync_queue
WHERE status = :status
ORDER BY createdAt DESC, id DESC;
''';

  static const String findAllNewest = '''
SELECT *
FROM sync_queue
ORDER BY createdAt DESC, id DESC;
''';

  static const String findById = '''
SELECT *
FROM sync_queue
WHERE id = :id
LIMIT 1;
''';

  static const String markProcessing = '''
UPDATE sync_queue
SET
  status = :status,
  lastAttemptAt = :lastAttemptAt,
  errorMessage = NULL
WHERE id = :id;
''';

  static const String resetProcessingToPending = '''
UPDATE sync_queue
SET
  status = :pendingStatus
WHERE status = :processingStatus;
''';

  static const String countByStatus = '''
SELECT COUNT(*) AS total
FROM sync_queue
WHERE status = :status;
''';

  static const String countAll = '''
SELECT COUNT(*) AS total
FROM sync_queue;
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

  static const String retryById = '''
UPDATE sync_queue
SET
  status = :status,
  lastAttemptAt = NULL,
  errorMessage = NULL
WHERE id = :id;
''';

  static const String deleteById = '''
DELETE FROM sync_queue
WHERE id = :id;
''';

  static const String findLatestActiveByEntity = '''
SELECT *
FROM sync_queue
WHERE entityType = :entityType
  AND entityId = :entityId
  AND status IN (:pendingStatus, :failedStatus, :processingStatus)
ORDER BY createdAt DESC, id DESC
LIMIT 1;
''';

  static const String requeueExistingUpdate = '''
UPDATE sync_queue
SET
  status = :status,
  lastAttemptAt = NULL,
  errorMessage = NULL
WHERE id = :id;
''';
}
