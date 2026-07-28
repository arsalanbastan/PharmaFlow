import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String _sheetName = 'شرکت های پخش';

Future<void> main(List<String> args) async {
  final excelPath = _readArg(args, '--excel');
  final dbArgPath = _readArg(args, '--db');
  final dryRun = _hasFlag(args, '--dry-run');

  if (excelPath == null || excelPath.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_companies.dart --excel=<xlsx-path> [--db=<db-path>] [--dry-run]',
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
    report.updatedCount = _applyVisitorPhoneUpdates(db, report.rowsToUpdate);
  } finally {
    db.dispose();
  }

  _printReport(report, dbPath);
}

_VisitorPhoneImportReport _analyzeSheet(Sheet sheet, Database db) {
  final report = _VisitorPhoneImportReport();
  final headerRowIndex = _findHeaderRowIndex(sheet);

  if (headerRowIndex == null) {
    throw StateError('Could not find header row for sheet: $_sheetName');
  }

  final headerMap = _buildHeaderMap(sheet.rows[headerRowIndex]);
  final idxCompany = headerMap['نامشرکت'];
  final idxVisitorPhone = headerMap['شمارهتلفنویزتور'];

  if (idxCompany == null) {
    throw StateError('Required column not found: نام شرکت');
  }

  if (idxVisitorPhone == null) {
    throw StateError('Required column not found: شماره تلفن ویزتور');
  }

  final companyLookup = _loadCompanyLookup(db);

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

    final rawCompanyName = _cleanText(_cellText(row, idxCompany));
    final visitorPhoneResult = _normalizePhone(_cellText(row, idxVisitorPhone));
    final visitorPhone = visitorPhoneResult.value;

    if (visitorPhone == null) {
      report.emptyPhoneCount++;
    }

    if (rawCompanyName.isEmpty) {
      continue;
    }

    final company = companyLookup[_normalizeLookupKey(rawCompanyName)];
    if (company == null) {
      report.notFoundCompanies.add(rawCompanyName);
      continue;
    }

    if (visitorPhone == null) {
      continue;
    }

    if (company.visitorPhone == visitorPhone) {
      continue;
    }

    report.rowsToUpdate.add(
      _VisitorPhoneUpdate(
        companyId: company.id,
        companyName: company.name,
        visitorPhone: visitorPhone,
      ),
    );
  }

  report.matchedCompaniesCount = report.rowsToUpdate.length;
  return report;
}

int _applyVisitorPhoneUpdates(Database db, List<_VisitorPhoneUpdate> updates) {
  if (updates.isEmpty) {
    return 0;
  }

  final statement = db.prepare(
    'UPDATE companies SET visitor_phone = ? WHERE id = ?',
  );

  db.execute('BEGIN TRANSACTION');

  var updated = 0;

  try {
    for (final update in updates) {
      statement.execute([update.visitorPhone, update.companyId]);
      updated++;
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.dispose();
  }

  return updated;
}

Map<String, _CompanyRow> _loadCompanyLookup(Database db) {
  final rows = db.select('SELECT id, name, visitor_phone FROM companies');
  final lookup = <String, _CompanyRow>{};

  for (final row in rows) {
    final name = _cleanText(row['name']?.toString() ?? '');
    if (name.isEmpty) {
      continue;
    }

    lookup[_normalizeLookupKey(name)] = _CompanyRow(
      id: row['id'] as int,
      name: name,
      visitorPhone: row['visitor_phone']?.toString(),
    );
  }

  return lookup;
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

void _printDryRunReport(_VisitorPhoneImportReport report, String dbPath) {
  stdout.writeln('--- PharmaFlow Visitor Phone Import Dry Run ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Total rows: ${report.totalRows}');
  stdout.writeln('Updated count: ${report.rowsToUpdate.length}');
  stdout.writeln('Empty phone count: ${report.emptyPhoneCount}');
  stdout.writeln('Not found companies (${report.notFoundCompanies.length}):');

  if (report.notFoundCompanies.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final company in report.notFoundCompanies.toList()..sort()) {
      stdout.writeln(' - $company');
    }
  }
}

void _printReport(_VisitorPhoneImportReport report, String dbPath) {
  stdout.writeln('--- PharmaFlow Visitor Phone Import Report ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Backup path: ${report.backupPath}');
  stdout.writeln('Updated count: ${report.updatedCount}');
  stdout.writeln('Empty phone count: ${report.emptyPhoneCount}');
  stdout.writeln('Not found companies (${report.notFoundCompanies.length}):');

  if (report.notFoundCompanies.isEmpty) {
    stdout.writeln(' - none');
  } else {
    for (final company in report.notFoundCompanies.toList()..sort()) {
      stdout.writeln(' - $company');
    }
  }
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

String _normalizeLookupKey(String input) {
  return _cleanText(
    input,
  ).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase();
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

class _VisitorPhoneImportReport {
  int totalRows = 0;
  int matchedCompaniesCount = 0;
  int emptyPhoneCount = 0;
  String? backupPath;
  int updatedCount = 0;
  final Set<String> notFoundCompanies = <String>{};
  final List<_VisitorPhoneUpdate> rowsToUpdate = <_VisitorPhoneUpdate>[];
}

class _VisitorPhoneUpdate {
  const _VisitorPhoneUpdate({
    required this.companyId,
    required this.companyName,
    required this.visitorPhone,
  });

  final int companyId;
  final String companyName;
  final String visitorPhone;
}

class _CompanyRow {
  const _CompanyRow({
    required this.id,
    required this.name,
    required this.visitorPhone,
  });

  final int id;
  final String name;
  final String? visitorPhone;
}

class _NormalizedValue<T> {
  const _NormalizedValue({required this.value, required this.changed});

  final T value;
  final bool changed;
}
