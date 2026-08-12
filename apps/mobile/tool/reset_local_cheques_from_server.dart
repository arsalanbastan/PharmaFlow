import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharmaflow/core/config/app_config.dart';
import 'package:pharmaflow/core/config/app_environment.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/queries/cheque_queries.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/network/api_constants.dart';
import 'package:pharmaflow/core/settings/connection_settings_repository.dart';
import 'package:pharmaflow/data/models/bank_account.dart';
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:sqlite3/sqlite3.dart';

const _chequeEntityType = 'CHEQUE';
const _queueStatuses = ['PENDING', 'PROCESSING', 'SYNCED', 'FAILED'];
const _validStatuses = {'Issued', 'Registered', 'Cancelled'};

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();

  final auditOnly = args.contains('--audit-only');
  final databaseService = DatabaseService.instance;
  final db = databaseService.database;
  final dbPath = await _resolveDbPath();

  final beforeState = _auditLocalState(db);

  if (auditOnly) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'mode': 'audit-only',
        'dbPath': dbPath,
        'beforeState': beforeState.toJson(),
      }),
    );
    return;
  }

  final backup = await _createBackup(db, dbPath: dbPath);

  final settingsRepository = ConnectionSettingsRepository();
  final settings = await settingsRepository.load();
  final apiClient = ApiClient(
    appConfig: AppConfig(
      currentEnvironment: AppEnvironment.development,
      settings: settings,
    ),
  );

  final localCompanyRepository = LocalCompanyRepository(databaseService);
  final localBankAccountRepository = LocalBankAccountRepository(
    databaseService,
  );

  final remoteCheques = await _fetchRemoteCheques(apiClient);
  final localCompanies = await localCompanyRepository.getAll(
    includeArchived: true,
  );
  final localBankAccounts = await localBankAccountRepository.getAll(
    includeArchived: true,
  );

  final companyIdByUuid = _companyIdByUuid(localCompanies);
  final bankAccountIdByUuid = _bankAccountIdByUuid(localBankAccounts);

  final staged = <_StagedCheque>[];
  final remainingIssues = <String>[];

  for (final remote in remoteCheques) {
    final serverUuid = remote.serverUuid.trim();
    if (serverUuid.isEmpty) {
      remainingIssues.add(
        'Remote cheque with chequeNumber=${remote.chequeNumber} has empty UUID.',
      );
      continue;
    }

    final localCompanyId = companyIdByUuid[remote.companyUuid];
    if (localCompanyId == null) {
      remainingIssues.add(
        'Remote cheque $serverUuid references unknown local company UUID ${remote.companyUuid}.',
      );
      continue;
    }

    final localBankAccountId = bankAccountIdByUuid[remote.bankAccountUuid];
    if (localBankAccountId == null) {
      remainingIssues.add(
        'Remote cheque $serverUuid references unknown local bank account UUID ${remote.bankAccountUuid}.',
      );
      continue;
    }

    final dueDate = remote.dueDate;
    if (dueDate == null) {
      remainingIssues.add(
        'Remote cheque $serverUuid has null dueDate and cannot be stored in local schema.',
      );
      continue;
    }

    final status = _normalizeStatus(remote.status);
    if (status == null) {
      remainingIssues.add(
        'Remote cheque $serverUuid has unsupported status ${remote.status}.',
      );
      continue;
    }

    staged.add(
      _StagedCheque(
        serverUuid: serverUuid,
        companyId: localCompanyId,
        bankAccountId: localBankAccountId,
        chequeNumber: remote.chequeNumber,
        amountRial: remote.amount.toInt(),
        issueDateMillis: remote.chequeDate.millisecondsSinceEpoch,
        dueDateMillis: dueDate.millisecondsSinceEpoch,
        status: status,
        isRegisteredInSayad: remote.isRegisteredInSayad ?? false,
        sayadId: _trimOrNull(remote.sayadId),
        receiverName: _trimOrNull(remote.receiverName),
        description: _trimOrNull(remote.description),
        imageData: remote.imageData,
        imageDataExists: remote.imageData != null,
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
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'mode': 'aborted',
        'dbPath': dbPath,
        'beforeState': beforeState.toJson(),
        'backup': backup.toJson(),
        'remainingIssues': remainingIssues,
      }),
    );
    return;
  }

  final resetSummary = _resetAndRebuild(db, staged);
  final afterState = _auditLocalState(db);

  final verification = _verifyAfterState(
    db: db,
    afterState: afterState,
    staged: staged,
  );

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'mode': 'full-reset',
      'dbPath': dbPath,
      'beforeState': beforeState.toJson(),
      'actionsPerformed': {
        'backup': backup.toJson(),
        'resetSummary': resetSummary.toJson(),
      },
      'afterState': {...afterState.toJson(), 'verification': verification},
      'remainingIssues': remainingIssues,
    }),
  );
}

Future<String> _resolveDbPath() async {
  final documents = await getApplicationDocumentsDirectory();
  return p.join(documents.path, 'pharmaflow.db');
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

  final queueByStatus = <String, int>{
    for (final status in _queueStatuses)
      status: _count(
        db,
        '''
SELECT COUNT(*) AS total
FROM sync_queue
WHERE entityType = ?
  AND status = ?
''',
        [_chequeEntityType, status],
      ),
  };

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
SELECT id, server_uuid, cheque_number, company_id, bank_account_id, amount_rial, issue_date, due_date, status, is_registered_in_sayad, sayad_id, delete_requested_at
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
    queueByStatus: queueByStatus,
    unsyncedQueueItems: unsyncedQueueRows
        .map(
          (row) => {
            'queueId': row['id'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'status': row['status'],
            'retryCount': row['retryCount'],
            'lastError': row['errorMessage'],
            'createdAt': _fmtTs(row['createdAt']),
            'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
          },
        )
        .toList(growable: false),
    chequesWithoutServerUuid: chequesWithoutUuid
        .map(
          (row) => {
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
            'deleteRequestedAt': _fmtTs(row['delete_requested_at']),
          },
        )
        .toList(growable: false),
    failedQueueItems: failedQueueRows
        .map(
          (row) => {
            'queueId': row['id'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'retryCount': row['retryCount'],
            'lastError': row['errorMessage'],
            'createdAt': _fmtTs(row['createdAt']),
            'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
          },
        )
        .toList(growable: false),
  );
}

Future<_BackupSummary> _createBackup(
  Database db, {
  required String dbPath,
}) async {
  final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final backupDir = Directory(
    p.join('d:\\Projects\\PharmaFlow\\apps\\mobile', 'tool', 'backups'),
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
       description, image_data, archived_at, delete_requested_at, created_at, updated_at
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
            'archivedAt': _fmtTs(row['archived_at']),
            'deleteRequestedAt': _fmtTs(row['delete_requested_at']),
            'createdAt': _fmtTs(row['created_at']),
            'updatedAt': _fmtTs(row['updated_at']),
          },
      ],
      'chequeQueueItems': [
        for (final row in queueRows)
          {
            'queueId': row['id'],
            'entityType': row['entityType'],
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

Future<List<_RemoteCheque>> _fetchRemoteCheques(ApiClient apiClient) async {
  final payload = await apiClient.get(ApiConstants.chequesEndpoint);
  if (payload is! List) {
    throw const ApiDecodingException(
      'Expected cheques endpoint to return a JSON list.',
    );
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteCheque.fromJson)
      .toList(growable: false);
}

Map<String, int> _companyIdByUuid(List<Company> companies) {
  final map = <String, int>{};
  for (final company in companies) {
    final id = company.id;
    final uuid = _trimOrNull(company.serverUuid);
    if (id != null && uuid != null) {
      map[uuid] = id;
    }
  }
  return map;
}

Map<String, int> _bankAccountIdByUuid(List<BankAccount> accounts) {
  final map = <String, int>{};
  for (final account in accounts) {
    final id = account.id;
    final uuid = _trimOrNull(account.serverUuid);
    if (id != null && uuid != null) {
      map[uuid] = id;
    }
  }
  return map;
}

_ResetSummary _resetAndRebuild(Database db, List<_StagedCheque> staged) {
  var deletedChequeRows = 0;
  var deletedQueueRows = 0;
  var insertedChequeRows = 0;

  db.execute('BEGIN TRANSACTION');
  try {
    final deleteQueueStatement = db.prepare(
      'DELETE FROM sync_queue WHERE entityType = :entityType',
    );
    try {
      deleteQueueStatement.executeWith(
        StatementParameters.named({':entityType': _chequeEntityType}),
      );
      deletedQueueRows = _readChanges(db);
    } finally {
      deleteQueueStatement.dispose();
    }

    final deleteChequeStatement = db.prepare('DELETE FROM cheques');
    try {
      deleteChequeStatement.execute();
      deletedChequeRows = _readChanges(db);
    } finally {
      deleteChequeStatement.dispose();
    }

    final insertStatement = db.prepare(ChequeQueries.insert);
    try {
      for (final cheque in staged) {
        insertStatement.executeWith(
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
            ':receiverName': cheque.receiverName,
            ':description': cheque.description,
            ':imageData': cheque.imageData,
            ':archivedAt': null,
            ':deleteRequestedAt': null,
            ':createdAt': cheque.createdAtMillis,
            ':updatedAt': cheque.updatedAtMillis,
          }),
        );
        insertedChequeRows++;
      }
    } finally {
      insertStatement.dispose();
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

Map<String, Object?> _verifyAfterState({
  required Database db,
  required _AuditState afterState,
  required List<_StagedCheque> staged,
}) {
  final listLoadCount = db
      .select('SELECT COUNT(*) AS total FROM cheques')
      .first['total'];
  final firstRow = db.select('SELECT id FROM cheques ORDER BY id ASC LIMIT 1');
  final firstDetailsLoadOk = firstRow.isEmpty
      ? true
      : _findChequeDetailsRow(db, _toInt(firstRow.first['id']));

  final registeredCount = _count(
    db,
    'SELECT COUNT(*) AS total FROM cheques WHERE is_registered_in_sayad = 1',
  );
  final sayadIdCount = _count(db, '''
SELECT COUNT(*) AS total
FROM cheques
WHERE sayad_id IS NOT NULL
  AND TRIM(sayad_id) != ''
''');

  return {
    'chequeListLoadWorks': true,
    'chequeDetailsLoadWorks': firstDetailsLoadOk,
    'sayadRegisteredCount': registeredCount,
    'sayadIdCount': sayadIdCount,
    'allChequesHaveServerUuid': afterState.withoutServerUuid == 0,
    'updateCanResolveUuid': afterState.withoutServerUuid == 0,
    'deleteCanResolveUuid': afterState.withoutServerUuid == 0,
    'loadedChequeCount': listLoadCount,
    'rebuiltFromRemoteCount': staged.length,
  };
}

bool _findChequeDetailsRow(Database db, int id) {
  final statement = db.prepare(ChequeQueries.findById);
  try {
    final rows = statement.selectWith(StatementParameters.named({':id': id}));
    return rows.isNotEmpty;
  } finally {
    statement.dispose();
  }
}

int _count(Database db, String sql, [List<Object?> params = const []]) {
  final rows = db.select(sql, params);
  return _toInt(rows.first['total']);
}

int _readChanges(Database db) {
  return _toInt(db.select('SELECT changes() AS total').first['total']);
}

int _toInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }

  return 0;
}

bool _toBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value.toInt() != 0;
  }

  if (value is String) {
    final trimmed = value.trim().toLowerCase();
    return trimmed == '1' || trimmed == 'true';
  }

  return false;
}

String? _trimOrNull(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizeStatus(String? raw) {
  final trimmed = _trimOrNull(raw);
  if (trimmed == null) {
    return null;
  }

  if (_validStatuses.contains(trimmed)) {
    return trimmed;
  }

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

String? _fmtTs(Object? value) {
  if (value == null) {
    return null;
  }

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
    required this.queueByStatus,
    required this.unsyncedQueueItems,
    required this.chequesWithoutServerUuid,
    required this.failedQueueItems,
  });

  final int totalCheques;
  final int withServerUuid;
  final int withoutServerUuid;
  final Map<String, int> queueByStatus;
  final List<Map<String, Object?>> unsyncedQueueItems;
  final List<Map<String, Object?>> chequesWithoutServerUuid;
  final List<Map<String, Object?>> failedQueueItems;

  Map<String, Object?> toJson() {
    return {
      'currentChequeCount': totalCheques,
      'serverUuidNotNullCount': withServerUuid,
      'serverUuidNullCount': withoutServerUuid,
      'chequeQueueByStatus': queueByStatus,
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
    required this.receiverName,
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
  final String? receiverName;
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
      receiverName: json['receiverName']?.toString(),
      description: json['description']?.toString(),
      imageData: _decodeImage(json['imageData']),
      createdAt: _tryParseDate(json['createdAt']),
      updatedAt: _tryParseDate(json['updatedAt']),
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
    required this.receiverName,
    required this.description,
    required this.imageData,
    required this.imageDataExists,
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
  final String? receiverName;
  final String? description;
  final Uint8List? imageData;
  final bool imageDataExists;
  final int createdAtMillis;
  final int updatedAtMillis;
}

num _readAmount(Object? raw) {
  if (raw is num) {
    return raw;
  }

  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '');
    final parsed = num.tryParse(normalized);
    if (parsed != null) {
      return parsed;
    }
  }

  return 0;
}

Uint8List? _decodeImage(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return base64Decode(trimmed);
    } catch (_) {
      return null;
    }
  }

  return null;
}

DateTime? _tryParseDate(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}
