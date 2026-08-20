import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cheque.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';

int _seedCompany(Database db, String name) {
  final now = DateTime.utc(2026, 8, 13).millisecondsSinceEpoch;

  db.execute(
    '''
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
)
VALUES (?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
''',
    [
      '11111111-1111-4111-8111-${name.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}',
      name,
      now,
      now,
    ],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

int _seedBank(Database db, String title) {
  final now = DateTime.utc(2026, 8, 13).millisecondsSinceEpoch;

  db.execute(
    '''
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
)
VALUES (?, 'Bank', ?, 'Owner', '1', '2', 'IR3', NULL, NULL, ?, ?)
''',
    [
      '22222222-2222-4222-8222-${title.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}',
      title,
      now,
      now,
    ],
  );

  return db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
}

Cheque _cheque({
  required int companyId,
  required int bankId,
  int id = 0,
  String? serverUuid,
  String number = '1001',
}) {
  final now = DateTime.utc(2026, 8, 13, 10);

  return Cheque(
    id: id,
    serverUuid: serverUuid,
    companyId: companyId,
    bankAccountId: bankId,
    chequeNumber: number,
    amountRial: 1000000,
    issueDate: now,
    dueDate: now.add(const Duration(days: 10)),
    status: ChequeStatus.issued,
    isRegisteredInSayad: false,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late LocalChequeRepository repository;
  late int companyA;
  late int companyB;
  late int bankA;
  late int bankB;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    repository = LocalChequeRepository(DatabaseService.instance);
    companyA = _seedCompany(db, 'Company A');
    companyB = _seedCompany(db, 'Company B');
    bankA = _seedBank(db, 'Bank A');
    bankB = _seedBank(db, 'Bank B');
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'Cheque INSERT generates UUID and atomically creates one pending CREATE queue item',
    () async {
      final id = await repository.insert(
        _cheque(companyId: companyA, bankId: bankA),
      );

      final row = db.select('SELECT server_uuid FROM cheques WHERE id = ?', [
        id,
      ]).first;

      final uuid = row['server_uuid'] as String?;
      expect(uuid, isNotNull);
      expect(uuid!.trim(), isNotEmpty);

      final queueRows = db.select(
        '''
SELECT operation, status
FROM sync_queue
WHERE entityType = ? AND entityId = ?
''',
        [syncEntityTypeCheque, id],
      );

      expect(queueRows.length, equals(1));
      expect(
        queueRows.first['operation'],
        equals(SyncOperation.create.dbValue),
      );
      expect(queueRows.first['status'], equals(SyncStatus.pending.dbValue));
    },
  );

  test(
    'edit before first cheque sync keeps CREATE, preserves UUID, and updates dependency ids',
    () async {
      final id = await repository.insert(
        _cheque(companyId: companyA, bankId: bankA),
      );

      final existing = await repository.findById(id);
      expect(existing, isNotNull);

      final uuidBefore = existing!.serverUuid;

      await repository.update(
        existing.copyWith(
          companyId: companyB,
          bankAccountId: bankB,
          chequeNumber: '2002',
          updatedAt: DateTime.now(),
        ),
      );

      final updated = await repository.findById(id);
      expect(updated, isNotNull);
      expect(updated!.serverUuid, equals(uuidBefore));
      expect(updated.companyId, equals(companyB));
      expect(updated.bankAccountId, equals(bankB));
      expect(updated.chequeNumber, equals('2002'));

      final activeRows = db.select(
        '''
SELECT operation
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
  AND status IN (?, ?, ?)
''',
        [
          syncEntityTypeCheque,
          id,
          SyncStatus.pending.dbValue,
          SyncStatus.failed.dbValue,
          SyncStatus.processing.dbValue,
        ],
      );

      expect(activeRows.length, equals(1));
      expect(
        activeRows.first['operation'],
        equals(SyncOperation.create.dbValue),
      );
    },
  );
}
