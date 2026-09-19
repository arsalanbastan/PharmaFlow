import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

const _defaultHost = '192.168.1.215';
const _defaultPort = 3000;
const _defaultApiVersion = 'v1';

Future<void> main(List<String> args) async {
  final options = _Options.fromArgs(args);
  final dbPath = options.dbPath;
  if (dbPath == null || dbPath.isEmpty) {
    stderr.writeln('Missing --db-path=<path>.');
    exitCode = 1;
    return;
  }

  if (!File(dbPath).existsSync()) {
    stderr.writeln('Database file does not exist: $dbPath');
    exitCode = 1;
    return;
  }

  final db = sqlite3.open(dbPath);
  try {
    _assertRequiredTables(db);

    final remoteCheques = await _fetchRemoteCheques(options.baseUrl);
    final remoteByComposite = _buildRemoteIndex(remoteCheques);

    final localRows = _readLocalRowsNeedingBackfill(db);
    final companyUuidById = _readUuidByLocalId(db, 'companies');
    final bankUuidById = _readUuidByLocalId(db, 'bank_accounts');

    var repaired = 0;
    final unmatched = <Map<String, Object?>>[];
    final repairedRows = <Map<String, Object?>>[];

    db.execute('BEGIN TRANSACTION');
    try {
      final updateStmt = db.prepare('''
UPDATE cheques
SET server_uuid = :serverUuid
WHERE id = :id
''');
      try {
        for (final row in localRows) {
          final localId = row.localId;
          final existing = row.serverUuid?.trim();
          if (existing != null && existing.isNotEmpty) {
            continue;
          }

          final companyUuid = companyUuidById[row.companyId]?.trim();
          final bankUuid = bankUuidById[row.bankAccountId]?.trim();

          if (companyUuid == null || companyUuid.isEmpty) {
            unmatched.add({
              'localId': localId,
              'reason': 'Local company has no server_uuid.',
              'chequeNumber': row.chequeNumber,
              'companyId': row.companyId,
              'bankAccountId': row.bankAccountId,
            });
            continue;
          }

          if (bankUuid == null || bankUuid.isEmpty) {
            unmatched.add({
              'localId': localId,
              'reason': 'Local bank account has no server_uuid.',
              'chequeNumber': row.chequeNumber,
              'companyId': row.companyId,
              'bankAccountId': row.bankAccountId,
            });
            continue;
          }

          final key = _CompositeKey(
            chequeNumber: row.chequeNumber.trim(),
            companyUuid: companyUuid,
            bankAccountUuid: bankUuid,
            amountRial: row.amountRial,
            dueDateYmd: _toYmd(row.dueDate),
          );

          final candidates = remoteByComposite[key] ?? const <_RemoteCheque>[];
          if (candidates.isEmpty) {
            unmatched.add({
              'localId': localId,
              'reason':
                  'No backend cheque matched chequeNumber+bankAccount+company+amount+dueDate.',
              'chequeNumber': row.chequeNumber,
              'companyId': row.companyId,
              'bankAccountId': row.bankAccountId,
              'amountRial': row.amountRial,
              'dueDate': row.dueDate.toIso8601String(),
            });
            continue;
          }

          if (candidates.length > 1) {
            unmatched.add({
              'localId': localId,
              'reason':
                  'Multiple backend cheques matched chequeNumber+bankAccount+company+amount+dueDate.',
              'candidateCount': candidates.length,
              'chequeNumber': row.chequeNumber,
              'companyId': row.companyId,
              'bankAccountId': row.bankAccountId,
              'amountRial': row.amountRial,
              'dueDate': row.dueDate.toIso8601String(),
            });
            continue;
          }

          final matched = candidates.first;
          updateStmt.executeWith(
            StatementParameters.named({
              ':id': localId,
              ':serverUuid': matched.id,
            }),
          );
          repaired++;
          repairedRows.add({
            'localId': localId,
            'serverUuid': matched.id,
            'chequeNumber': row.chequeNumber,
          });
        }
      } finally {
        updateStmt.dispose();
      }

      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }

    final totals = _auditCounts(db);
    final sample20 = _readUuidSample(db, 20);

    final result = {
      'dbPath': dbPath,
      'backendBaseUrl': options.baseUrl,
      'totals': totals,
      'rowsRepaired': repaired,
      'unmatchedCount': unmatched.length,
      'unmatchedRows': unmatched,
      'repairedRows': repairedRows,
      'uuidSample20': sample20,
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(result);
    if (options.outputPath != null && options.outputPath!.isNotEmpty) {
      File(options.outputPath!).writeAsStringSync(jsonText, encoding: utf8);
    }
    stdout.writeln(jsonText);
  } finally {
    db.dispose();
  }
}

void _assertRequiredTables(Database db) {
  for (final table in const ['cheques', 'companies', 'bank_accounts']) {
    final rows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
      [table],
    );
    if (rows.isEmpty) {
      throw StateError('Required table not found: $table');
    }
  }
}

Future<List<_RemoteCheque>> _fetchRemoteCheques(String baseUrl) async {
  final uri = Uri.parse('$baseUrl/cheques');
  final response = await http
      .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
      .timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw HttpException(
      'GET $uri failed with status ${response.statusCode}',
      uri: uri,
    );
  }

  final payload = jsonDecode(response.body);
  if (payload is! List) {
    throw const FormatException('Expected /cheques to return a JSON array.');
  }

  return payload
      .whereType<Map<String, dynamic>>()
      .map(_RemoteCheque.fromJson)
      .where((row) => row.id.isNotEmpty)
      .toList(growable: false);
}

Map<_CompositeKey, List<_RemoteCheque>> _buildRemoteIndex(
  List<_RemoteCheque> rows,
) {
  final index = <_CompositeKey, List<_RemoteCheque>>{};
  for (final row in rows) {
    final key = _CompositeKey(
      chequeNumber: row.chequeNumber.trim(),
      companyUuid: row.companyId.trim(),
      bankAccountUuid: row.bankAccountId.trim(),
      amountRial: row.amount.toInt(),
      dueDateYmd: _toYmd(row.dueDate),
    );
    index.putIfAbsent(key, () => <_RemoteCheque>[]).add(row);
  }
  return index;
}

Map<int, String> _readUuidByLocalId(Database db, String table) {
  final rows = db.select('''
SELECT id, server_uuid
FROM $table
WHERE server_uuid IS NOT NULL
  AND TRIM(server_uuid) != ''
''');

  final result = <int, String>{};
  for (final row in rows) {
    result[_toInt(row['id'])] = (row['server_uuid'] as String).trim();
  }
  return result;
}

List<_LocalChequeRow> _readLocalRowsNeedingBackfill(Database db) {
  final rows = db.select('''
SELECT id, server_uuid, cheque_number, company_id, bank_account_id, amount_rial, due_date
FROM cheques
WHERE server_uuid IS NULL OR TRIM(server_uuid) = ''
ORDER BY id ASC
''');

  return rows.map(_LocalChequeRow.fromRow).toList(growable: false);
}

Map<String, int> _auditCounts(Database db) {
  int count(String sql) => _toInt(db.select(sql).first['total']);
  return {
    'totalCheques': count('SELECT COUNT(*) AS total FROM cheques'),
    'serverUuidPopulated': count('''
SELECT COUNT(*) AS total
FROM cheques
WHERE server_uuid IS NOT NULL
  AND TRIM(server_uuid) != ''
'''),
    'serverUuidMissing': count('''
SELECT COUNT(*) AS total
FROM cheques
WHERE server_uuid IS NULL
   OR TRIM(server_uuid) = ''
'''),
  };
}

List<Map<String, Object?>> _readUuidSample(Database db, int take) {
  final rows = db.select(
    '''
SELECT id, cheque_number, server_uuid
FROM cheques
WHERE server_uuid IS NOT NULL
  AND TRIM(server_uuid) != ''
ORDER BY RANDOM()
LIMIT ?
''',
    [take],
  );

  return [
    for (final row in rows)
      {
        'id': row['id'],
        'chequeNumber': row['cheque_number'],
        'serverUuid': row['server_uuid'],
        'isValidUuid': _isUuidV4Like((row['server_uuid'] as String?) ?? ''),
      },
  ];
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

DateTime _toDateTime(Object? raw) {
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  if (raw is String) {
    final t = raw.trim();
    final epoch = int.tryParse(t);
    if (epoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    final parsed = DateTime.tryParse(t);
    if (parsed != null) {
      return parsed;
    }
  }
  throw ArgumentError('Unsupported date payload: $raw');
}

String _toYmd(DateTime dt) {
  final local = dt.toUtc();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

bool _isUuidV4Like(String value) {
  final v = value.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(v);
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
    String? outputPath;
    var host = _defaultHost;
    var port = _defaultPort;
    var useHttps = false;
    var apiVersion = _defaultApiVersion;

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
        final parsed = int.tryParse(arg.substring('--port='.length).trim());
        if (parsed != null) {
          port = parsed;
        }
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

class _RemoteCheque {
  const _RemoteCheque({
    required this.id,
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amount,
    required this.dueDate,
  });

  final String id;
  final String companyId;
  final String bankAccountId;
  final String chequeNumber;
  final num amount;
  final DateTime dueDate;

  factory _RemoteCheque.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final companyId = (json['companyId'] ?? '').toString().trim();
    final bankAccountId = (json['bankAccountId'] ?? '').toString().trim();
    final chequeNumber = (json['chequeNumber'] ?? '').toString().trim();
    final amount = _parseNum(json['amount']);
    final dueRaw = json['dueDate'];
    final dueDate = dueRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.parse(dueRaw.toString());

    return _RemoteCheque(
      id: id,
      companyId: companyId,
      bankAccountId: bankAccountId,
      chequeNumber: chequeNumber,
      amount: amount,
      dueDate: dueDate,
    );
  }

  static num _parseNum(Object? raw) {
    if (raw is num) {
      return raw;
    }
    if (raw is String) {
      final parsed = num.tryParse(raw.trim().replaceAll(',', ''));
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }
}

class _LocalChequeRow {
  const _LocalChequeRow({
    required this.localId,
    required this.serverUuid,
    required this.chequeNumber,
    required this.companyId,
    required this.bankAccountId,
    required this.amountRial,
    required this.dueDate,
  });

  final int localId;
  final String? serverUuid;
  final String chequeNumber;
  final int companyId;
  final int bankAccountId;
  final int amountRial;
  final DateTime dueDate;

  factory _LocalChequeRow.fromRow(Map<String, Object?> row) {
    return _LocalChequeRow(
      localId: _toInt(row['id']),
      serverUuid: row['server_uuid'] as String?,
      chequeNumber: (row['cheque_number'] as String? ?? '').trim(),
      companyId: _toInt(row['company_id']),
      bankAccountId: _toInt(row['bank_account_id']),
      amountRial: _toInt(row['amount_rial']),
      dueDate: _toDateTime(row['due_date']),
    );
  }
}

class _CompositeKey {
  const _CompositeKey({
    required this.chequeNumber,
    required this.companyUuid,
    required this.bankAccountUuid,
    required this.amountRial,
    required this.dueDateYmd,
  });

  final String chequeNumber;
  final String companyUuid;
  final String bankAccountUuid;
  final int amountRial;
  final String dueDateYmd;

  @override
  bool operator ==(Object other) {
    return other is _CompositeKey &&
        other.chequeNumber == chequeNumber &&
        other.companyUuid == companyUuid &&
        other.bankAccountUuid == bankAccountUuid &&
        other.amountRial == amountRial &&
        other.dueDateYmd == dueDateYmd;
  }

  @override
  int get hashCode {
    return Object.hash(
      chequeNumber,
      companyUuid,
      bankAccountUuid,
      amountRial,
      dueDateYmd,
    );
  }
}
