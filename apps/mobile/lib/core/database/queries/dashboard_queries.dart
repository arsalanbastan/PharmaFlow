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
  c.due_date,
  COUNT(c.id) AS commitment_count,
  SUM(c.amount_rial) AS total_amount
FROM cheques c
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
GROUP BY
  c.due_date
ORDER BY
  c.due_date;
''';


  /// شرکت‌ها و چک‌های یک روز
  static const String commitmentCompanies = '''
SELECT
  c.company_id,
  c.amount_rial,
  c.cheque_number
FROM cheques c
WHERE
  c.due_date >= ?
  AND c.due_date < ?
  AND c.status != 'cancelled'
  AND c.archived_at IS NULL
ORDER BY
  c.amount_rial DESC;
''';
}