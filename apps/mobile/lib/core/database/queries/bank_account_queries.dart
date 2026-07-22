class BankAccountQueries {
  const BankAccountQueries._();

  static const String createTable = '''
  CREATE TABLE IF NOT EXISTS bank_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    bank_name TEXT NOT NULL,

    account_title TEXT NOT NULL,

    account_holder TEXT NOT NULL,

    account_number TEXT NOT NULL,

    card_number TEXT NOT NULL,

    iban TEXT NOT NULL,

    note TEXT,

    archived_at INTEGER,

    created_at INTEGER NOT NULL,

    updated_at INTEGER NOT NULL
  );
  ''';

  static const String createIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_bank_account_name
  ON bank_accounts(account_title);
  ''';
}