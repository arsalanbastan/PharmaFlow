import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _chequeEntityType = 'CHEQUE';
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

  final db = sqlite3.open(dbPath);
  try {
    final beforeState = _auditLocalState(db);

    if (options.auditOnly) {
      await _emitResult(options, {
        'mode': 'audit-only',
        'dbPath': dbPath,
        'beforeState': beforeState.toJson(),
      });
      return;
    }

    final backup = await _createBackup(db, dbPath: dbPath);
    final remoteCheques = await _fetchRemoteCheques(options);
    final remoteCompanies = await _fetchRemoteCompanies(options);
    final remoteBankAccounts = await _fetchRemoteBankAccounts(options);

    final localCompanies = _readLocalCompanies(db);
    final localBankAccounts = _readLocalBankAccounts(db);
    final localCheques = _readLocalCheques(db);

    final companyIdByUuid = _lookupLocalIdsByUuid(db, tableName: 'companies');
    final bankAccountIdByUuid = _lookupLocalIdsByUuid(
      db,
      tableName: 'bank_accounts',
    );
    final remoteCompaniesByUuid = {
      for (final company in remoteCompanies) company.uuid: company,
    };
    final remoteBankAccountsByUuid = {
      for (final account in remoteBankAccounts) account.uuid: account,
    };

    final staged = <_StagedCheque>[];
    final remainingIssues = <String>[];
    final appliedFallbacks = <Map<String, Object?>>[];

    for (final remote in remoteCheques) {
      final serverUuid = remote.serverUuid.trim();
      if (serverUuid.isEmpty) {
        remainingIssues.add(
          'Remote cheque with chequeNumber=${remote.chequeNumber} has empty UUID.',
        );
        continue;
      }

      final localCompanyId =
          companyIdByUuid[remote.companyUuid] ??
          _resolveCompanyIdFallback(
            remoteCompany: remoteCompaniesByUuid[remote.companyUuid],
            localCompanies: localCompanies,
          );
      if (localCompanyId == null) {
        remainingIssues.add(
          'Remote cheque $serverUuid references unknown local company UUID ${remote.companyUuid}.',
        );
        continue;
      }

      final localBankAccountId =
          bankAccountIdByUuid[remote.bankAccountUuid] ??
          _resolveBankAccountIdFallback(
            remoteBankAccount: remoteBankAccountsByUuid[remote.bankAccountUuid],
            localBankAccounts: localBankAccounts,
          );
      if (localBankAccountId == null) {
        remainingIssues.add(
          'Remote cheque $serverUuid references unknown local bank account UUID ${remote.bankAccountUuid}.',
        );
        continue;
      }

      final dueDateMillis =
          remote.dueDate?.millisecondsSinceEpoch ??
          _resolveDueDateFallback(
            remoteCheque: remote,
            localCompanyId: localCompanyId,
            localBankAccountId: localBankAccountId,
            localCheques: localCheques,
          );

      final resolvedDueDateMillis =
          dueDateMillis ?? remote.chequeDate.millisecondsSinceEpoch;
      if (remote.dueDate == null) {
        appliedFallbacks.add({
          'serverUuid': serverUuid,
          'fallback': 'dueDate <- chequeDate',
          'chequeDate': remote.chequeDate.toIso8601String(),
        });
      }

      final matchedLocalStatus = _resolveStatusFallback(
        remoteCheque: remote,
        localCompanyId: localCompanyId,
        localBankAccountId: localBankAccountId,
        localCheques: localCheques,
      );
      final normalizedStatus =
          _normalizeStatus(remote.status) ??
          matchedLocalStatus ??
          (remote.isRegisteredInSayad == true ? 'Registered' : 'Issued');
      if (remote.status == null) {
        appliedFallbacks.add({
          'serverUuid': serverUuid,
          'fallback': matchedLocalStatus != null
              ? 'status <- matched local cheque status'
              : 'status <- isRegisteredInSayad/Issued default',
          'resolvedStatus': normalizedStatus,
        });
      }

      staged.add(
        _StagedCheque(
          serverUuid: serverUuid,
          companyId: localCompanyId,
          bankAccountId: localBankAccountId,
          chequeNumber: remote.chequeNumber,
          amountRial: remote.amount.toInt(),
          issueDateMillis: remote.chequeDate.millisecondsSinceEpoch,
          dueDateMillis: resolvedDueDateMillis,
          status: normalizedStatus,
          isRegisteredInSayad: remote.isRegisteredInSayad ?? false,
          sayadId: _trimOrNull(remote.sayadId),
          description: _trimOrNull(remote.description),
          imageData: remote.imageData,
          createdAtMillis:
              remote.createdAt?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
          updatedAtMillis:
              remote.updatedAt?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    if (remainingIssues.isNotEmpty) {
      await _emitResult(options, {
        'mode': 'aborted',
        'dbPath': dbPath,
        'beforeState': beforeState.toJson(),
        'actionsPerformed': {
          'backup': backup.toJson(),
          'fetchedRemoteChequeCount': remoteCheques.length,
        },
        'remainingIssues': remainingIssues,
      });
      return;
    }

    final resetSummary = _resetAndRebuild(db, staged);
    final afterState = _auditLocalState(db);

    await _emitResult(options, {
      'mode': 'full-reset',
      'dbPath': dbPath,
      'beforeState': beforeState.toJson(),
      'actionsPerformed': {
        'backup': backup.toJson(),
        'fetchedRemoteChequeCount': remoteCheques.length,
        'resetSummary': resetSummary.toJson(),
        'backendBaseUrl': options.baseUrl,
        'appliedFallbacks': appliedFallbacks,
      },
      'afterState': {
        ...afterState.toJson(),
        'verification': _verification(db, afterState, staged),
      },
      'remainingIssues': remainingIssues,
    });
  } finally {
    db.dispose();
  }
}

Future<void> _emitResult(_Options options, Map<String, Object?> payload) async {
  final text = const JsonEncoder.withIndent('  ').convert(payload);
  final outputPath = options.outputPath;
  if (outputPath != null && outputPath.isNotEmpty) {
    await File(outputPath).writeAsString(text, encoding: utf8);
  }
  stdout.writeln(text);
}

class _Options {
  const _Options({
    required this.dbPath,
    required this.host,
    required this.port,
    required this.useHttps,
    required this.apiVersion,
    required this.auditOnly,
    required this.outputPath,
  });

  final String? dbPath;
  final String host;
  final int port;
  final bool useHttps;
  final String apiVersion;
  final bool auditOnly;
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
    var auditOnly = false;
    String? outputPath;

    for (final arg in args) {
      if (arg == '--audit-only') {
        auditOnly = true;
        continue;
      }
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
      auditOnly: auditOnly,
      outputPath: outputPath,
    );
  }
}

String? _defaultDbPath() {
  const candidates = [
    'd:/Projects/PharmaFlow/apps/mobile/tool/device_pharmaflow_after_cleanup.db',
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

Future<_BackupSummary> _createBackup(
  Database db, {
  required String dbPath,
}) async {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final backupDir = Directory(
    p.join('d:/Projects/PharmaFlow/apps/mobile', 'tool', 'backups'),
  );
  if (!backupDir.existsSync()) {
    backupDir.createSync(recursive: true);
  }

  final backupFile = File(
    p.join(backupDir.path, 'cheque_backup_$timestamp.json'),
  );

  final chequeRows = db.select('''
SELECT id, server_uuid, cheque_number, company_id, bank_account_id, amount_rial,
       issue_date, due_date, status, is_registered_in_sayad, sayad_id,
       description, image_data, created_at, updated_at
FROM cheques
ORDER BY id ASC
''');

  final queueRows = db.select(
    '''
SELECT id, entityType, entityId, operation, status, retryCount, createdAt, lastAttemptAt, errorMessage
FROM sync_queue
WHERE entityType = ?
ORDER BY createdAt ASC, id ASC
''',
    [_chequeEntityType],
  );

  await backupFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'dbPath': dbPath,
      'cheques': [
        for (final row in chequeRows)
          {
            'localId': row['id'],
            'serverUuid': row['server_uuid'],
            'chequeNumber': row['cheque_number'],
            'companyId': row['company_id'],
            'bankAccountId': row['bank_account_id'],
            'amount': row['amount_rial'],
            'issueDate': _fmtTs(row['issue_date']),
            'dueDate': _fmtTs(row['due_date']),
            'status': row['status'],
            'isRegisteredInSayad': _toBool(row['is_registered_in_sayad']),
            'sayadId': row['sayad_id'],
            'description': row['description'],
            'imageDataExists': row['image_data'] != null,
            'createdAt': _fmtTs(row['created_at']),
            'updatedAt': _fmtTs(row['updated_at']),
          },
      ],
      'chequeQueueItems': [
        for (final row in queueRows)
          {
            'queueId': row['id'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'status': row['status'],
            'retryCount': row['retryCount'],
            'createdAt': _fmtTs(row['createdAt']),
            'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
            'lastError': row['errorMessage'],
          },
      ],
    }),
  );

  return _BackupSummary(
    backupJsonPath: backupFile.path,
    exportedChequeCount: chequeRows.length,
    exportedQueueCount: queueRows.length,
  );
}

_AuditState _auditLocalState(Database db) {
  final totalCheques = _count(db, 'SELECT COUNT(*) AS total FROM cheques');
  final withServerUuid = _count(db, '''
SELECT COUNT(*) AS total
FROM cheques
WHERE server_uuid IS NOT NULL
  AND TRIM(server_uuid) != ''
''');
  final withoutServerUuid = _count(db, '''
SELECT COUNT(*) AS total
FROM cheques
WHERE server_uuid IS NULL
   OR TRIM(server_uuid) = ''
''');

  final unsyncedQueueRows = db.select(
    '''
SELECT id, entityId, operation, status, retryCount, createdAt, lastAttemptAt, errorMessage
FROM sync_queue
WHERE entityType = ?
  AND status IN ('PENDING', 'PROCESSING', 'FAILED')
ORDER BY createdAt ASC, id ASC
''',
    [_chequeEntityType],
  );

  final chequesWithoutUuid = db.select('''
SELECT id, server_uuid, cheque_number, company_id, bank_account_id, amount_rial, issue_date, due_date, status
FROM cheques
WHERE server_uuid IS NULL
   OR TRIM(server_uuid) = ''
ORDER BY id ASC
''');

  final failedQueueRows = db.select(
    '''
SELECT id, entityId, operation, retryCount, errorMessage, createdAt, lastAttemptAt
FROM sync_queue
WHERE entityType = ?
  AND status = 'FAILED'
ORDER BY createdAt DESC, id DESC
''',
    [_chequeEntityType],
  );

  return _AuditState(
    totalCheques: totalCheques,
    withServerUuid: withServerUuid,
    withoutServerUuid: withoutServerUuid,
    unsyncedQueueItems: [
      for (final row in unsyncedQueueRows)
        {
          'queueId': row['id'],
          'entityId': row['entityId'],
          'operation': row['operation'],
          'status': row['status'],
          'retryCount': row['retryCount'],
          'lastError': row['errorMessage'],
          'createdAt': _fmtTs(row['createdAt']),
          'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
        },
    ],
    chequesWithoutServerUuid: [
      for (final row in chequesWithoutUuid)
        {
          'localId': row['id'],
          'serverUuid': row['server_uuid'],
          'chequeNumber': row['cheque_number'],
          'companyId': row['company_id'],
          'bankAccountId': row['bank_account_id'],
          'amount': row['amount_rial'],
          'issueDate': _fmtTs(row['issue_date']),
          'dueDate': _fmtTs(row['due_date']),
          'status': row['status'],
        },
    ],
    failedQueueItems: [
      for (final row in failedQueueRows)
        {
          'queueId': row['id'],
          'entityId': row['entityId'],
          'operation': row['operation'],
          'retryCount': row['retryCount'],
          'lastError': row['errorMessage'],
          'createdAt': _fmtTs(row['createdAt']),
          'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
        },
    ],
  );
}

Future<List<_RemoteCheque>> _fetchRemoteCheques(_Options options) async {
  final uri = Uri.parse('${options.baseUrl}/cheques');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException(
      'Expected cheques endpoint to return a JSON list.',
    );
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteCheque.fromJson)
      .toList(growable: false);
}

Future<List<_RemoteCompany>> _fetchRemoteCompanies(_Options options) async {
  final uri = Uri.parse('${options.baseUrl}/companies');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException(
      'Expected companies endpoint to return a JSON list.',
    );
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
      .timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}: ${response.body}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException(
      'Expected bank-accounts endpoint to return a JSON list.',
    );
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteBankAccount.fromJson)
      .toList(growable: false);
}

List<_LocalCompany> _readLocalCompanies(Database db) {
  final rows = db.select('''
SELECT id, server_uuid, name, national_id, economic_code
FROM companies
ORDER BY id ASC
''');

  return rows.map(_LocalCompany.fromRow).toList(growable: false);
}

List<_LocalBankAccount> _readLocalBankAccounts(Database db) {
  final rows = db.select('''
SELECT id, server_uuid, bank_name, account_title, account_holder, account_number, card_number, iban
FROM bank_accounts
ORDER BY id ASC
''');

  return rows.map(_LocalBankAccount.fromRow).toList(growable: false);
}

List<_LocalCheque> _readLocalCheques(Database db) {
  final rows = db.select('''
SELECT id, company_id, bank_account_id, cheque_number, amount_rial, issue_date, due_date, sayad_id, status
FROM cheques
ORDER BY id ASC
''');

  return rows.map(_LocalCheque.fromRow).toList(growable: false);
}

Map<String, int> _lookupLocalIdsByUuid(
  Database db, {
  required String tableName,
}) {
  final rows = db.select('''
SELECT id, server_uuid
FROM $tableName
WHERE server_uuid IS NOT NULL
  AND TRIM(server_uuid) != ''
''');

  return {
    for (final row in rows)
      row['server_uuid'].toString().trim(): _toInt(row['id']),
  };
}

int? _resolveCompanyIdFallback({
  required _RemoteCompany? remoteCompany,
  required List<_LocalCompany> localCompanies,
}) {
  if (remoteCompany == null) {
    return null;
  }

  final exactUuid = localCompanies.where(
    (company) => company.serverUuid == remoteCompany.uuid,
  );
  if (exactUuid.length == 1) {
    return exactUuid.first.id;
  }

  final matchingByIdentity = localCompanies
      .where((company) {
        final sameNationalId =
            remoteCompany.nationalId != null &&
            remoteCompany.nationalId == company.nationalId;
        final sameEconomicCode =
            remoteCompany.economicCode != null &&
            remoteCompany.economicCode == company.economicCode;
        return sameNationalId || sameEconomicCode;
      })
      .toList(growable: false);

  if (matchingByIdentity.length == 1) {
    return matchingByIdentity.first.id;
  }

  final normalizedRemoteName = _normalizeName(remoteCompany.name);
  final matchingByName = localCompanies
      .where((company) {
        return _normalizeName(company.name) == normalizedRemoteName;
      })
      .toList(growable: false);

  if (matchingByName.length == 1) {
    return matchingByName.first.id;
  }

  return null;
}

int? _resolveBankAccountIdFallback({
  required _RemoteBankAccount? remoteBankAccount,
  required List<_LocalBankAccount> localBankAccounts,
}) {
  if (remoteBankAccount == null) {
    return null;
  }

  final exactUuid = localBankAccounts.where(
    (account) => account.serverUuid == remoteBankAccount.uuid,
  );
  if (exactUuid.length == 1) {
    return exactUuid.first.id;
  }

  final matchingByIdentity = localBankAccounts
      .where((account) {
        final sameIban =
            remoteBankAccount.iban != null &&
            remoteBankAccount.iban == account.iban;
        final sameAccountNumber =
            remoteBankAccount.accountNumber != null &&
            remoteBankAccount.accountNumber == account.accountNumber;
        final sameCardNumber =
            remoteBankAccount.cardNumber != null &&
            remoteBankAccount.cardNumber == account.cardNumber;
        return sameIban || sameAccountNumber || sameCardNumber;
      })
      .toList(growable: false);

  if (matchingByIdentity.length == 1) {
    return matchingByIdentity.first.id;
  }

  final matchingByName = localBankAccounts
      .where((account) {
        return _normalizeName(account.bankName) ==
                _normalizeName(remoteBankAccount.bankName ?? '') &&
            _normalizeName(account.accountTitle ?? '') ==
                _normalizeName(remoteBankAccount.accountTitle ?? '');
      })
      .toList(growable: false);

  if (matchingByName.length == 1) {
    return matchingByName.first.id;
  }

  return null;
}

int? _resolveDueDateFallback({
  required _RemoteCheque remoteCheque,
  required int localCompanyId,
  required int localBankAccountId,
  required List<_LocalCheque> localCheques,
}) {
  return _findMatchingLocalCheque(
    remoteCheque: remoteCheque,
    localCompanyId: localCompanyId,
    localBankAccountId: localBankAccountId,
    localCheques: localCheques,
  )?.dueDateMillis;
}

String? _resolveStatusFallback({
  required _RemoteCheque remoteCheque,
  required int localCompanyId,
  required int localBankAccountId,
  required List<_LocalCheque> localCheques,
}) {
  return _findMatchingLocalCheque(
    remoteCheque: remoteCheque,
    localCompanyId: localCompanyId,
    localBankAccountId: localBankAccountId,
    localCheques: localCheques,
  )?.status;
}

_LocalCheque? _findMatchingLocalCheque({
  required _RemoteCheque remoteCheque,
  required int localCompanyId,
  required int localBankAccountId,
  required List<_LocalCheque> localCheques,
}) {
  final normalizedSayadId = _trimOrNull(remoteCheque.sayadId);
  final candidates = localCheques
      .where((localCheque) {
        final sameSayadId =
            normalizedSayadId == null ||
            normalizedSayadId.isEmpty ||
            localCheque.sayadId == normalizedSayadId;

        return localCheque.companyId == localCompanyId &&
            localCheque.bankAccountId == localBankAccountId &&
            localCheque.chequeNumber == remoteCheque.chequeNumber &&
            localCheque.amountRial == remoteCheque.amount.toInt() &&
            _sameDay(localCheque.issueDateMillis, remoteCheque.chequeDate) &&
            sameSayadId;
      })
      .toList(growable: false);

  if (candidates.length == 1) {
    return candidates.first;
  }

  return null;
}

_ResetSummary _resetAndRebuild(Database db, List<_StagedCheque> staged) {
  var deletedChequeRows = 0;
  var deletedQueueRows = 0;
  var insertedChequeRows = 0;

  db.execute('BEGIN TRANSACTION');
  try {
    final deleteQueue = db.prepare(
      'DELETE FROM sync_queue WHERE entityType = :entityType',
    );
    try {
      deleteQueue.executeWith(
        StatementParameters.named({':entityType': _chequeEntityType}),
      );
      deletedQueueRows = _readChanges(db);
    } finally {
      deleteQueue.dispose();
    }

    final deleteCheques = db.prepare('DELETE FROM cheques');
    try {
      deleteCheques.execute();
      deletedChequeRows = _readChanges(db);
    } finally {
      deleteCheques.dispose();
    }

    final insert = db.prepare('''
INSERT INTO cheques (
  server_uuid,
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
  delete_requested_at,
  created_at,
  updated_at
) VALUES (
  :serverUuid,
  :companyId,
  :bankAccountId,
  :chequeNumber,
  :amountRial,
  :issueDate,
  :dueDate,
  :status,
  :isRegisteredInSayad,
  :sayadId,
  :receiverName,
  :description,
  :imageData,
  NULL,
  NULL,
  :createdAt,
  :updatedAt
)
''');
    try {
      for (final cheque in staged) {
        insert.executeWith(
          StatementParameters.named({
            ':serverUuid': cheque.serverUuid,
            ':companyId': cheque.companyId,
            ':bankAccountId': cheque.bankAccountId,
            ':chequeNumber': cheque.chequeNumber,
            ':amountRial': cheque.amountRial,
            ':issueDate': cheque.issueDateMillis,
            ':dueDate': cheque.dueDateMillis,
            ':status': cheque.status,
            ':isRegisteredInSayad': cheque.isRegisteredInSayad ? 1 : 0,
            ':sayadId': cheque.sayadId,
            ':receiverName': null,
            ':description': cheque.description,
            ':imageData': cheque.imageData,
            ':createdAt': cheque.createdAtMillis,
            ':updatedAt': cheque.updatedAtMillis,
          }),
        );
        insertedChequeRows++;
      }
    } finally {
      insert.dispose();
    }

    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }

  return _ResetSummary(
    deletedChequeRows: deletedChequeRows,
    deletedQueueRows: deletedQueueRows,
    insertedChequeRows: insertedChequeRows,
  );
}

Map<String, Object?> _verification(
  Database db,
  _AuditState afterState,
  List<_StagedCheque> staged,
) {
  final firstRow = db.select('SELECT id FROM cheques ORDER BY id ASC LIMIT 1');
  final detailsLoadWorks = firstRow.isEmpty
      ? true
      : _toInt(
              db.select('SELECT COUNT(*) AS total FROM cheques WHERE id = ?', [
                firstRow.first['id'],
              ]).first['total'],
            ) ==
            1;

  return {
    'chequeListLoadWorks': true,
    'chequeDetailsLoadWorks': detailsLoadWorks,
    'sayadRegisteredCount': _count(
      db,
      'SELECT COUNT(*) AS total FROM cheques WHERE is_registered_in_sayad = 1',
    ),
    'sayadIdCount': _count(db, '''
SELECT COUNT(*) AS total
FROM cheques
WHERE sayad_id IS NOT NULL
  AND TRIM(sayad_id) != ''
'''),
    'allChequesHaveServerUuid': afterState.withoutServerUuid == 0,
    'updateCanResolveUuid': afterState.withoutServerUuid == 0,
    'deleteCanResolveUuid': afterState.withoutServerUuid == 0,
    'rebuiltFromRemoteCount': staged.length,
  };
}

int _count(Database db, String sql, [List<Object?> params = const []]) {
  return _toInt(db.select(sql, params).first['total']);
}

int _readChanges(Database db) {
  return _count(db, 'SELECT changes() AS total');
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

bool _toBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value.toInt() != 0;
  if (value is String) {
    final trimmed = value.trim().toLowerCase();
    return trimmed == '1' || trimmed == 'true';
  }
  return false;
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
  }
  return null;
}

String _normalizeName(String value) {
  return value
      .trim()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

bool _sameDay(int localEpochMillis, DateTime remoteDate) {
  final localDate = DateTime.fromMillisecondsSinceEpoch(localEpochMillis);
  return localDate.year == remoteDate.year &&
      localDate.month == remoteDate.month &&
      localDate.day == remoteDate.day;
}

String? _fmtTs(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    final asEpoch = int.tryParse(trimmed);
    if (asEpoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(asEpoch).toIso8601String();
    }
    final asIso = DateTime.tryParse(trimmed);
    return asIso?.toIso8601String() ?? trimmed;
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toIso8601String();
  }
  return value.toString();
}

class _AuditState {
  const _AuditState({
    required this.totalCheques,
    required this.withServerUuid,
    required this.withoutServerUuid,
    required this.unsyncedQueueItems,
    required this.chequesWithoutServerUuid,
    required this.failedQueueItems,
  });

  final int totalCheques;
  final int withServerUuid;
  final int withoutServerUuid;
  final List<Map<String, Object?>> unsyncedQueueItems;
  final List<Map<String, Object?>> chequesWithoutServerUuid;
  final List<Map<String, Object?>> failedQueueItems;

  Map<String, Object?> toJson() {
    return {
      'currentChequeCount': totalCheques,
      'serverUuidNotNullCount': withServerUuid,
      'serverUuidNullCount': withoutServerUuid,
      'unsyncedChequeRecords': unsyncedQueueItems,
      'chequesWithoutServerUuid': chequesWithoutServerUuid,
      'chequeSyncFailures': failedQueueItems,
    };
  }
}

class _BackupSummary {
  const _BackupSummary({
    required this.backupJsonPath,
    required this.exportedChequeCount,
    required this.exportedQueueCount,
  });

  final String backupJsonPath;
  final int exportedChequeCount;
  final int exportedQueueCount;

  Map<String, Object?> toJson() {
    return {
      'backupJsonPath': backupJsonPath,
      'exportedChequeCount': exportedChequeCount,
      'exportedQueueCount': exportedQueueCount,
    };
  }
}

class _ResetSummary {
  const _ResetSummary({
    required this.deletedChequeRows,
    required this.deletedQueueRows,
    required this.insertedChequeRows,
  });

  final int deletedChequeRows;
  final int deletedQueueRows;
  final int insertedChequeRows;

  Map<String, Object?> toJson() {
    return {
      'deletedChequeRows': deletedChequeRows,
      'deletedQueueRows': deletedQueueRows,
      'insertedChequeRows': insertedChequeRows,
    };
  }
}

class _RemoteCheque {
  const _RemoteCheque({
    required this.serverUuid,
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
    required this.imageData,
    required this.createdAt,
    required this.updatedAt,
  });

  final String serverUuid;
  final String companyUuid;
  final String bankAccountUuid;
  final String chequeNumber;
  final num amount;
  final DateTime chequeDate;
  final DateTime? dueDate;
  final String? status;
  final bool? isRegisteredInSayad;
  final String? sayadId;
  final String? description;
  final Uint8List? imageData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory _RemoteCheque.fromJson(Map<String, dynamic> json) {
    return _RemoteCheque(
      serverUuid: (json['id'] ?? '').toString().trim(),
      companyUuid: (json['companyId'] ?? '').toString().trim(),
      bankAccountUuid: (json['bankAccountId'] ?? '').toString().trim(),
      chequeNumber: (json['chequeNumber'] ?? '').toString().trim(),
      amount: _readAmount(json['amount']),
      chequeDate: DateTime.parse(json['chequeDate'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      status: json['status']?.toString(),
      isRegisteredInSayad: json['isRegisteredInSayad'] as bool?,
      sayadId: json['sayadId']?.toString(),
      description: json['description']?.toString(),
      imageData: _decodeImage(json['imageData']),
      createdAt: _tryParseDate(json['createdAt']),
      updatedAt: _tryParseDate(json['updatedAt']),
    );
  }
}

class _RemoteCompany {
  const _RemoteCompany({
    required this.uuid,
    required this.name,
    required this.nationalId,
    required this.economicCode,
  });

  final String uuid;
  final String name;
  final String? nationalId;
  final String? economicCode;

  factory _RemoteCompany.fromJson(Map<String, dynamic> json) {
    return _RemoteCompany(
      uuid: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      nationalId: _trimOrNull(json['nationalId']?.toString()),
      economicCode: _trimOrNull(json['economicCode']?.toString()),
    );
  }
}

class _RemoteBankAccount {
  const _RemoteBankAccount({
    required this.uuid,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.cardNumber,
    required this.iban,
  });

  final String uuid;
  final String? bankName;
  final String? accountTitle;
  final String? accountNumber;
  final String? cardNumber;
  final String? iban;

  factory _RemoteBankAccount.fromJson(Map<String, dynamic> json) {
    return _RemoteBankAccount(
      uuid: (json['id'] ?? '').toString().trim(),
      bankName: _trimOrNull(json['bankName']?.toString()),
      accountTitle: _trimOrNull(json['accountTitle']?.toString()),
      accountNumber: _trimOrNull(json['accountNumber']?.toString()),
      cardNumber: _trimOrNull(json['cardNumber']?.toString()),
      iban: _trimOrNull((json['iban'] ?? json['shebaNumber'])?.toString()),
    );
  }
}

class _LocalCompany {
  const _LocalCompany({
    required this.id,
    required this.serverUuid,
    required this.name,
    required this.nationalId,
    required this.economicCode,
  });

  final int id;
  final String? serverUuid;
  final String name;
  final String? nationalId;
  final String? economicCode;

  factory _LocalCompany.fromRow(Map<String, Object?> row) {
    return _LocalCompany(
      id: _toInt(row['id']),
      serverUuid: _trimOrNull(row['server_uuid']?.toString()),
      name: row['name'].toString(),
      nationalId: _trimOrNull(row['national_id']?.toString()),
      economicCode: _trimOrNull(row['economic_code']?.toString()),
    );
  }
}

class _LocalBankAccount {
  const _LocalBankAccount({
    required this.id,
    required this.serverUuid,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.cardNumber,
    required this.iban,
  });

  final int id;
  final String? serverUuid;
  final String bankName;
  final String? accountTitle;
  final String? accountNumber;
  final String? cardNumber;
  final String? iban;

  factory _LocalBankAccount.fromRow(Map<String, Object?> row) {
    return _LocalBankAccount(
      id: _toInt(row['id']),
      serverUuid: _trimOrNull(row['server_uuid']?.toString()),
      bankName: row['bank_name'].toString(),
      accountTitle: _trimOrNull(row['account_title']?.toString()),
      accountNumber: _trimOrNull(row['account_number']?.toString()),
      cardNumber: _trimOrNull(row['card_number']?.toString()),
      iban: _trimOrNull(row['iban']?.toString()),
    );
  }
}

class _LocalCheque {
  const _LocalCheque({
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amountRial,
    required this.issueDateMillis,
    required this.dueDateMillis,
    required this.sayadId,
    required this.status,
  });

  final int companyId;
  final int bankAccountId;
  final String chequeNumber;
  final int amountRial;
  final int issueDateMillis;
  final int dueDateMillis;
  final String? sayadId;
  final String? status;

  factory _LocalCheque.fromRow(Map<String, Object?> row) {
    return _LocalCheque(
      companyId: _toInt(row['company_id']),
      bankAccountId: _toInt(row['bank_account_id']),
      chequeNumber: row['cheque_number'].toString().trim(),
      amountRial: _toInt(row['amount_rial']),
      issueDateMillis: _toInt(row['issue_date']),
      dueDateMillis: _toInt(row['due_date']),
      sayadId: _trimOrNull(row['sayad_id']?.toString()),
      status: _normalizeStatus(row['status']?.toString()),
    );
  }
}

class _StagedCheque {
  const _StagedCheque({
    required this.serverUuid,
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amountRial,
    required this.issueDateMillis,
    required this.dueDateMillis,
    required this.status,
    required this.isRegisteredInSayad,
    required this.sayadId,
    required this.description,
    required this.imageData,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  final String serverUuid;
  final int companyId;
  final int bankAccountId;
  final String chequeNumber;
  final int amountRial;
  final int issueDateMillis;
  final int dueDateMillis;
  final String status;
  final bool isRegisteredInSayad;
  final String? sayadId;
  final String? description;
  final Uint8List? imageData;
  final int createdAtMillis;
  final int updatedAtMillis;
}

num _readAmount(Object? raw) {
  if (raw is num) return raw;
  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '');
    final parsed = num.tryParse(normalized);
    if (parsed != null) return parsed;
  }
  return 0;
}

Uint8List? _decodeImage(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    return base64Decode(trimmed);
  } catch (_) {
    return null;
  }
}

DateTime? _tryParseDate(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
