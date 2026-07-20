class CompanyQueries {
  const CompanyQueries._();

  static const String createTable = '''
CREATE TABLE companies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  name TEXT NOT NULL UNIQUE,

  national_id TEXT,

  economic_code TEXT,

  notes TEXT,

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