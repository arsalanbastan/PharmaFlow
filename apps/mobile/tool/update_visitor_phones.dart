import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const String _sheetName = 'شرکت های پخش';
const String _companyHeaderKey = 'نامشرکت';
const String _visitorPhoneHeaderKey = 'شمارهتلفنویزتور';

Future<void> main(List<String> args) async {
  final excelPath = _readArg(args, '--excel');
  final dbArgPath = _readArg(args, '--db');
  final dryRun = _hasFlag(args, '--dry-run');

  if (excelPath == null || excelPath.trim().isEmpty) {
    stderr.writeln(
      'Usage: flutter pub run tool/update_visitor_phones.dart --excel=<xlsx-path> [--db=<db-path>] [--dry-run]',
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

  final db = sqlite3.open(dbPath);
  late final _UpdatePlan plan;

  try {
    plan = _buildUpdatePlan(sheet, db);

    if (dryRun) {
      _printDryRunReport(plan, dbPath);
      return;
    }
  } finally {
    db.dispose();
  }

  final backupPath = await _backupDatabase(dbFile);
  final writeDb = sqlite3.open(dbPath);

  try {
    final updatedCount = _applyUpdates(writeDb, plan.updates);
    _printRealModeReport(
      plan: plan,
      dbPath: dbPath,
      backupPath: backupPath,
      updatedCount: updatedCount,
    );
  } finally {
    writeDb.dispose();
  }
}

_UpdatePlan _buildUpdatePlan(Sheet sheet, Database db) {
  final headerRowIndex = _findHeaderRowIndex(sheet);
  if (headerRowIndex == null) {
    throw StateError('Could not find header row for sheet: $_sheetName');
  }

  final headerMap = _buildHeaderMap(sheet.rows[headerRowIndex]);
  final idxCompany = headerMap[_companyHeaderKey];
  final idxVisitorPhone = headerMap[_visitorPhoneHeaderKey];

  if (idxCompany == null) {
    throw StateError('Required column not found: نام شرکت');
  }

  if (idxVisitorPhone == null) {
    throw StateError('Required column not found: شماره تلفن ویزتور');
  }

  final companyLookup = _loadCompanyLookup(db);

  var totalExcelCompanies = 0;
  var matchedDatabaseCompanies = 0;
  var emptyVisitorPhones = 0;
  final missingCompanies = <String>{};
  final updatesByCompanyId = <int, _VisitorPhoneUpdate>{};

  for (
    var rowIndex = headerRowIndex + 1;
    rowIndex < sheet.rows.length;
    rowIndex++
  ) {
    final row = sheet.rows[rowIndex];
    if (!_rowHasData(row)) {
      continue;
    }

    final companyName = _cleanText(_cellText(row, idxCompany));
    if (companyName.isEmpty) {
      continue;
    }

    totalExcelCompanies++;

    final company = companyLookup[_normalizeLookupKey(companyName)];
    if (company == null) {
      missingCompanies.add(companyName);
      continue;
    }

    matchedDatabaseCompanies++;

    final normalizedPhone = _normalizePhone(_cellText(row, idxVisitorPhone));
    if (normalizedPhone == null) {
      emptyVisitorPhones++;
      continue;
    }

    if (company.visitorPhone == normalizedPhone) {
      continue;
    }

    updatesByCompanyId[company.id] = _VisitorPhoneUpdate(
      companyId: company.id,
      companyName: company.name,
      oldPhone: company.visitorPhone,
      newPhone: normalizedPhone,
    );
  }

  final updates = updatesByCompanyId.values.toList()
    ..sort((a, b) => a.companyName.compareTo(b.companyName));

  return _UpdatePlan(
    totalExcelCompanies: totalExcelCompanies,
    matchedDatabaseCompanies: matchedDatabaseCompanies,
    missingCompanies: missingCompanies.toList()..sort(),
    emptyVisitorPhones: emptyVisitorPhones,
    updates: updates,
  );
}

int _applyUpdates(Database db, List<_VisitorPhoneUpdate> updates) {
  if (updates.isEmpty) {
    return 0;
  }

  final statement = db.prepare(
    'UPDATE companies SET visitor_phone = ? WHERE id = ?',
  );
  var updatedCount = 0;

  db.execute('BEGIN TRANSACTION');

  try {
    for (final update in updates) {
      statement.execute([update.newPhone, update.companyId]);
      updatedCount++;
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.dispose();
  }

  return updatedCount;
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
      visitorPhone: _cleanText(row['visitor_phone']?.toString() ?? ''),
    );
  }

  return lookup;
}

void _printDryRunReport(_UpdatePlan plan, String dbPath) {
  stdout.writeln('--- Visitor Phone Update Dry Run ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Total Excel companies: ${plan.totalExcelCompanies}');
  stdout.writeln(
    'Matched database companies: ${plan.matchedDatabaseCompanies}',
  );
  stdout.writeln('Missing companies: ${plan.missingCompanies.length}');
  stdout.writeln('Empty visitor phones: ${plan.emptyVisitorPhones}');
  stdout.writeln('Planned updates: ${plan.updates.length}');

  if (plan.missingCompanies.isNotEmpty) {
    stdout.writeln('Missing company names:');
    for (final name in plan.missingCompanies) {
      stdout.writeln(' - $name');
    }
  }

  stdout.writeln('Sample updates:');
  if (plan.updates.isEmpty) {
    stdout.writeln(' - none');
  } else {
    final sample = plan.updates.take(10);
    for (final update in sample) {
      final oldPhone = update.oldPhone.isEmpty ? '(empty)' : update.oldPhone;
      stdout.writeln(
        ' - ${update.companyName}: $oldPhone -> ${update.newPhone}',
      );
    }
  }
}

void _printRealModeReport({
  required _UpdatePlan plan,
  required String dbPath,
  required String backupPath,
  required int updatedCount,
}) {
  stdout.writeln('--- Visitor Phone Update Report ---');
  stdout.writeln('Database path: $dbPath');
  stdout.writeln('Backup path: $backupPath');
  stdout.writeln('Updated count: $updatedCount');
  stdout.writeln('Not found count: ${plan.missingCompanies.length}');
  stdout.writeln('Empty phone count: ${plan.emptyVisitorPhones}');
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

int? _findHeaderRowIndex(Sheet sheet) {
  for (var rowIndex = 0; rowIndex < sheet.rows.length; rowIndex++) {
    final headerMap = _buildHeaderMap(sheet.rows[rowIndex]);
    if (headerMap.containsKey(_companyHeaderKey)) {
      return rowIndex;
    }
  }

  return null;
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

bool _rowHasData(List<dynamic> row) {
  for (final cell in row) {
    final value = cell?.value;
    if (value != null && value.toString().trim().isNotEmpty) {
      return true;
    }
  }

  return false;
}

String? _normalizePhone(String raw) {
  final cleanedRaw = _toEnglishDigits(raw).trim();
  if (cleanedRaw.isEmpty) {
    return null;
  }

  final digitCandidates = RegExp(r'[0-9]+')
      .allMatches(cleanedRaw)
      .map((m) => m.group(0) ?? '')
      .where((v) => v.isNotEmpty)
      .toList();

  if (digitCandidates.isEmpty) {
    return null;
  }

  String selected = digitCandidates.firstWhere(
    (v) => v.startsWith('0917') || v.startsWith('917'),
    orElse: () => digitCandidates.first,
  );

  if (selected.startsWith('0098')) {
    selected = '0${selected.substring(4)}';
  } else if (selected.startsWith('98')) {
    selected = '0${selected.substring(2)}';
  } else if (!selected.startsWith('0')) {
    selected = '0$selected';
  }

  return selected;
}

String _normalizeHeader(String input) {
  return _toEnglishDigits(input)
      .replaceAll('\u200c', '')
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim();
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

class _UpdatePlan {
  const _UpdatePlan({
    required this.totalExcelCompanies,
    required this.matchedDatabaseCompanies,
    required this.missingCompanies,
    required this.emptyVisitorPhones,
    required this.updates,
  });

  final int totalExcelCompanies;
  final int matchedDatabaseCompanies;
  final List<String> missingCompanies;
  final int emptyVisitorPhones;
  final List<_VisitorPhoneUpdate> updates;
}

class _VisitorPhoneUpdate {
  const _VisitorPhoneUpdate({
    required this.companyId,
    required this.companyName,
    required this.oldPhone,
    required this.newPhone,
  });

  final int companyId;
  final String companyName;
  final String oldPhone;
  final String newPhone;
}

class _CompanyRow {
  const _CompanyRow({
    required this.id,
    required this.name,
    required this.visitorPhone,
  });

  final int id;
  final String name;
  final String visitorPhone;
}
