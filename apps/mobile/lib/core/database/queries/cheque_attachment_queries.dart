class ChequeAttachmentQueries {
  const ChequeAttachmentQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS cheque_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  server_uuid TEXT NOT NULL UNIQUE,

  cheque_id INTEGER NOT NULL,

  kind TEXT NOT NULL
    CHECK(kind = 'STATEMENT'),

  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,

  original_file_size INTEGER,
  file_size INTEGER NOT NULL,

  sha256 TEXT NOT NULL,

  local_path TEXT,
  storage_key TEXT,

  delete_requested_at INTEGER,
  deleted_at INTEGER,

  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,

  FOREIGN KEY(cheque_id)
    REFERENCES cheques(id)
    ON DELETE RESTRICT
);
''';

  static const String createIndexes = '''
CREATE INDEX IF NOT EXISTS
  idx_cheque_attachments_cheque
ON cheque_attachments(
  cheque_id,
  created_at
);

CREATE INDEX IF NOT EXISTS
  idx_cheque_attachments_cheque_kind
ON cheque_attachments(
  cheque_id,
  kind
);

CREATE INDEX IF NOT EXISTS
  idx_cheque_attachments_updated
ON cheque_attachments(
  updated_at,
  id
);

CREATE UNIQUE INDEX IF NOT EXISTS
  idx_cheque_attachments_storage_key
ON cheque_attachments(storage_key)
WHERE storage_key IS NOT NULL;
''';
}
