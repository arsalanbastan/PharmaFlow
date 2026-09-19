import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/bank_account.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';

BankAccount _account({
  int? id,
  String? serverUuid,
  String title = 'حساب تست',
  String bankName = 'بانک تست',
  String iban = 'IR123456',
  DateTime? archivedAt,
}) {
  final now = DateTime.utc(2026, 8, 13, 10);

  return BankAccount(
    id: id,
    serverUuid: serverUuid,
    bankName: bankName,
    accountTitle: title,
    accountHolder: 'داروخانه',
    accountNumber: '123',
    cardNumber: '456',
    iban: iban,
    note: 'note',
    archivedAt: archivedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Database db;
  late LocalBankAccountRepository repository;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);
    repository = LocalBankAccountRepository(DatabaseService.instance);
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'BankAccount INSERT generates UUID and atomically creates one pending CREATE queue item',
    () async {
      final id = await repository.insert(_account());

      final bankRow = db.select(
        'SELECT server_uuid FROM bank_accounts WHERE id = ?',
        [id],
      ).first;

      final uuid = bankRow['server_uuid'] as String?;

      expect(uuid, isNotNull);
      expect(uuid!.trim(), isNotEmpty);

      final queueRows = db.select(
        '''
SELECT entityType, entityId, operation, status
FROM sync_queue
WHERE entityType = ? AND entityId = ?
''',
        [syncEntityTypeBankAccount, id],
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
    'edit before first bank sync keeps CREATE and preserves generated UUID',
    () async {
      final id = await repository.insert(_account());

      final uuidBefore =
          db.select('SELECT server_uuid FROM bank_accounts WHERE id = ?', [
                id,
              ]).first['server_uuid']
              as String;

      final existing = await repository.findById(id);
      expect(existing, isNotNull);

      await repository.update(
        BankAccount(
          id: id,
          serverUuid: null,
          bankName: 'بانک ویرایش‌شده',
          accountTitle: 'حساب ویرایش‌شده',
          accountHolder: existing!.accountHolder,
          accountNumber: existing.accountNumber,
          cardNumber: existing.cardNumber,
          iban: existing.iban,
          note: existing.note,
          archivedAt: existing.archivedAt,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      final uuidAfter =
          db.select('SELECT server_uuid FROM bank_accounts WHERE id = ?', [
                id,
              ]).first['server_uuid']
              as String;

      expect(uuidAfter, equals(uuidBefore));

      final activeRows = db.select(
        '''
SELECT operation, status
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
  AND status IN (?, ?, ?)
ORDER BY id
''',
        [
          syncEntityTypeBankAccount,
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

  test(
    'archive before first bank sync keeps CREATE and latest archived snapshot',
    () async {
      final id = await repository.insert(_account());

      await repository.archive(id);

      final row = db.select(
        'SELECT archived_at FROM bank_accounts WHERE id = ?',
        [id],
      ).first;

      expect(row['archived_at'], isNotNull);

      final activeRows = db.select(
        '''
SELECT operation
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
  AND status IN (?, ?, ?)
''',
        [
          syncEntityTypeBankAccount,
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
