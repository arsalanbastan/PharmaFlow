class CompanyQueries {
  const CompanyQueries._();

  static const String createTable = '''
CREATE TABLE companies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  server_uuid TEXT,

  name TEXT NOT NULL UNIQUE,

  national_id TEXT,

  economic_code TEXT,

  bank_name TEXT,
  account_number TEXT,
  card_number TEXT,
  sheba_number TEXT,

  notes TEXT,

  visitor_name TEXT,
  visitor_phone TEXT,
  accountant_name TEXT,
  accountant_phone TEXT,

  archived_at INTEGER,

  created_at INTEGER NOT NULL,

  updated_at INTEGER NOT NULL
);
''';

  static const String createIndexes = '''
CREATE INDEX idx_company_name
ON companies(name);
''';
}
