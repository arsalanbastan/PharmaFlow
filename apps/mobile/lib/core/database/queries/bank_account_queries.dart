class BankAccountQueries {
  const BankAccountQueries._();

  static const String createTable = '''
CREATE TABLE bank_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  account_title TEXT NOT NULL,

  bank_name TEXT NOT NULL,

  bank_logo TEXT,

  account_number TEXT NOT NULL,

  card_number TEXT NOT NULL,

  iban TEXT NOT NULL,

  has_cheque_book INTEGER NOT NULL DEFAULT 0,

  is_active INTEGER NOT NULL DEFAULT 1,

  created_at TEXT NOT NULL,

  updated_at TEXT NOT NULL
);
''';
}