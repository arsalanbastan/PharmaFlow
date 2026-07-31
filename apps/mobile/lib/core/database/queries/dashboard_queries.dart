class DashboardQueries {
  const DashboardQueries._();

  /// تعهدات فردا به تفکیک حساب بانکی
  static const String tomorrowCommitments = '''
SELECT
  ba.id AS bank_account_id,
  ba.account_title AS bank_account_title,
  SUM(c.amount_rial) AS total_amount
FROM cheques c
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
GROUP BY
  ba.id,
  ba.account_title
ORDER BY
  total_amount DESC;
''';

  /// خلاصه یک بازه زمانی (دوره)
  static const String commitmentPeriodSummary = '''
SELECT
  COUNT(c.id) AS commitment_count,
  COALESCE(SUM(c.amount_rial), 0) AS total_amount
FROM cheques c
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL;
''';

  /// روزهای دارای تعهد در یک دوره
  static const String commitmentDays = '''
SELECT
  (
    CAST(
      strftime(
        '%s',
        datetime(c.due_date / 1000, 'unixepoch', 'localtime', 'start of day', 'utc')
      ) AS INTEGER
    ) * 1000
  ) AS day_start,
  COUNT(c.id) AS commitment_count,
  COALESCE(SUM(c.amount_rial), 0) AS total_amount
FROM cheques c
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
GROUP BY
  day_start
ORDER BY
  day_start;
''';

  /// شرکت‌ها و چک‌های یک روز
  static const String commitmentCompanies = '''
SELECT
  c.company_id,
  co.name AS company_name,
  ba.account_title AS bank_account_title,
  c.amount_rial,
  c.cheque_number
FROM cheques c
INNER JOIN companies co
  ON co.id = c.company_id
INNER JOIN bank_accounts ba
  ON ba.id = c.bank_account_id
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
ORDER BY
  co.name,
  c.amount_rial DESC;
''';

  /// چک‌های ثبت نشده در صیاد
  static const String unregisteredCheques = '''
SELECT
  c.*
FROM cheques c
WHERE
  c.is_registered_in_sayad = 0
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
ORDER BY
  c.issue_date DESC,
  c.created_at DESC;
''';
}
