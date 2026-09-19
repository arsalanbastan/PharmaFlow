class CashPaymentAttachmentQueries {
  const CashPaymentAttachmentQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS cash_payment_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  server_uuid TEXT NOT NULL UNIQUE,

  cash_payment_id INTEGER NOT NULL,

  kind TEXT NOT NULL
    CHECK(kind IN ('RECEIPT', 'STATEMENT')),

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

  FOREIGN KEY(cash_payment_id)
    REFERENCES cash_payments(id)
    ON DELETE RESTRICT
);
''';

  static const String createIndexes = '''
CREATE INDEX IF NOT EXISTS
  idx_cash_payment_attachments_payment
ON cash_payment_attachments(
  cash_payment_id,
  created_at
);

CREATE INDEX IF NOT EXISTS
  idx_cash_payment_attachments_payment_kind
ON cash_payment_attachments(
  cash_payment_id,
  kind
);

CREATE INDEX IF NOT EXISTS
  idx_cash_payment_attachments_updated
ON cash_payment_attachments(
  updated_at,
  id
);

CREATE UNIQUE INDEX IF NOT EXISTS
  idx_cash_payment_attachments_storage_key
ON cash_payment_attachments(storage_key)
WHERE storage_key IS NOT NULL;
''';
}
