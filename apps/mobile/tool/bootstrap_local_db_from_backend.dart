import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

const _defaultHost = '192.168.1.215';
const _defaultPort = 3000;
const _defaultApiVersion = 'v1';
const _validStatuses = {'Issued', 'Registered', 'Cancelled'};

Future<void> main(List<String> args) async {
  final options = _Options.fromArgs(args);
  final dbPath = options.dbPath ?? _defaultDbPath();

  if (dbPath == null || !File(dbPath).existsSync()) {
    stderr.writeln('No usable db path found. Pass --db-path=<path>.');
    exitCode = 1;
    return;
  }

  final startedAt = DateTime.now();
  final db = sqlite3.open(dbPath);

  try {
    db.execute('PRAGMA foreign_keys = ON;');

    final remoteCompanies = await _fetchRemoteCompanies(options);
    final remoteBankAccounts = await _fetchRemoteBankAccounts(options);
    final remoteCheques = await _fetchRemoteCheques(options);

    final importStats = _bootstrapInTransaction(
      db: db,
      companies: remoteCompanies,
      bankAccounts: remoteBankAccounts,
      cheques: remoteCheques,
    );

    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;

    final verification = _runVerification(
      db: db,
      companiesDownloaded: remoteCompanies.length,
      bankAccountsDownloaded: remoteBankAccounts.length,
      chequesDownloaded: remoteCheques.length,
      durationMs: durationMs,
      importStats: importStats,
    );

    final payload = {
      'mode': 'adr-016-bootstrap',
      'dbPath': dbPath,
      'backendBaseUrl': options.baseUrl,
      'startedAt': startedAt.toIso8601String(),
      'durationMs': durationMs,
      'downloaded': {
        'companies': remoteCompanies.length,
        'bankAccounts': remoteBankAccounts.length,
        'cheques': remoteCheques.length,
      },
      'imported': {
        'companies': importStats.insertedCompanies,
        'bankAccounts': importStats.insertedBankAccounts,
        'cheques': importStats.insertedCheques,
      },
      'skipped': {
        'companies': importStats.skippedCompanies,
        'bankAccounts': importStats.skippedBankAccounts,
        'cheques': importStats.skippedCheques,
      },
      'issues': importStats.issues,
      'verification': verification,
    };

    final output = const JsonEncoder.withIndent('  ').convert(payload);
    if (options.outputPath != null && options.outputPath!.trim().isNotEmpty) {
      await File(options.outputPath!).writeAsString(output, encoding: utf8);
    }
    stdout.writeln(output);
  } finally {
    db.dispose();
  }
}

class _Options {
  const _Options({
    required this.dbPath,
    required this.host,
    required this.port,
    required this.useHttps,
    required this.apiVersion,
    required this.outputPath,
  });

  final String? dbPath;
  final String host;
  final int port;
  final bool useHttps;
  final String apiVersion;
  final String? outputPath;

  String get baseUrl {
    final scheme = useHttps ? 'https' : 'http';
    final version = apiVersion.startsWith('v') ? apiVersion : 'v$apiVersion';
    return '$scheme://$host:$port/api/$version';
  }

  static _Options fromArgs(List<String> args) {
    String? dbPath;
    var host = _defaultHost;
    var port = _defaultPort;
    var useHttps = false;
    var apiVersion = _defaultApiVersion;
    String? outputPath;

    for (final arg in args) {
      if (arg == '--https') {
        useHttps = true;
        continue;
      }
      if (arg.startsWith('--db-path=')) {
        dbPath = arg.substring('--db-path='.length).trim();
        continue;
      }
      if (arg.startsWith('--host=')) {
        host = arg.substring('--host='.length).trim();
        continue;
      }
      if (arg.startsWith('--port=')) {
        port = int.tryParse(arg.substring('--port='.length).trim()) ?? port;
        continue;
      }
      if (arg.startsWith('--api-version=')) {
        apiVersion = arg.substring('--api-version='.length).trim();
        continue;
      }
      if (arg.startsWith('--output=')) {
        outputPath = arg.substring('--output='.length).trim();
      }
    }

    return _Options(
      dbPath: dbPath,
      host: host,
      port: port,
      useHttps: useHttps,
      apiVersion: apiVersion,
      outputPath: outputPath,
    );
  }
}

String? _defaultDbPath() {
  const candidates = [
    'd:/Projects/PharmaFlow/apps/mobile/tool/device_pharmaflow_live.db',
    'd:/Projects/PharmaFlow/apps/mobile/tool/device_pharmaflow.db',
    'd:/Projects/PharmaFlow/apps/mobile/pharmaflow.db',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  return null;
}

Future<List<_RemoteCompany>> _fetchRemoteCompanies(_Options options) async {
  final uri = Uri.parse('${options.baseUrl}/companies');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 45));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException('Expected /companies to return a JSON list.');
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteCompany.fromJson)
      .toList(growable: false);
}

Future<List<_RemoteBankAccount>> _fetchRemoteBankAccounts(
  _Options options,
) async {
  final uri = Uri.parse('${options.baseUrl}/bank-accounts');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 45));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException(
      'Expected /bank-accounts to return a JSON list.',
    );
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteBankAccount.fromJson)
      .toList(growable: false);
}

Future<List<_RemoteCheque>> _fetchRemoteCheques(_Options options) async {
  final uri = Uri.parse('${options.baseUrl}/cheques');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 45));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException('Expected /cheques to return a JSON list.');
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteCheque.fromJson)
      .toList(growable: false);
}

_ImportStats _bootstrapInTransaction({
  required Database db,
  required List<_RemoteCompany> companies,
  required List<_RemoteBankAccount> bankAccounts,
  required List<_RemoteCheque> cheques,
}) {
  var insertedCompanies = 0;
  var insertedBankAccounts = 0;
  var insertedCheques = 0;
  var skippedCompanies = 0;
  var skippedBankAccounts = 0;
  var skippedCheques = 0;

  final issues = <String>[];
  final companyIdByUuid = <String, int>{};
  final bankIdByUuid = <String, int>{};

  db.execute('BEGIN TRANSACTION');
  try {
    db.execute('DELETE FROM sync_queue');
    db.execute('DELETE FROM cheques');
    db.execute('DELETE FROM bank_accounts');
    db.execute('DELETE FROM companies');

    final insertCompany = db.prepare('''
INSERT INTO companies (
  server_uuid,
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
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
''');

    try {
      for (final company in companies) {
        if (company.uuid.isEmpty) {
          skippedCompanies++;
          issues.add('Skipped company with empty UUID: ${company.name}.');
          continue;
        }

        final companyName = company.name.isEmpty
            ? 'Company-${company.uuid.substring(0, min(8, company.uuid.length))}'
            : company.name;
        final createdAt =
            company.createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
        final updatedAt = company.updatedAtMs ?? createdAt;

        try {
          insertCompany.execute([
            company.uuid,
            companyName,
            company.nationalId,
            company.economicCode,
            company.notes,
            company.visitorName,
            company.visitorPhone,
            company.accountantName,
            company.accountantPhone,
            createdAt,
            updatedAt,
          ]);
          insertedCompanies++;

          final localId = _toInt(
            db.select('SELECT last_insert_rowid() AS id').first['id'],
          );
          companyIdByUuid[company.uuid] = localId;
        } catch (e) {
          skippedCompanies++;
          issues.add('Failed company ${company.uuid}: $e');
        }
      }
    } finally {
      insertCompany.dispose();
    }

    final insertBank = db.prepare('''
INSERT INTO bank_accounts (
  server_uuid,
  bank_name,
  account_title,
  account_holder,
  account_number,
  card_number,
  iban,
  note,
  archived_at,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
''');

    try {
      for (final account in bankAccounts) {
        if (account.uuid.isEmpty) {
          skippedBankAccounts++;
          issues.add('Skipped bank account with empty UUID.');
          continue;
        }

        final suffix = account.uuid.substring(0, min(8, account.uuid.length));
        final bankName = account.bankName ?? 'Unknown Bank';
        final accountTitle = account.accountTitle ?? 'Account-$suffix';
        final accountHolder = account.accountHolder ?? accountTitle;
        final accountNumber = account.accountNumber ?? 'ACC-$suffix';
        final cardNumber = account.cardNumber ?? accountNumber;
        final iban = account.iban ?? 'IR${_numericSeed(account.uuid, 24)}';
        final createdAt =
            account.createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
        final updatedAt = account.updatedAtMs ?? createdAt;

        try {
          insertBank.execute([
            account.uuid,
            bankName,
            accountTitle,
            accountHolder,
            accountNumber,
            cardNumber,
            iban,
            account.note,
            createdAt,
            updatedAt,
          ]);
          insertedBankAccounts++;

          final localId = _toInt(
            db.select('SELECT last_insert_rowid() AS id').first['id'],
          );
          bankIdByUuid[account.uuid] = localId;
        } catch (e) {
          skippedBankAccounts++;
          issues.add('Failed bank account ${account.uuid}: $e');
        }
      }
    } finally {
      insertBank.dispose();
    }

    final insertCheque = db.prepare('''
INSERT INTO cheques (
  server_uuid,
  company_id,
  bank_account_id,
  receiver_name,
  cheque_number,
  amount_rial,
  issue_date,
  due_date,
  status,
  description,
  is_registered_in_sayad,
  sayad_id,
  image_data,
  archived_at,
  delete_requested_at,
  created_at,
  updated_at
) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?)
''');

    try {
      for (final cheque in cheques) {
        if (cheque.uuid.isEmpty) {
          skippedCheques++;
          issues.add('Skipped cheque with empty UUID: ${cheque.chequeNumber}.');
          continue;
        }

        final companyId = companyIdByUuid[cheque.companyUuid];
        final bankId = bankIdByUuid[cheque.bankAccountUuid];

        if (companyId == null || bankId == null) {
          skippedCheques++;
          issues.add(
            'Skipped cheque ${cheque.uuid}: unresolved FK company=${cheque.companyUuid} bank=${cheque.bankAccountUuid}.',
          );
          continue;
        }

        final issueDate = cheque.chequeDate.millisecondsSinceEpoch;
        final dueDate = max(
          issueDate,
          cheque.dueDate?.millisecondsSinceEpoch ?? issueDate,
        );
        final amount = max(1, cheque.amount.toInt());
        final status =
            _normalizeStatus(cheque.status) ??
            (cheque.isRegisteredInSayad ? 'Registered' : 'Issued');
        final createdAt =
            cheque.createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
        final updatedAt = cheque.updatedAtMs ?? createdAt;

        try {
          insertCheque.execute([
            cheque.uuid,
            companyId,
            bankId,
            cheque.chequeNumber.isEmpty
                ? 'NO-CHEQUE-NUMBER'
                : cheque.chequeNumber,
            amount,
            issueDate,
            dueDate,
            status,
            cheque.description,
            cheque.isRegisteredInSayad ? 1 : 0,
            cheque.sayadId,
            createdAt,
            updatedAt,
          ]);
          insertedCheques++;
        } catch (e) {
          skippedCheques++;
          issues.add('Failed cheque ${cheque.uuid}: $e');
        }
      }
    } finally {
      insertCheque.dispose();
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }

  return _ImportStats(
    insertedCompanies: insertedCompanies,
    insertedBankAccounts: insertedBankAccounts,
    insertedCheques: insertedCheques,
    skippedCompanies: skippedCompanies,
    skippedBankAccounts: skippedBankAccounts,
    skippedCheques: skippedCheques,
    issues: issues,
  );
}

Map<String, Object?> _runVerification({
  required Database db,
  required int companiesDownloaded,
  required int bankAccountsDownloaded,
  required int chequesDownloaded,
  required int durationMs,
  required _ImportStats importStats,
}) {
  final companiesUuidCheck = _uuidCheck(db, table: 'companies');
  final bankUuidCheck = _uuidCheck(db, table: 'bank_accounts');
  final chequeUuidCheck = _uuidCheck(db, table: 'cheques');

  final fkBroken = _toInt(
    db.select('''
SELECT COUNT(*) AS total
FROM cheques c
LEFT JOIN companies co ON co.id = c.company_id
LEFT JOIN bank_accounts ba ON ba.id = c.bank_account_id
WHERE co.id IS NULL OR ba.id IS NULL
''').first['total'],
  );

  final queueCount = _toInt(
    db.select('SELECT COUNT(*) AS total FROM sync_queue').first['total'],
  );

  final activeDashboardCount = _toInt(
    db.select('''
SELECT COUNT(*) AS total
FROM cheques c
INNER JOIN companies co ON co.id = c.company_id
INNER JOIN bank_accounts ba ON ba.id = c.bank_account_id
WHERE c.archived_at IS NULL AND c.delete_requested_at IS NULL
''').first['total'],
  );

  final dbCounts = {
    'companies': _count(db, 'SELECT COUNT(*) AS total FROM companies'),
    'bankAccounts': _count(db, 'SELECT COUNT(*) AS total FROM bank_accounts'),
    'cheques': _count(db, 'SELECT COUNT(*) AS total FROM cheques'),
  };

  final sample = _randomChequeSample(db, sampleSize: 20);

  return {
    'requestedMetrics': {
      'companiesDownloaded': companiesDownloaded,
      'bankAccountsDownloaded': bankAccountsDownloaded,
      'chequesDownloaded': chequesDownloaded,
      'bootstrapDurationMs': durationMs,
    },
    'dbCounts': dbCounts,
    'uuidVerification': {
      'companies': companiesUuidCheck,
      'bankAccounts': bankUuidCheck,
      'cheques': chequeUuidCheck,
      'allPassed':
          companiesUuidCheck['ok'] == true &&
          bankUuidCheck['ok'] == true &&
          chequeUuidCheck['ok'] == true,
    },
    'foreignKeyVerification': {'brokenCheques': fkBroken, 'ok': fkBroken == 0},
    'dashboardVerification': {
      'activeJoinCount': activeDashboardCount,
      'ok': activeDashboardCount == dbCounts['cheques'],
    },
    'syncQueueVerification': {
      'pendingTotal': queueCount,
      'ok': queueCount == 0,
    },
    'randomChequeSample': sample,
    'importDiagnostics': {
      'inserted': {
        'companies': importStats.insertedCompanies,
        'bankAccounts': importStats.insertedBankAccounts,
        'cheques': importStats.insertedCheques,
      },
      'skipped': {
        'companies': importStats.skippedCompanies,
        'bankAccounts': importStats.skippedBankAccounts,
        'cheques': importStats.skippedCheques,
      },
      'issueCount': importStats.issues.length,
    },
  };
}

Map<String, Object?> _uuidCheck(Database db, {required String table}) {
  final total = _count(db, 'SELECT COUNT(*) AS total FROM $table');
  final nullOrBlank = _count(db, '''
SELECT COUNT(*) AS total
FROM $table
WHERE server_uuid IS NULL OR TRIM(server_uuid) = ''
''');
  final distinctNonBlank = _count(db, '''
SELECT COUNT(DISTINCT TRIM(server_uuid)) AS total
FROM $table
WHERE server_uuid IS NOT NULL AND TRIM(server_uuid) != ''
''');

  final expectedDistinct = total - nullOrBlank;
  final duplicateCount = max(0, expectedDistinct - distinctNonBlank);

  return {
    'table': table,
    'total': total,
    'nullOrBlank': nullOrBlank,
    'duplicateCount': duplicateCount,
    'ok': nullOrBlank == 0 && duplicateCount == 0,
  };
}

List<Map<String, Object?>> _randomChequeSample(
  Database db, {
  required int sampleSize,
}) {
  final rows = db.select('''
SELECT
  c.id,
  c.server_uuid AS cheque_uuid,
  c.company_id,
  c.bank_account_id,
  co.server_uuid AS company_uuid,
  ba.server_uuid AS bank_uuid,
  c.cheque_number,
  c.amount_rial
FROM cheques c
INNER JOIN companies co ON co.id = c.company_id
INNER JOIN bank_accounts ba ON ba.id = c.bank_account_id
ORDER BY c.id ASC
''');

  if (rows.isEmpty) return const [];

  final random = Random();
  final selectedIndices = <int>{};
  final target = min(sampleSize, rows.length);

  while (selectedIndices.length < target) {
    selectedIndices.add(random.nextInt(rows.length));
  }

  final sorted = selectedIndices.toList()..sort();

  return [
    for (final idx in sorted)
      {
        'localChequeId': _toInt(rows[idx]['id']),
        'chequeUuid': rows[idx]['cheque_uuid']?.toString(),
        'companyId': _toInt(rows[idx]['company_id']),
        'companyUuid': rows[idx]['company_uuid']?.toString(),
        'bankAccountId': _toInt(rows[idx]['bank_account_id']),
        'bankUuid': rows[idx]['bank_uuid']?.toString(),
        'chequeNumber': rows[idx]['cheque_number']?.toString(),
        'amountRial': _toInt(rows[idx]['amount_rial']),
        'fkOk':
            rows[idx]['company_uuid'] != null && rows[idx]['bank_uuid'] != null,
      },
  ];
}

class _ImportStats {
  const _ImportStats({
    required this.insertedCompanies,
    required this.insertedBankAccounts,
    required this.insertedCheques,
    required this.skippedCompanies,
    required this.skippedBankAccounts,
    required this.skippedCheques,
    required this.issues,
  });

  final int insertedCompanies;
  final int insertedBankAccounts;
  final int insertedCheques;
  final int skippedCompanies;
  final int skippedBankAccounts;
  final int skippedCheques;
  final List<String> issues;
}

class _RemoteCompany {
  const _RemoteCompany({
    required this.uuid,
    required this.name,
    required this.nationalId,
    required this.economicCode,
    required this.notes,
    required this.visitorName,
    required this.visitorPhone,
    required this.accountantName,
    required this.accountantPhone,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String uuid;
  final String name;
  final String? nationalId;
  final String? economicCode;
  final String? notes;
  final String? visitorName;
  final String? visitorPhone;
  final String? accountantName;
  final String? accountantPhone;
  final int? createdAtMs;
  final int? updatedAtMs;

  factory _RemoteCompany.fromJson(Map<String, dynamic> json) {
    return _RemoteCompany(
      uuid: _trimOrNull(json['id']?.toString()) ?? '',
      name: _trimOrNull(json['name']?.toString()) ?? '',
      nationalId: _trimOrNull(json['nationalId']?.toString()),
      economicCode: _trimOrNull(json['economicCode']?.toString()),
      notes: _trimOrNull(json['notes']?.toString()),
      visitorName: _trimOrNull(json['visitorName']?.toString()),
      visitorPhone: _trimOrNull(json['visitorPhone']?.toString()),
      accountantName: _trimOrNull(json['accountantName']?.toString()),
      accountantPhone: _trimOrNull(json['accountantPhone']?.toString()),
      createdAtMs: _readEpochMs(json['createdAt']),
      updatedAtMs: _readEpochMs(json['updatedAt']),
    );
  }
}

class _RemoteBankAccount {
  const _RemoteBankAccount({
    required this.uuid,
    required this.bankName,
    required this.accountTitle,
    required this.accountHolder,
    required this.accountNumber,
    required this.cardNumber,
    required this.iban,
    required this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String uuid;
  final String? bankName;
  final String? accountTitle;
  final String? accountHolder;
  final String? accountNumber;
  final String? cardNumber;
  final String? iban;
  final String? note;
  final int? createdAtMs;
  final int? updatedAtMs;

  factory _RemoteBankAccount.fromJson(Map<String, dynamic> json) {
    return _RemoteBankAccount(
      uuid: _trimOrNull(json['id']?.toString()) ?? '',
      bankName: _trimOrNull(json['bankName']?.toString()),
      accountTitle: _trimOrNull(json['accountTitle']?.toString()),
      accountHolder: _trimOrNull(
        (json['accountHolder'] ?? json['accountOwner'])?.toString(),
      ),
      accountNumber: _trimOrNull(json['accountNumber']?.toString()),
      cardNumber: _trimOrNull(json['cardNumber']?.toString()),
      iban: _trimOrNull((json['iban'] ?? json['shebaNumber'])?.toString()),
      note: _trimOrNull(json['note']?.toString()),
      createdAtMs: _readEpochMs(json['createdAt']),
      updatedAtMs: _readEpochMs(json['updatedAt']),
    );
  }
}

class _RemoteCheque {
  const _RemoteCheque({
    required this.uuid,
    required this.companyUuid,
    required this.bankAccountUuid,
    required this.chequeNumber,
    required this.amount,
    required this.chequeDate,
    required this.dueDate,
    required this.status,
    required this.isRegisteredInSayad,
    required this.sayadId,
    required this.description,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String uuid;
  final String companyUuid;
  final String bankAccountUuid;
  final String chequeNumber;
  final num amount;
  final DateTime chequeDate;
  final DateTime? dueDate;
  final String? status;
  final bool isRegisteredInSayad;
  final String? sayadId;
  final String? description;
  final int? createdAtMs;
  final int? updatedAtMs;

  factory _RemoteCheque.fromJson(Map<String, dynamic> json) {
    final issueDate = _readDate(json['chequeDate']) ?? DateTime.now();

    return _RemoteCheque(
      uuid: _trimOrNull(json['id']?.toString()) ?? '',
      companyUuid: _trimOrNull(json['companyId']?.toString()) ?? '',
      bankAccountUuid: _trimOrNull(json['bankAccountId']?.toString()) ?? '',
      chequeNumber: _trimOrNull(json['chequeNumber']?.toString()) ?? '',
      amount: _readAmount(json['amount']),
      chequeDate: issueDate,
      dueDate: _readDate(json['dueDate']),
      status: _trimOrNull(json['status']?.toString()),
      isRegisteredInSayad: _toBool(json['isRegisteredInSayad']),
      sayadId: _trimOrNull(json['sayadId']?.toString()),
      description: _trimOrNull(json['description']?.toString()),
      createdAtMs: _readEpochMs(json['createdAt']),
      updatedAtMs: _readEpochMs(json['updatedAt']),
    );
  }
}

int _count(Database db, String sql, [List<Object?> params = const []]) {
  return _toInt(db.select(sql, params).first['total']);
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String? _trimOrNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizeStatus(String? raw) {
  final trimmed = _trimOrNull(raw);
  if (trimmed == null) return null;
  if (_validStatuses.contains(trimmed)) return trimmed;

  switch (trimmed.toLowerCase()) {
    case 'issued':
      return 'Issued';
    case 'registered':
      return 'Registered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return null;
  }
}

num _readAmount(Object? value) {
  if (value is num) return value;
  if (value is String) {
    final parsed = num.tryParse(value.trim().replaceAll(',', ''));
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
  return false;
}

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    final epoch = value.toInt();
    if (epoch > 0) return DateTime.fromMillisecondsSinceEpoch(epoch);
  }
  return null;
}

int? _readEpochMs(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    final asInt = int.tryParse(value.trim());
    if (asInt != null) return asInt;
    final asDate = DateTime.tryParse(value.trim());
    if (asDate != null) return asDate.millisecondsSinceEpoch;
  }
  return null;
}

String _numericSeed(String source, int width) {
  final digits = source.runes.map((r) => (r % 10).toString()).join();
  if (digits.length >= width) return digits.substring(0, width);
  return digits.padRight(width, '0');
}
