class CompanyContactQueries {
  const CompanyContactQueries._();

  static const String createTable = '''
CREATE TABLE company_contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  company_id INTEGER NOT NULL,

  full_name TEXT NOT NULL,

  role TEXT NOT NULL,

  phone1 TEXT NOT NULL,

  phone2 TEXT,

  FOREIGN KEY (company_id)
    REFERENCES companies(id)
    ON DELETE RESTRICT
);
''';
}