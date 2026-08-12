import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

String _fmtTs(Object? value) {
  if (value == null) return 'null';
  final millis = value is int
      ? value
      : value is num
      ? value.toInt()
      : int.tryParse(value.toString()) ?? 0;
  if (millis <= 0) return millis.toString();
  return DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
}

void main(List<String> args) {
  final dbPath = args.isNotEmpty ? args.first : 'pharmaflow.db';
  final db = sqlite3.open(dbPath);
  try {
    final tableCheck = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sync_queue' LIMIT 1;",
    );
    if (tableCheck.isEmpty) {
      print(
        jsonEncode({'dbPath': dbPath, 'error': 'sync_queue table not found'}),
      );
      return;
    }

    final counts = db.select('''
SELECT status, COUNT(*) AS total
FROM sync_queue
GROUP BY status
ORDER BY status;
''');

    final failedItems = db.select('''
SELECT
  id,
  entityType,
  entityId,
  operation,
  status,
  retryCount,
  errorMessage,
  createdAt,
  lastAttemptAt
FROM sync_queue
WHERE status = 'FAILED'
ORDER BY createdAt ASC, id ASC;
''');

    final analysis = <Map<String, Object?>>[];

    for (final row in failedItems) {
      final entityType = row['entityType'] as String;
      final entityId = row['entityId'] as int;
      final createdAt = row['createdAt'] as int;
      final operation = row['operation'] as String;

      final newerSyncedStmt = db.prepare('''
SELECT id, operation, createdAt
FROM sync_queue
WHERE entityType = :entityType
  AND entityId = :entityId
  AND status = 'SYNCED'
  AND createdAt > :createdAt
ORDER BY createdAt DESC, id DESC
LIMIT 1;
''');
      final newerSynced = newerSyncedStmt.selectWith(
        StatementParameters.named({
          ':entityType': entityType,
          ':entityId': entityId,
          ':createdAt': createdAt,
        }),
      );
      newerSyncedStmt.dispose();

      final newerUnsyncedStmt = db.prepare('''
SELECT id, status, operation, createdAt
FROM sync_queue
WHERE entityType = :entityType
  AND entityId = :entityId
  AND createdAt > :createdAt
  AND status IN ('PENDING', 'FAILED', 'PROCESSING')
ORDER BY createdAt DESC, id DESC
LIMIT 1;
''');
      final anyPendingOrFailedNewer = newerUnsyncedStmt.selectWith(
        StatementParameters.named({
          ':entityType': entityType,
          ':entityId': entityId,
          ':createdAt': createdAt,
        }),
      );
      newerUnsyncedStmt.dispose();

      Map<String, Object?>? entitySnapshot;
      if (entityType == 'CHEQUE') {
        final entityStmt = db.prepare('''
SELECT id, server_uuid, is_registered_in_sayad, delete_requested_at, updated_at
FROM cheques
WHERE id = :id
LIMIT 1;
''');
        final entity = entityStmt.selectWith(
          StatementParameters.named({':id': entityId}),
        );
        entityStmt.dispose();
        if (entity.isNotEmpty) {
          entitySnapshot = {
            'id': entity.first['id'],
            'serverUuid': entity.first['server_uuid'],
            'isRegisteredInSayad': entity.first['is_registered_in_sayad'],
            'deleteRequestedAt': entity.first['delete_requested_at'],
            'updatedAt': entity.first['updated_at'],
          };
        }
      }

      analysis.add({
        'failedQueueId': row['id'],
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'createdAt': createdAt,
        'newerSynced': newerSynced.isNotEmpty
            ? {
                'id': newerSynced.first['id'],
                'operation': newerSynced.first['operation'],
                'createdAt': newerSynced.first['createdAt'],
              }
            : null,
        'newerUnsynced': anyPendingOrFailedNewer.isNotEmpty
            ? {
                'id': anyPendingOrFailedNewer.first['id'],
                'status': anyPendingOrFailedNewer.first['status'],
                'operation': anyPendingOrFailedNewer.first['operation'],
                'createdAt': anyPendingOrFailedNewer.first['createdAt'],
              }
            : null,
        'entitySnapshot': entitySnapshot,
      });
    }

    final output = {
      'dbPath': dbPath,
      'counts': [
        for (final row in counts)
          {'status': row['status'], 'total': row['total']},
      ],
      'failedItems': [
        for (final row in failedItems)
          {
            'id': row['id'],
            'entityType': row['entityType'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'status': row['status'],
            'retryCount': row['retryCount'],
            'lastError': row['errorMessage'],
            'createdAt': _fmtTs(row['createdAt']),
            'lastAttemptAt': _fmtTs(row['lastAttemptAt']),
          },
      ],
      'analysis': [
        for (final row in analysis)
          {
            'failedQueueId': row['failedQueueId'],
            'entityType': row['entityType'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'failedCreatedAt': _fmtTs(row['createdAt']),
            'newerSynced': row['newerSynced'] == null
                ? null
                : {
                    'id': (row['newerSynced'] as Map<String, Object?>)['id'],
                    'operation':
                        (row['newerSynced']
                            as Map<String, Object?>)['operation'],
                    'createdAt': _fmtTs(
                      (row['newerSynced'] as Map<String, Object?>)['createdAt'],
                    ),
                  },
            'newerUnsynced': row['newerUnsynced'] == null
                ? null
                : {
                    'id': (row['newerUnsynced'] as Map<String, Object?>)['id'],
                    'status':
                        (row['newerUnsynced']
                            as Map<String, Object?>)['status'],
                    'operation':
                        (row['newerUnsynced']
                            as Map<String, Object?>)['operation'],
                    'createdAt': _fmtTs(
                      (row['newerUnsynced']
                          as Map<String, Object?>)['createdAt'],
                    ),
                  },
            'entitySnapshot': row['entitySnapshot'] == null
                ? null
                : {
                    'id': (row['entitySnapshot'] as Map<String, Object?>)['id'],
                    'serverUuid':
                        (row['entitySnapshot']
                            as Map<String, Object?>)['serverUuid'],
                    'isRegisteredInSayad':
                        (row['entitySnapshot']
                            as Map<String, Object?>)['isRegisteredInSayad'],
                    'deleteRequestedAt': _fmtTs(
                      (row['entitySnapshot']
                          as Map<String, Object?>)['deleteRequestedAt'],
                    ),
                    'updatedAt': _fmtTs(
                      (row['entitySnapshot']
                          as Map<String, Object?>)['updatedAt'],
                    ),
                  },
          },
      ],
    };

    print(const JsonEncoder.withIndent('  ').convert(output));
  } finally {
    db.dispose();
  }
}
