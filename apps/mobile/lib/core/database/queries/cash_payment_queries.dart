class CashPaymentQueries {
  const CashPaymentQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS cash_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  server_uuid TEXT,

  amount_rial INTEGER NOT NULL
    CHECK (amount_rial > 0),

  payment_date INTEGER NOT NULL,

  company_id INTEGER NOT NULL,

  bank_account_id INTEGER NOT NULL,

  payment_method TEXT NOT NULL
    CHECK (
      payment_method IN (
        'BANK_DEPOSIT',
        'POS_PAYMENT'
      )
    ),

  tracking_number TEXT,

  description TEXT,

  notes TEXT,

  archived_at INTEGER,

  delete_requested_at INTEGER,

  deleted_at INTEGER,

  created_at INTEGER NOT NULL,

  updated_at INTEGER NOT NULL,

  FOREIGN KEY (company_id)
    REFERENCES companies(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  FOREIGN KEY (bank_account_id)
    REFERENCES bank_accounts(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);
''';

  static const String createIndexes = '''
CREATE UNIQUE INDEX IF NOT EXISTS
idx_cash_payments_server_uuid
ON cash_payments(server_uuid)
WHERE server_uuid IS NOT NULL;

CREATE INDEX IF NOT EXISTS
idx_cash_payments_company_payment_date
ON cash_payments(company_id, payment_date);

CREATE INDEX IF NOT EXISTS
idx_cash_payments_bank_payment_date
ON cash_payments(bank_account_id, payment_date);

CREATE INDEX IF NOT EXISTS
idx_cash_payments_payment_date
ON cash_payments(payment_date);

CREATE INDEX IF NOT EXISTS
idx_cash_payments_updated_at_id
ON cash_payments(updated_at, id);

CREATE INDEX IF NOT EXISTS
idx_cash_payments_delete_requested_at
ON cash_payments(delete_requested_at);
''';
}
