import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String _sheetName = 'شرکت های پخش';
const String _fallbackCompanyName = 'ارغوان کالای جنوب';

Future<void> main(List<String> args) async {
  final excelPath = _readArg(args, '--excel');
  final dbArgPath = _readArg(args, '--db');
  final dryRun = _hasFlag(args, '--dry-run');
  final verify = _hasFlag(args, '--verify');
  final clearCheques = _hasFlag(args, '--clear-cheques');

  final dbPath = await _resolveDbPath(dbArgPath);

  if (clearCheques) {
    if (dbArgPath == null || dbArgPath.trim().isEmpty) {
      stderr.writeln('For --clear-cheques, please provide --db=<db-path>.');
      exitCode = 64;
      return;
    }

    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      stderr.writeln('Database file not found: $dbPath');
      exitCode = 66;
      return;
    }

    _clearChequesOnly(dbPath);
    return;
  }

  if (verify) {
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      stderr.writeln('Database file not found: $dbPath');
      exitCode = 66;
      return;
    }

    _printVerifyReport(dbPath);
    return;
  }

  if (excelPath == null || excelPath.trim().isEmpty) {
    stderr.writeln(
      'Usage: flutter pub run tool/import_distributor_companies.dart --excel=<xlsx-path> [--db=<db-path>] [--dry-run] [--verify] [--clear-cheques]',
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

  final bytes = excelFile.readAsBytesSync();
  final workbook = Excel.decodeBytes(bytes);
  final sheet = workbook.tables[_sheetName];

  if (sheet == null) {
    stderr.writeln('Sheet not found: $_sheetName');
    stderr.writeln('Available sheets: ${workbook.tables.keys.join(', ')}');
    exitCode = 65;
    return;
  }

  if (dryRun) {
    _printDryRunReport(sheet, dbPath);
    return;
  }

  final dbFile = File(dbPath);

  if (!dbFile.existsSync()) {
    stderr.writeln('Database file not found: $dbPath');
    exitCode = 66;
    return;
  }

  final backupPath = await _backupDatabase(dbFile);

  final report = _ImportReport(backupPath: backupPath);
  final db = sqlite3.open(dbPath);

  try {
    report.deletedCompanies = _deleteAllCompanies(db);
    _importCompaniesFromSheet(db, sheet, report);
  } finally {
    db.dispose();
  }

  _printReport(report);
}

void _clearChequesOnly(String dbPath) {
  final db = sqlite3.open(dbPath);

  try {
    final deletedCount = _countTable(db, 'cheques');

    db.execute('DELETE FROM cheques');

    final remainingCount = _countTable(db, 'cheques');

    stdout.writeln('--- PharmaFlow Clear Cheques ---');
    stdout.writeln('Database path: $dbPath');
    stdout.writeln('deleted cheque count: $deletedCount');
    stdout.writeln('remaining cheque count: $remainingCount');
  } finally {
    db.dispose();
  }
}

void _printVerifyReport(String dbPath) {
  final db = sqlite3.open(dbPath);

  try {
    final companiesCount = _countTable(db, 'companies');
    final bankAccountsCount = _countTable(db, 'bank_accounts');
    final chequesCount = _countTable(db, 'cheques');

    stdout.writeln('--- PharmaFlow Database Verify ---');
    stdout.writeln('Database path: $dbPath');
    stdout.writeln('companies count: $companiesCount');
    stdout.writeln('bank accounts count: $bankAccountsCount');
    stdout.writeln('cheques count: $chequesCount');
  } finally {
    db.dispose();
  }
}

int _countTable(Database db, String tableName) {
  final result = db.select('SELECT COUNT(*) AS total FROM $tableName');
  return result.first['total'] as int;
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

int _deleteAllCompanies(Database db) {
  final count =
      db.select('SELECT COUNT(*) AS total FROM companies').first['total']
          as int;

  db.execute('DELETE FROM companies');
  return count;
}

void _importCompaniesFromSheet(Database db, Sheet sheet, _ImportReport report) {
  final headerRowIndex = _findHeaderRowIndex(sheet);
  if (headerRowIndex == null) {
    throw StateError('Could not find header row for sheet: $_sheetName');
  }

  final headerRow = sheet.rows[headerRowIndex];
  final headerMap = _buildHeaderMap(headerRow);

  final idxCompany = headerMap['نامشرکت'];
  final idxVisitorName = headerMap['نامویزیتور'];
  final idxVisitorPhone = headerMap['شمارهتلفنویزیتور'];
  final idxAccountantName = headerMap['نامحسابدار'];
  final idxAccountantPhone = headerMap['شمارهتلفنحسابدار'];
  final idxNationalId = headerMap['شناسهملی'];

  if (idxCompany == null) {
    throw StateError('Required column not found: نام شرکت');
  }

  final nowMillis = DateTime.now().millisecondsSinceEpoch;

  final insertStatement = db.prepare('''
    INSERT INTO companies (
      name,
      national_id,
      economic_code,
      notes,
      visitor_name,
      visitor_phone,
      accountant_name,
      accountant_phone,
      archived_at,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');

  db.execute('BEGIN TRANSACTION');

  try {
    for (
      var rowIndex = headerRowIndex + 1;
      rowIndex < sheet.rows.length;
      rowIndex++
    ) {
      final row = sheet.rows[rowIndex];

      try {
        var companyName = _cleanText(_cellText(row, idxCompany));

        if (companyName == '0') {
          companyName = _fallbackCompanyName;
        }

        if (companyName.isEmpty) {
          report.failedRows.add('Row ${rowIndex + 1}: نام شرکت خالی است.');
          continue;
        }

        final visitorName = _nullableCleanText(_cellText(row, idxVisitorName));
        final visitorPhoneResult = _normalizePhone(
          _cellText(row, idxVisitorPhone),
        );
        final accountantName = _nullableCleanText(
          _cellText(row, idxAccountantName),
        );
        final accountantPhoneResult = _normalizePhone(
          _cellText(row, idxAccountantPhone),
        );
        final nationalIdResult = _normalizeNationalId(
          _cellText(row, idxNationalId),
        );

        if (visitorPhoneResult.changed) {
          report.fixedPhoneCount++;
        }

        if (accountantPhoneResult.changed) {
          report.fixedPhoneCount++;
        }

        if (nationalIdResult.changed) {
          report.fixedNationalIdCount++;
        }

        insertStatement.execute([
          companyName,
          nationalIdResult.value,
          null,
          null,
          visitorName,
          visitorPhoneResult.value,
          accountantName,
          accountantPhoneResult.value,
          null,
          nowMillis,
          nowMillis,
        ]);

        report.importedCompanies++;
      } catch (e) {
        report.failedRows.add('Row ${rowIndex + 1}: $e');
      }
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    insertStatement.dispose();
  }
}

int? _findHeaderRowIndex(Sheet sheet) {
  for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
    final headerMap = _buildHeaderMap(sheet.rows[rowIndex]);
    if (headerMap.containsKey('نامشرکت')) {
      return rowIndex;
    }
  }

  return null;
}

void _printDryRunReport(Sheet sheet, String dbPath) {
  final headerRowIndex = _findHeaderRowIndex(sheet);

  if (headerRowIndex == null) {
    stdout.writeln('--- PharmaFlow Company Import Dry Run ---');
    stdout.writeln('Target database path: $dbPath');
    stdout.writeln('Sheet: $_sheetName');
    stdout.writeln('Header row: not found');
    stdout.writeln('Rows counted: 0');
    stdout.writeln('Detected company names: 0');
    return;
  }

  final headerMap = _buildHeaderMap(sheet.rows[headerRowIndex]);
  final idxCompany = headerMap['نامشرکت'];

  final companyNames = <String>[];

  for (
    var rowIndex = headerRowIndex + 1;
    rowIndex < sheet.rows.length;
    rowIndex++
  ) {
    final row = sheet.rows[rowIndex];
    var companyName = _cleanText(_cellText(row, idxCompany));

    if (companyName == '0') {
      companyName = _fallbackCompanyName;
    }

    if (companyName.isNotEmpty) {
      companyNames.add(companyName);
    }
  }

  final uniqueCompanyNames = companyNames.toSet().toList()..sort();

  stdout.writeln('--- PharmaFlow Company Import Dry Run ---');
  stdout.writeln('Target database path: $dbPath');
  stdout.writeln('Sheet: $_sheetName');
  stdout.writeln('Header row index: ${headerRowIndex + 1}');
  stdout.writeln('Rows counted: ${sheet.rows.length - (headerRowIndex + 1)}');
  stdout.writeln('Detected company names (${uniqueCompanyNames.length}):');

  for (final name in uniqueCompanyNames) {
    stdout.writeln(' - $name');
  }
}

Map<String, int> _buildHeaderMap(List<dynamic> row) {
  final map = <String, int>{};

  for (var i = 0; i < row.length; i++) {
    final text = _normalizeHeader(_cellValueToString(row[i]));
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

String _normalizeHeader(String input) {
  final text = _toEnglishDigits(input)
      .replaceAll('\u200c', '')
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim();

  return text;
}

String _cleanText(String input) {
  return input
      .replaceAll('\u200c', ' ')
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _nullableCleanText(String input) {
  final cleaned = _cleanText(input);
  if (cleaned.isEmpty) {
    return null;
  }

  return cleaned;
}

_NormalizedValue<String?> _normalizePhone(String raw) {
  final cleanedRaw = _toEnglishDigits(raw).trim();
  if (cleanedRaw.isEmpty) {
    return const _NormalizedValue<String?>(value: null, changed: false);
  }

  final digitCandidates = RegExp(r'[0-9]+')
      .allMatches(cleanedRaw)
      .map((m) => m.group(0) ?? '')
      .where((v) => v.isNotEmpty)
      .toList();

  if (digitCandidates.isEmpty) {
    return const _NormalizedValue<String?>(value: null, changed: true);
  }

  String selected = digitCandidates.firstWhere(
    (v) => v.startsWith('0917') || v.startsWith('917'),
    orElse: () => digitCandidates.first,
  );

  var changed = digitCandidates.length > 1;

  if (selected.startsWith('0098')) {
    selected = '0${selected.substring(4)}';
    changed = true;
  } else if (selected.startsWith('98')) {
    selected = '0${selected.substring(2)}';
    changed = true;
  } else if (!selected.startsWith('0')) {
    selected = '0$selected';
    changed = true;
  }

  final simpleSource = cleanedRaw.replaceAll(RegExp(r'[^0-9]'), '');
  if (simpleSource != selected) {
    changed = true;
  }

  return _NormalizedValue<String?>(value: selected, changed: changed);
}

_NormalizedValue<String?> _normalizeNationalId(String raw) {
  final cleanedRaw = _toEnglishDigits(raw).trim();
  if (cleanedRaw.isEmpty) {
    return const _NormalizedValue<String?>(value: null, changed: false);
  }

  var changed = false;
  String normalized;

  final scientificLike = RegExp(r'^[+-]?[0-9]*\.?[0-9]+[eE][+-]?[0-9]+$');
  if (scientificLike.hasMatch(cleanedRaw)) {
    final parsed = num.tryParse(cleanedRaw);
    if (parsed == null) {
      throw ArgumentError('شناسه ملی نامعتبر: $cleanedRaw');
    }
    normalized = parsed.toInt().toString();
    changed = true;
  } else {
    final numeric = num.tryParse(cleanedRaw);
    if (numeric != null && cleanedRaw.contains('.')) {
      normalized = numeric.toInt().toString();
      changed = true;
    } else {
      normalized = cleanedRaw.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalized != cleanedRaw) {
        changed = true;
      }
    }
  }

  if (normalized.isEmpty) {
    return const _NormalizedValue<String?>(value: null, changed: true);
  }

  return _NormalizedValue<String?>(
    value: normalized,
    changed: changed || normalized != cleanedRaw,
  );
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

void _printReport(_ImportReport report) {
  stdout.writeln('--- PharmaFlow Company Import Report ---');
  stdout.writeln('Backup path: ${report.backupPath}');
  stdout.writeln('Deleted companies count: ${report.deletedCompanies}');
  stdout.writeln('Imported companies count: ${report.importedCompanies}');
  stdout.writeln('Fixed phone count: ${report.fixedPhoneCount}');
  stdout.writeln('Fixed nationalId count: ${report.fixedNationalIdCount}');
  stdout.writeln('Failed rows: ${report.failedRows.length}');

  if (report.failedRows.isNotEmpty) {
    for (final row in report.failedRows) {
      stdout.writeln(' - $row');
    }
  }
}

class _ImportReport {
  _ImportReport({required this.backupPath});

  final String backupPath;
  int deletedCompanies = 0;
  int importedCompanies = 0;
  int fixedPhoneCount = 0;
  int fixedNationalIdCount = 0;
  final List<String> failedRows = <String>[];
}

class _NormalizedValue<T> {
  const _NormalizedValue({required this.value, required this.changed});

  final T value;
  final bool changed;
}
