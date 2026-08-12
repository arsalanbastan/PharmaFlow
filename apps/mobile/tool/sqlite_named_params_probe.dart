import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.openInMemory();
  db.execute(
    'CREATE TABLE cheques ('
    'id INTEGER PRIMARY KEY,'
    'cheque_number TEXT,'
    'amount_rial INTEGER,'
    'issue_date INTEGER,'
    'due_date INTEGER,'
    'status TEXT,'
    'is_registered_in_sayad INTEGER,'
    'sayad_id TEXT,'
    'receiver_name TEXT,'
    'description TEXT,'
    'image_data BLOB,'
    'archived_at INTEGER,'
    'updated_at INTEGER'
    ');',
  );
  db.execute(
    "INSERT INTO cheques ("
    "id, cheque_number, amount_rial, issue_date, due_date, status, is_registered_in_sayad, sayad_id, receiver_name, description, image_data, archived_at, updated_at"
    ") VALUES ("
    "1, 'CHQ-1', 1000, 100, 200, 'Issued', 0, NULL, NULL, NULL, NULL, NULL, 0"
    ");",
  );

  final statement = db.prepare('''
UPDATE cheques
SET
  cheque_number = :chequeNumber,
  amount_rial = :amountRial,
  issue_date = :issueDate,
  due_date = :dueDate,
  status = :status,
  is_registered_in_sayad = :isRegisteredInSayad,
  sayad_id = :sayadId,
  receiver_name = :receiverName,
  description = :description,
  image_data = :imageData,
  archived_at = :archivedAt,
  updated_at = :updatedAt
WHERE id = :id;
''');

  final namedParams = {
    ':id': 1,
    ':chequeNumber': 'CHQ-1',
    ':amountRial': 1000,
    ':issueDate': 100,
    ':dueDate': 200,
    ':status': 'Issued',
    ':isRegisteredInSayad': 1,
    ':sayadId': null,
    ':receiverName': null,
    ':description': null,
    ':imageData': null,
    ':archivedAt': null,
    ':updatedAt': DateTime.now().millisecondsSinceEpoch,
  };

  try {
    statement.executeWith(StatementParameters.named(namedParams));
    final affectedRows =
        (db.select('SELECT changes() AS changed_rows').first['changed_rows']
                as num)
            .toInt();
    final readBackStatement = db.prepare(
      'SELECT is_registered_in_sayad FROM cheques WHERE id = :id;',
    );
    final readBack = readBackStatement.selectWith(
      StatementParameters.named({':id': 1}),
    );
    readBackStatement.dispose();
    final updated = (readBack.first['is_registered_in_sayad'] as int) == 1;

    print('NO_EXCEPTION');
    print('AFFECTED_ROWS=$affectedRows');
    print('READBACK_IS_REGISTERED_IN_SAYAD=$updated');
  } catch (error, stackTrace) {
    print('EXCEPTION_TYPE=${error.runtimeType}');
    print('EXCEPTION_MESSAGE=$error');
    print('STACK_TRACE_START');
    print(stackTrace);
    print('STACK_TRACE_END');
    rethrow;
  } finally {
    statement.dispose();
    db.dispose();
  }
}
