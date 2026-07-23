class ChequeQueries {
  const ChequeQueries._();

  static const String createTable = '''
CREATE TABLE IF NOT EXISTS cheques (
  id INTEGER PRIMARY KEY AUTOINCREMENT,

  bank_account_id INTEGER NOT NULL,

  company_id INTEGER NOT NULL,

  receiver_name TEXT,

  cheque_number TEXT NOT NULL,

  amount_rial INTEGER NOT NULL CHECK (amount_rial > 0),

  issue_date TEXT NOT NULL,

  due_date TEXT NOT NULL CHECK (due_date >= issue_date),

  status TEXT NOT NULL CHECK (status IN ('Issued', 'Registered', 'Cancelled')),

  description TEXT,

  is_registered_in_sayad INTEGER NOT NULL DEFAULT 0,

  image_data BLOB,

  archived_at INTEGER,

  created_at INTEGER NOT NULL,

  updated_at INTEGER NOT NULL,

  FOREIGN KEY (bank_account_id)
    REFERENCES bank_accounts(id)
    ON DELETE RESTRICT,

  FOREIGN KEY (company_id)
    REFERENCES companies(id)
    ON DELETE RESTRICT
);
''';

  static const String createIndexes = '''
CREATE INDEX IF NOT EXISTS idx_cheques_bank_account_cheque_number
ON cheques(bank_account_id, cheque_number);

CREATE INDEX IF NOT EXISTS idx_cheques_issue_date_cheque_number
ON cheques(issue_date, cheque_number);

CREATE INDEX IF NOT EXISTS idx_cheques_company_id
ON cheques(company_id);

CREATE INDEX IF NOT EXISTS idx_cheques_bank_account_id
ON cheques(bank_account_id);

CREATE INDEX IF NOT EXISTS idx_cheques_status
ON cheques(status);

CREATE INDEX IF NOT EXISTS idx_cheques_archived_at
ON cheques(archived_at);

CREATE INDEX IF NOT EXISTS idx_cheques_due_date
ON cheques(due_date);
''';

  static const String insert = '''
INSERT INTO cheques (
  company_id,
  bank_account_id,
  cheque_number,
  amount_rial,
  issue_date,
  due_date,
  status,
  is_registered_in_sayad,
  receiver_name,
  description,
  image_data,
  archived_at,
  created_at,
  updated_at
) VALUES (
  :companyId,
  :bankAccountId,
  :chequeNumber,
  :amountRial,
  :issueDate,
  :dueDate,
  :status,
  :isRegisteredInSayad,
  :receiverName,
  :description,
  :imageData,
  :archivedAt,
  :createdAt,
  :updatedAt
);
''';

  static const String updateEditableById = '''
UPDATE cheques
SET
  cheque_number = :chequeNumber,
  amount_rial = :amountRial,
  issue_date = :issueDate,
  due_date = :dueDate,
  status = :status,
  is_registered_in_sayad = :isRegisteredInSayad,
  receiver_name = :receiverName,
  description = :description,
  image_data = :imageData,
  archived_at = :archivedAt,
  updated_at = :updatedAt
WHERE id = :id;
''';

  static const String findById = '''
SELECT
  c.id,
  c.company_id,
  c.bank_account_id,
  c.receiver_name,
  c.cheque_number,
  c.amount_rial,
  c.issue_date,
  c.due_date,
  c.status,
  c.description,
  c.is_registered_in_sayad,
  c.image_data,
  c.archived_at,
  c.created_at,
  c.updated_at,
  co.name AS company_name,
  ba.account_title AS bank_account_title
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE c.id = :id
LIMIT 1;
''';

  static const String findList = '''
SELECT
  c.id,
  c.company_id,
  c.bank_account_id,
  c.receiver_name,
  c.cheque_number,
  c.amount_rial,
  c.issue_date,
  c.due_date,
  c.status,
  c.description,
  c.is_registered_in_sayad,
  c.image_data,
  c.archived_at,
  c.created_at,
  c.updated_at,
  co.name AS company_name,
  ba.account_title AS bank_account_title
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE
  (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  )
  AND (:companyId IS NULL OR c.company_id = :companyId)
  AND (:bankAccountId IS NULL OR c.bank_account_id = :bankAccountId)
ORDER BY c.issue_date DESC, c.cheque_number DESC;
''';

  static const String findByCompanyId = '''
SELECT
  c.id,
  c.company_id,
  c.bank_account_id,
  c.receiver_name,
  c.cheque_number,
  c.amount_rial,
  c.issue_date,
  c.due_date,
  c.status,
  c.description,
  c.is_registered_in_sayad,
  c.image_data,
  c.archived_at,
  c.created_at,
  c.updated_at,
  co.name AS company_name,
  ba.account_title AS bank_account_title
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE
  c.company_id = :companyId
  AND (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  )
ORDER BY c.issue_date DESC, c.cheque_number DESC;
''';

  static const String findByBankAccountId = '''
SELECT
  c.id,
  c.company_id,
  c.bank_account_id,
  c.receiver_name,
  c.cheque_number,
  c.amount_rial,
  c.issue_date,
  c.due_date,
  c.status,
  c.description,
  c.is_registered_in_sayad,
  c.image_data,
  c.archived_at,
  c.created_at,
  c.updated_at,
  co.name AS company_name,
  ba.account_title AS bank_account_title
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE
  c.bank_account_id = :bankAccountId
  AND (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  )
ORDER BY c.issue_date DESC, c.cheque_number DESC;
''';

  static const String findDuplicatesByBankAccountAndChequeNumber = '''
SELECT
  c.id,
  c.company_id,
  c.bank_account_id,
  c.cheque_number,
  c.amount_rial,
  c.issue_date,
  c.due_date,
  c.status,
  c.is_registered_in_sayad,
  c.archived_at,
  c.created_at,
  c.updated_at,
  co.name AS company_name,
  ba.account_title AS bank_account_title
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE c.bank_account_id = :bankAccountId
  AND c.cheque_number = :chequeNumber
ORDER BY c.issue_date DESC, c.cheque_number DESC;
''';

  static const String findLatestChequeNumberByBankAccountId = '''
SELECT c.cheque_number
FROM cheques c
WHERE c.bank_account_id = :bankAccountId
ORDER BY c.issue_date DESC, c.created_at DESC, c.id DESC
LIMIT 1;
''';

  static const String countList = '''
SELECT COUNT(c.id) AS total
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
WHERE
  (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  )
  AND (:companyId IS NULL OR c.company_id = :companyId)
  AND (:bankAccountId IS NULL OR c.bank_account_id = :bankAccountId);
''';

  static const String countByCompanyId = '''
SELECT COUNT(c.id) AS total
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
WHERE
  c.company_id = :companyId
  AND (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  );
''';

  static const String countByBankAccountId = '''
SELECT COUNT(c.id) AS total
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
WHERE
  c.bank_account_id = :bankAccountId
  AND (:includeCancelled = 1 OR c.status != 'Cancelled')
  AND (:includeArchived = 1 OR c.archived_at IS NULL)
  AND (:fromDate IS NULL OR c.issue_date >= :fromDate)
  AND (:toDate IS NULL OR c.issue_date <= :toDate)
  AND (
    :search IS NULL
    OR :search = ''
    OR co.name LIKE '%' || :search || '%'
    OR c.cheque_number LIKE '%' || :search || '%'
  );
''';
}