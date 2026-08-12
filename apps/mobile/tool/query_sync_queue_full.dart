import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

String fmtTs(Object? value) {
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
  if (args.isEmpty) {
    print('Usage: dart run tool/query_sync_queue_full.dart <dbPath>');
    return;
  }

  final db = sqlite3.open(args.first);
  try {
    final rows = db.select('''
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
ORDER BY id;
''');

    final grouped = db.select('''
SELECT status, COUNT(*) AS total
FROM sync_queue
GROUP BY status
ORDER BY status;
''');

    final result = {
      'allRows': [
        for (final row in rows)
          {
            'id': row['id'],
            'entityType': row['entityType'],
            'entityId': row['entityId'],
            'operation': row['operation'],
            'status': row['status'],
            'retryCount': row['retryCount'],
            'lastError': row['errorMessage'],
            'createdAt': fmtTs(row['createdAt']),
            'updatedAt': fmtTs(row['lastAttemptAt']),
          },
      ],
      'counts': [
        for (final row in grouped)
          {'status': row['status'], 'total': row['total']},
      ],
    };

    print(const JsonEncoder.withIndent('  ').convert(result));
  } finally {
    db.dispose();
  }
}
