import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.length < 2) {
    print(
      'Usage: dart run tool/query_cheques_ids.dart <dbPath> <commaSeparatedIds>',
    );
    return;
  }

  final db = sqlite3.open(args[0]);
  try {
    final ids = args[1]
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList(growable: false);

    final rows = <Map<String, Object?>>[];
    for (final id in ids) {
      final stmt = db.prepare('''
SELECT id, server_uuid, delete_requested_at, updated_at
FROM cheques
WHERE id = :id
LIMIT 1;
''');
      final r = stmt.selectWith(StatementParameters.named({':id': id}));
      stmt.dispose();
      if (r.isNotEmpty) {
        rows.add({
          'id': r.first['id'],
          'serverUuid': r.first['server_uuid'],
          'deleteRequestedAt': r.first['delete_requested_at'],
          'updatedAt': r.first['updated_at'],
        });
      }
    }

    print(const JsonEncoder.withIndent('  ').convert({'rows': rows}));
  } finally {
    db.dispose();
  }
}
