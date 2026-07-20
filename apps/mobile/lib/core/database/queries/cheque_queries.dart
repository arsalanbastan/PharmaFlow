class ChequeQueries {
  const ChequeQueries._();

  static const String createTable = '''
CREATE TABLE cheques (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  bank_account_id INTEGER NOT NULL,

  company_id INTEGER,

  receiver_name TEXT,

  cheque_number TEXT NOT NULL,

  amount INTEGER NOT NULL,

  issue_date TEXT NOT NULL,

  due_date TEXT NOT NULL,

  description TEXT,

  is_registered_in_sayad INTEGER NOT NULL DEFAULT 0,

  cheque_image_path TEXT,

  created_at TEXT NOT NULL,

  updated_at TEXT NOT NULL,

  FOREIGN KEY (bank_account_id)
    REFERENCES bank_accounts(id)
    ON DELETE RESTRICT,

  FOREIGN KEY (company_id)
    REFERENCES companies(id)
    ON DELETE RESTRICT
);
''';
}