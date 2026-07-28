import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqlite3/sqlite3.dart';

const String _sheetName = 'چک های صادر شده';

const Map<String, String> _bankAliasToTargetTitle = {
  'بانک رفاه': 'رفاه جاری',
  'تجارت ارسلان': 'تجارت جاری ارسلان',
  'آرمان': 'حساب سامان آدورا',
  'کارت آرمان': 'حساب سامان آدورا',
  'آرمان کارت': 'حساب سامان آدورا',
  'آدورا': 'حساب سامان آدورا',
  'سامان آدورا': 'حساب سامان آدورا',
};

Future<void> main(List<String> args) async {
  final excelPath = _readArg(args, '--excel');
  final dbArgPath = _readArg(args, '--db');
  final dryRun = _hasFlag(args, '--dry-run');

  if (excelPath == null || excelPath.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_cheques.dart --excel=<xlsx-path> [--db=<db-path>] [--dry-run]',
    );
    exitCode = 64;
    return;
  }

  final excelFile = File(excelPath);
  if (!excelFile.existsSync()) {
    stderr.writeln('Excel file not found: $excelPath');
    exitCode = 66;
    return;
  }

  final dbPath = await _resolveDbPath(dbArgPath);
  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    stderr.writeln('Database file not found: $dbPath');
    exitCode = 66;
    return;
  }

  final workbook = Excel.decodeBytes(excelFile.readAsBytesSync());
  final sheet = workbook.tables[_sheetName];

  if (sheet == null) {
    stderr.writeln('Sheet not found: $_sheetName');
    stderr.writeln('Available sheets: ${workbook.tables.keys.join(', ')}');
    exitCode = 65;
    return;
  }

  final analysisDb = sqlite3.open(dbPath);
  final report = _analyzeSheet(sheet, analysisDb);
  analysisDb.dispose();

  if (dryRun) {
    _printDryRunReport(report, dbPath);
    return;
  }

  final backupPath = await _backupDatabase(dbFile);
  final db = sqlite3.open(dbPath);

  try {
    report.backupPath = backupPath;
    report.deletedChequesCount = _deleteAllCheques(db);
    report.importedChequesCount = _importValidRows(db, report.validRows);
  } finally {
    db.dispose();
  }

  _printImportReport(report, dbPath);
}

Future<String> _resolveDbPath(String? dbArgPath) async {
  if (dbArgPath != null && dbArgPath.trim().isNotEmpty) {
    return p.normalize(dbArgPath.trim());
  }

  final candidates = <String>[
    p.join(Directory.current.path, 'pharmaflow.db'),
    p.join(Directory.current.path, 'data', 'pharmaflow.db'),
    p.join(_homeDir(), 'Documents', 'pharmaflow.db'),
    p.join(_homeDir(), 'pharmaflow.db'),
    p.join(_homeDir(), 'AppData', 'Roaming', 'pharmaflow.db'),
    p.join(_homeDir(), 'AppData', 'Local', 'pharmaflow.db'),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return p.normalize(candidate);
    }
  }

  return p.normalize(candidates.first);
}

String _homeDir() {
  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return home;
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    return userProfile;
  }

  return Directory.current.path;
}

String? _readArg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) {
      return arg.substring(key.length + 1).trim();
    }
  }

  return null;
}

bool _hasFlag(List<String> args, String flag) {
  return args.any((arg) => arg.trim() == flag);
}

Future<String> _backupDatabase(File dbFile) async {
  final now = DateTime.now();
  final stamp =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';

  final backupPath = p.join(dbFile.parent.path, 'pharmaflow_backup_$stamp.db');

  await dbFile.copy(backupPath);
  return backupPath;
}

int _deleteAllCheques(Database db) {
  final count = _countTable(db, 'cheques');
  db.execute('DELETE FROM cheques');
  return count;
}

int _importValidRows(Database db, List<_ChequeRowRecord> validRows) {
  if (validRows.isEmpty) {
    return 0;
  }

  final now = DateTime.now();
  final nowMillis = now.millisecondsSinceEpoch;

  final statement = db.prepare('''
		INSERT INTO cheques (
			company_id,
			bank_account_id,
			cheque_number,
			amount_rial,
			issue_date,
			due_date,
			status,
			is_registered_in_sayad,
			sayad_id,
			receiver_name,
			description,
			image_data,
			archived_at,
			created_at,
			updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	''');

  db.execute('BEGIN TRANSACTION');

  var imported = 0;

  try {
    for (final row in validRows) {
      statement.execute([
        row.companyId,
        row.bankAccountId,
        row.chequeNumber,
        row.amountRial,
        row.issueDate.millisecondsSinceEpoch,
        row.dueDate.millisecondsSinceEpoch,
        row.isRegisteredInSayad ? 'Registered' : 'Issued',
        row.isRegisteredInSayad ? 1 : 0,
        null,
        null,
        row.description,
        null,
        null,
        nowMillis,
        nowMillis,
      ]);

      imported++;
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.dispose();
  }

  return imported;
}

_ChequeImportReport _analyzeSheet(Sheet sheet, Database db) {
  final report = _ChequeImportReport();

  final headerRowIndex = _findHeaderRowIndex(sheet);
  if (headerRowIndex == null) {
    throw StateError('Could not find header row for sheet: $_sheetName');
  }

  final headerMap = _buildHeaderMap(sheet.rows[headerRowIndex]);

  final idxChequeNumber = headerMap['شمارهچک'];
  final idxAmountRial = headerMap['مبلغچک'];
  final idxIssueDate = headerMap['تاریخصدور'];
  final idxDueDate = headerMap['تاریخسررسید'];
  final idxCompanyName = headerMap['نامطرفحساب'];
  final idxBankAccount = headerMap['حساببانکی'];
  final idxSayad = headerMap['ثبتشده'];

  final requiredIndexes = [
    idxChequeNumber,
    idxAmountRial,
    idxIssueDate,
    idxDueDate,
    idxCompanyName,
    idxBankAccount,
    idxSayad,
  ];

  if (requiredIndexes.any((value) => value == null)) {
    throw StateError(
      'One or more required columns were not found in $_sheetName',
    );
  }

  final companyLookup = _loadCompanyLookup(db);
  final bankLookup = _loadBankLookup(db);

  for (
    var rowIndex = headerRowIndex + 1;
    rowIndex < sheet.rows.length;
    rowIndex++
  ) {
    final row = sheet.rows[rowIndex];
    if (!_rowHasData(row)) {
      continue;
    }

    report.totalRows++;

    final rawChequeNumber = _cleanText(_cellText(row, idxChequeNumber));
    final rawAmount = _cleanText(_cellText(row, idxAmountRial));
    final rawIssueDate = _cleanText(_cellText(row, idxIssueDate));
    final rawDueDate = _cleanText(_cellText(row, idxDueDate));
    final rawCompanyName = _cleanText(_cellText(row, idxCompanyName));
    final rawBankAccountValue = _cellText(row, idxBankAccount);
    final rawBankAccount = _cleanText(_cellText(row, idxBankAccount));
    final rawSayad = _cleanText(_cellText(row, idxSayad));

    final companyId = _lookupCompanyId(rawCompanyName, companyLookup);
    if (companyId != null) {
      report.matchedCompaniesCount++;
    } else if (rawCompanyName.isNotEmpty) {
      report.unmatchedCompanies.add(rawCompanyName);
    }

    final bankResolution = _resolveBankAccount(rawBankAccount, bankLookup);
    if (bankResolution != null) {
      report.matchedBankAccountsCount++;
      if (bankResolution.aliasUsed != null) {
        report.bankMappingStats[bankResolution.aliasUsed!] =
            (report.bankMappingStats[bankResolution.aliasUsed!] ?? 0) + 1;
      }
    } else if (rawBankAccount.isNotEmpty) {
      report.unmatchedBankAccounts.add(rawBankAccount);
    }

    if (rawBankAccountValue.trim().isNotEmpty) {
      report.rawBankAccountValues[rawBankAccountValue] =
          (report.rawBankAccountValues[rawBankAccountValue] ?? 0) + 1;
    }

    final isArmanAccount = _isArmanBankAccount(bankResolution?.accountTitle);
    final chequeNumberParts = isArmanAccount
        ? _splitChequeNumberParts(rawChequeNumber)
        : _ChequeNumberParts(first: rawChequeNumber);
    final chequeNumber = _parseChequeNumber(chequeNumberParts.first);
    var amountRial = _parseAmountRial(rawAmount);
    var issueDate = _parseJalaliDate(rawIssueDate);
    final dueDate = _parseJalaliDate(rawDueDate);
    final sayadRegistered = _parseSayadRegistered(rawSayad);
    final description = isArmanAccount ? chequeNumberParts.description : null;

    if (sayadRegistered == true) {
      report.sayadRegisteredCount++;
    } else if (sayadRegistered == false) {
      report.sayadUnregisteredCount++;
    }

    final reasons = <String>[];

    if (companyId == null) {
      reasons.add('company not found');
    }

    if (bankResolution == null) {
      reasons.add('bank account not found');
    }

    if (chequeNumber == null) {
      reasons.add('invalid cheque number');
    }

    if (amountRial == 0) {
      amountRial = 1;
      report.correctedZeroAmountCount++;
    }

    if (amountRial == null || amountRial <= 0) {
      reasons.add('invalid amount');
    }

    if (issueDate == null) {
      reasons.add('invalid issue date');
    }

    if (dueDate == null) {
      reasons.add('invalid due date');
    }

    if (sayadRegistered == null) {
      reasons.add('invalid sayad status');
    }

    final issueDateForComparison = _parseGregorianDateForComparison(
      rawIssueDate,
    );
    final dueDateForComparison = _parseJalaliDate(rawDueDate);

    if (issueDateForComparison != null &&
        dueDateForComparison != null &&
        _dateOnly(
          dueDateForComparison,
        ).isBefore(_dateOnly(issueDateForComparison))) {
      issueDate = _dateOnly(
        dueDateForComparison,
      ).subtract(const Duration(days: 90));
      report.correctedIssueDateCount++;
    }

    if (reasons.isEmpty) {
      report.validRows.add(
        _ChequeRowRecord(
          rowNumber: rowIndex + 1,
          companyId: companyId!,
          bankAccountId: bankResolution!.id,
          chequeNumber: chequeNumber!,
          amountRial: amountRial!,
          issueDate: issueDate!,
          dueDate: dueDate!,
          isRegisteredInSayad: sayadRegistered!,
          description: description,
        ),
      );
    } else {
      report.invalidRowsCount++;
      if (report.invalidRowDiagnostics.length < 20) {
        report.invalidRowDiagnostics.add(
          _InvalidRowDiagnostic(
            rowNumber: rowIndex + 1,
            chequeNumber: rawChequeNumber,
            amount: rawAmount,
            issueDateRawValue: _cellText(row, idxIssueDate),
            dueDateRawValue: _cellText(row, idxDueDate),
            companyName: _cellText(row, idxCompanyName),
            bankAccount: _cellText(row, idxBankAccount),
            sayadRawValue: _cellText(row, idxSayad),
            validationErrors: List<String>.unmodifiable(reasons),
          ),
        );
      }
      report.invalidRowDetails.add(
        'Row ${rowIndex + 1}: ${reasons.join(', ')}',
      );
    }
  }

  report.headerRowIndex = headerRowIndex + 1;
  return report;
}

void _printDryRunReport(_ChequeImportReport report, String dbPath) {
  stdout.writeln('--- PharmaFlow Cheque Import Dry Run ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Header row index: ${report.headerRowIndex}');
  stdout.writeln('Total cheque rows: ${report.totalRows}');
  stdout.writeln('Matched companies count: ${report.matchedCompaniesCount}');
  stdout.writeln(
    'Unmatched companies list (${report.unmatchedCompanies.length}):',
  );

  if (report.unmatchedCompanies.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final company in report.unmatchedCompanies.toList()..sort()) {
      stdout.writeln(' - $company');
    }
  }

  stdout.writeln(
    'Matched bank accounts count: ${report.matchedBankAccountsCount}',
  );
  stdout.writeln(
    'Unmatched bank account values before mapping (${report.unmatchedBankAccounts.length}):',
  );

  if (report.unmatchedBankAccounts.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final value in report.unmatchedBankAccounts.toList()..sort()) {
      stdout.writeln(' - $value');
    }
  }

  stdout.writeln('حساب بانکی values (${report.rawBankAccountValues.length}):');
  if (report.rawBankAccountValues.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final entry in report.rawBankAccountValues.entries.toList()) {
      stdout.writeln(' - ${entry.key}: ${entry.value}');
    }
  }

  stdout.writeln('Bank mapping statistics:');
  for (final entry in _bankAliasToTargetTitle.entries) {
    stdout.writeln(
      ' - ${entry.key} -> ${entry.value}: ${report.bankMappingStats[entry.key] ?? 0}',
    );
  }

  stdout.writeln('Sayad registered count: ${report.sayadRegisteredCount}');
  stdout.writeln('Sayad unregistered count: ${report.sayadUnregisteredCount}');
  stdout.writeln(
    'Corrected issueDate count: ${report.correctedIssueDateCount}',
  );
  stdout.writeln(
    'Corrected zero amount count: ${report.correctedZeroAmountCount}',
  );
  stdout.writeln('Invalid rows count: ${report.invalidRowsCount}');

  stdout.writeln('Invalid row details (first 20):');
  if (report.invalidRowDiagnostics.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final diagnostic in report.invalidRowDiagnostics) {
      stdout.writeln(' - Excel row number: ${diagnostic.rowNumber}');
      stdout.writeln('   cheque number: ${diagnostic.chequeNumber}');
      stdout.writeln('   amount: ${diagnostic.amount}');
      stdout.writeln(
        '   issue date raw value: ${diagnostic.issueDateRawValue}',
      );
      stdout.writeln('   due date raw value: ${diagnostic.dueDateRawValue}');
      stdout.writeln('   company name: ${diagnostic.companyName}');
      stdout.writeln('   bank account: ${diagnostic.bankAccount}');
      stdout.writeln(
        '   sayad registration raw value: ${diagnostic.sayadRawValue}',
      );
      stdout.writeln(
        '   validation errors list: ${diagnostic.validationErrors.join(', ')}',
      );
    }
  }
}

void _printImportReport(_ChequeImportReport report, String dbPath) {
  stdout.writeln('--- PharmaFlow Cheque Import Report ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Backup path: ${report.backupPath}');
  stdout.writeln('Deleted cheque count: ${report.deletedChequesCount}');
  stdout.writeln('Imported cheque count: ${report.importedChequesCount}');
  stdout.writeln('Invalid rows count: ${report.invalidRowsCount}');
}

Map<String, int> _loadCompanyLookup(Database db) {
  final rows = db.select('SELECT id, name FROM companies');
  final lookup = <String, int>{};

  for (final row in rows) {
    final name = _cleanText(row['name']?.toString() ?? '');
    if (name.isNotEmpty) {
      lookup[_normalizeLookupKey(name)] = row['id'] as int;
    }
  }

  return lookup;
}

_BankLookup _loadBankLookup(Database db) {
  final rows = db.select(
    'SELECT id, bank_name, account_title FROM bank_accounts',
  );
  final titleLookup = <String, List<_BankAccountInfo>>{};
  final bankNameLookup = <String, List<_BankAccountInfo>>{};

  for (final row in rows) {
    final info = _BankAccountInfo(
      id: row['id'] as int,
      bankName: _cleanText(row['bank_name']?.toString() ?? ''),
      accountTitle: _cleanText(row['account_title']?.toString() ?? ''),
    );

    final titleKey = _normalizeLookupKey(info.accountTitle);
    if (titleKey.isNotEmpty) {
      titleLookup.putIfAbsent(titleKey, () => <_BankAccountInfo>[]).add(info);
    }

    final bankNameKey = _normalizeLookupKey(info.bankName);
    if (bankNameKey.isNotEmpty) {
      bankNameLookup
          .putIfAbsent(bankNameKey, () => <_BankAccountInfo>[])
          .add(info);
    }
  }

  return _BankLookup(titleLookup: titleLookup, bankNameLookup: bankNameLookup);
}

int? _lookupCompanyId(String rawCompanyName, Map<String, int> companyLookup) {
  if (rawCompanyName.isEmpty) {
    return null;
  }

  return companyLookup[_normalizeLookupKey(rawCompanyName)];
}

_BankResolution? _resolveBankAccount(String rawBankValue, _BankLookup lookup) {
  if (rawBankValue.isEmpty) {
    return null;
  }

  final normalizedRaw = _normalizeLookupKey(rawBankValue);
  if (normalizedRaw.isEmpty) {
    return null;
  }

  final aliasTarget =
      _bankAliasToTargetTitle[rawBankValue] ??
      _bankAliasToTargetTitle[_denormalizeForAliasLookup(rawBankValue)];
  if (aliasTarget != null) {
    final byTitle = lookup.titleLookup[_normalizeLookupKey(aliasTarget)];
    if (byTitle != null && byTitle.isNotEmpty) {
      return _BankResolution(
        id: byTitle.first.id,
        accountTitle: byTitle.first.accountTitle,
        aliasUsed: rawBankValue,
      );
    }
  }

  final directTitle = lookup.titleLookup[normalizedRaw];
  if (directTitle != null && directTitle.isNotEmpty) {
    return _BankResolution(
      id: directTitle.first.id,
      accountTitle: directTitle.first.accountTitle,
    );
  }

  final byBankName = lookup.bankNameLookup[normalizedRaw];
  if (byBankName != null && byBankName.length == 1) {
    return _BankResolution(
      id: byBankName.first.id,
      accountTitle: byBankName.first.accountTitle,
    );
  }

  return null;
}

String _denormalizeForAliasLookup(String value) {
  return _cleanText(value);
}

bool _isArmanBankAccount(String? accountTitle) {
  if (accountTitle == null || accountTitle.trim().isEmpty) {
    return false;
  }

  return _normalizeLookupKey(accountTitle) ==
      _normalizeLookupKey('حساب سامان آدورا');
}

_ChequeNumberParts _splitChequeNumberParts(String rawChequeNumber) {
  final parts = rawChequeNumber
      .split(RegExp(r'\s*[\-,،و]\s*'))
      .map(_cleanText)
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return const _ChequeNumberParts(first: '');
  }

  if (parts.length == 1) {
    return _ChequeNumberParts(first: parts.first);
  }

  return _ChequeNumberParts(
    first: parts.first,
    description: 'شماره فاکتورهای مرتبط: ${parts.skip(1).join('، ')}',
  );
}

int? _parseChequeNumber(String value) {
  final digits = _toEnglishDigits(value).replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    return null;
  }

  return int.tryParse(digits);
}

int? _parseAmountRial(String value) {
  final normalized = _toEnglishDigits(value).replaceAll(RegExp(r'[^0-9.]'), '');
  if (normalized.isEmpty) {
    return null;
  }

  final parsed = num.tryParse(normalized.replaceAll(',', ''));
  if (parsed == null) {
    return null;
  }

  return parsed.toInt();
}

DateTime? _parseJalaliDate(String value) {
  final normalized = _toEnglishDigits(value).trim();
  if (normalized.isEmpty) {
    return null;
  }

  final jalaliMatch = RegExp(
    r'^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$',
  ).firstMatch(normalized);
  if (jalaliMatch != null) {
    final year = int.tryParse(jalaliMatch.group(1)!);
    final month = int.tryParse(jalaliMatch.group(2)!);
    final day = int.tryParse(jalaliMatch.group(3)!);

    if (year != null && month != null && day != null) {
      return Jalali(year, month, day).toDateTime();
    }
  }

  final iso = DateTime.tryParse(normalized);
  if (iso != null) {
    return iso;
  }

  return null;
}

DateTime? _parseGregorianDateForComparison(String value) {
  final normalized = _toEnglishDigits(value).trim();
  if (normalized.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})',
  ).firstMatch(normalized);
  if (match != null) {
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);

    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  return DateTime.tryParse(normalized);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool? _parseSayadRegistered(String value) {
  final normalized = _normalizeLookupKey(value);
  if (normalized.isEmpty) {
    return false;
  }

  const falseValues = <String>{'n', 'no', 'false', '0', 'خیر', 'نشده', 'خالی'};

  if (falseValues.contains(normalized)) {
    return false;
  }

  const trueValues = <String>{'y', 'yes', 'true', '1', 'بله', 'ثبتشده'};

  if (trueValues.contains(normalized)) {
    return true;
  }

  return null;
}

bool _rowHasData(List<dynamic> row) {
  for (final cell in row) {
    final value = cell?.value;
    if (value != null && value.toString().trim().isNotEmpty) {
      return true;
    }
  }

  return false;
}

int? _findHeaderRowIndex(Sheet sheet) {
  for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
    final headerMap = _buildHeaderMap(sheet.rows[rowIndex]);
    if (headerMap.containsKey('شمارهچک')) {
      return rowIndex;
    }
  }

  return null;
}

Map<String, int> _buildHeaderMap(List<dynamic> row) {
  final map = <String, int>{};

  for (var i = 0; i < row.length; i++) {
    final text = _normalizeLookupKey(_cellValueToString(row[i]));
    if (text.isNotEmpty) {
      map[text] = i;
    }
  }

  return map;
}

String _cellText(List<dynamic> row, int? index) {
  if (index == null || index < 0 || index >= row.length) {
    return '';
  }

  return _cellValueToString(row[index]);
}

String _cellValueToString(dynamic cell) {
  final value = cell?.value;
  if (value == null) {
    return '';
  }

  return value.toString();
}

String _cleanText(String input) {
  return _toEnglishDigits(input)
      .replaceAll('\u200c', ' ')
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeLookupKey(String input) {
  return _cleanText(
    input,
  ).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
}

String _toEnglishDigits(String value) {
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(arabicIndic[i], i.toString());
    result = result.replaceAll(persian[i], i.toString());
  }

  return result;
}

int _countTable(Database db, String tableName) {
  final result = db.select('SELECT COUNT(*) AS total FROM $tableName');
  return result.first['total'] as int;
}

class _ChequeImportReport {
  int headerRowIndex = 0;
  int totalRows = 0;
  int matchedCompaniesCount = 0;
  final Set<String> unmatchedCompanies = <String>{};
  int matchedBankAccountsCount = 0;
  final Set<String> unmatchedBankAccounts = <String>{};
  final Map<String, int> rawBankAccountValues = <String, int>{};
  final Map<String, int> bankMappingStats = {
    for (final alias in _bankAliasToTargetTitle.keys) alias: 0,
  };
  int sayadRegisteredCount = 0;
  int sayadUnregisteredCount = 0;
  int correctedIssueDateCount = 0;
  int correctedZeroAmountCount = 0;
  int invalidRowsCount = 0;
  final List<String> invalidRowDetails = <String>[];
  final List<_InvalidRowDiagnostic> invalidRowDiagnostics =
      <_InvalidRowDiagnostic>[];
  final List<_ChequeRowRecord> validRows = <_ChequeRowRecord>[];
  String? backupPath;
  int deletedChequesCount = 0;
  int importedChequesCount = 0;
}

class _ChequeRowRecord {
  const _ChequeRowRecord({
    required this.rowNumber,
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amountRial,
    required this.issueDate,
    required this.dueDate,
    required this.isRegisteredInSayad,
    required this.description,
  });

  final int rowNumber;
  final int companyId;
  final int bankAccountId;
  final int chequeNumber;
  final int amountRial;
  final DateTime issueDate;
  final DateTime dueDate;
  final bool isRegisteredInSayad;
  final String? description;
}

class _BankAccountInfo {
  const _BankAccountInfo({
    required this.id,
    required this.bankName,
    required this.accountTitle,
  });

  final int id;
  final String bankName;
  final String accountTitle;
}

class _BankLookup {
  const _BankLookup({required this.titleLookup, required this.bankNameLookup});

  final Map<String, List<_BankAccountInfo>> titleLookup;
  final Map<String, List<_BankAccountInfo>> bankNameLookup;
}

class _BankResolution {
  const _BankResolution({
    required this.id,
    required this.accountTitle,
    this.aliasUsed,
  });

  final int id;
  final String accountTitle;
  final String? aliasUsed;
}

class _ChequeNumberParts {
  const _ChequeNumberParts({required this.first, this.description});

  final String first;
  final String? description;
}

class _InvalidRowDiagnostic {
  const _InvalidRowDiagnostic({
    required this.rowNumber,
    required this.chequeNumber,
    required this.amount,
    required this.issueDateRawValue,
    required this.dueDateRawValue,
    required this.companyName,
    required this.bankAccount,
    required this.sayadRawValue,
    required this.validationErrors,
  });

  final int rowNumber;
  final String chequeNumber;
  final String amount;
  final String issueDateRawValue;
  final String dueDateRawValue;
  final String companyName;
  final String bankAccount;
  final String sayadRawValue;
  final List<String> validationErrors;
}
