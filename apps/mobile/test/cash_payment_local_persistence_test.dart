import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/data/mappers/cash_payment_mapper.dart';
import 'package:pharmaflow/data/models/cash_payment.dart';
import 'package:pharmaflow/data/repositories/local/local_cash_payment_repository.dart';

void main() {
  test('migration preserves cash_payments through database version 13', () {
    final db = sqlite3.openInMemory();

    try {
      MigrationManager.migrate(db);

      final version =
          db.select('PRAGMA user_version').first['user_version'] as int;

      expect(version, 13);

      final columns = db
          .select('PRAGMA table_info(cash_payments)')
          .map((row) => row['name'] as String)
          .toSet();

      expect(
        columns,
        containsAll(<String>{
          'id',
          'server_uuid',
          'amount_rial',
          'payment_date',
          'company_id',
          'bank_account_id',
          'payment_method',
          'tracking_number',
          'description',
          'notes',
          'archived_at',
          'delete_requested_at',
          'deleted_at',
          'created_at',
          'updated_at',
        }),
      );

      final foreignKeys = db.select('PRAGMA foreign_key_list(cash_payments)');

      expect(foreignKeys, hasLength(2));

      final referencedTables = foreignKeys
          .map((row) => row['table'] as String)
          .toSet();

      expect(
        referencedTables,
        containsAll(<String>{'companies', 'bank_accounts'}),
      );
    } finally {
      db.dispose();
    }
  });

  test('version 10 upgrades forward through version 13', () {
    final db = sqlite3.openInMemory();

    try {
      db.execute('''
CREATE TABLE companies (
  id INTEGER PRIMARY KEY
);
''');

      db.execute('''
CREATE TABLE bank_accounts (
  id INTEGER PRIMARY KEY
);
''');

      db.execute('PRAGMA user_version = 10');

      MigrationManager.migrate(db);

      final version =
          db.select('PRAGMA user_version').first['user_version'] as int;

      expect(version, 13);

      final table = db.select('''
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name = 'cash_payments'
''');

      expect(table, hasLength(1));
    } finally {
      db.dispose();
    }
  });

  test('mapper roundtrips both supported payment methods', () {
    final now = DateTime.utc(2026, 8, 16, 10, 0);

    for (final method in CashPaymentMethod.values) {
      final payment = CashPayment(
        id: 7,
        serverUuid: '11111111-2222-4333-8444-555555555555',
        amountRial: 1250000,
        paymentDate: now,
        companyId: 3,
        bankAccountId: 4,
        paymentMethod: method,
        trackingNumber: 'REF-100',
        description: 'test',
        notes: 'notes',
        createdAt: now,
        updatedAt: now,
      );

      final mapped = CashPaymentMapper.fromMap(
        CashPaymentMapper.toMap(payment),
      );

      expect(mapped.paymentMethod, method);

      expect(mapped.amountRial, 1250000);

      expect(mapped.companyId, 3);

      expect(mapped.bankAccountId, 4);
    }
  });

  test(
    'local repository persists update archive restore and delete intent',
    () async {
      final db = sqlite3.openInMemory();

      MigrationManager.migrate(db);

      db.execute('PRAGMA foreign_keys = OFF');

      DatabaseService.instance.injectDatabaseForTesting(db);

      final repository = LocalCashPaymentRepository(DatabaseService.instance);

      try {
        final now = DateTime.utc(2026, 8, 16, 10, 0);

        final id = await repository.insert(
          CashPayment(
            amountRial: 5000000,
            paymentDate: now,
            companyId: 101,
            bankAccountId: 202,
            paymentMethod: CashPaymentMethod.bankDeposit,
            trackingNumber: '  REF-001  ',
            description: '  initial payment  ',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(id, greaterThan(0));

        final inserted = await repository.findById(id);

        expect(inserted, isNotNull);

        expect(inserted!.serverUuid, isNotEmpty);

        expect(inserted.trackingNumber, 'REF-001');

        expect(inserted.description, 'initial payment');

        await repository.update(
          inserted.copyWith(
            amountRial: 7000000,
            paymentMethod: CashPaymentMethod.posPayment,
            trackingNumber: null,
            description: 'updated',
          ),
        );

        final updated = await repository.findById(id);

        expect(updated!.amountRial, 7000000);

        expect(updated.paymentMethod, CashPaymentMethod.posPayment);

        expect(updated.trackingNumber, isNull);

        await repository.archive(id);

        expect(await repository.getAll(), isEmpty);

        expect(await repository.getAll(includeArchived: true), hasLength(1));

        await repository.restore(id);

        expect(await repository.getAll(), hasLength(1));

        await repository.requestDelete(id);

        expect(await repository.getAll(), isEmpty);

        final deleteVisible = await repository.getAll(
          includeDeleteRequested: true,
        );

        expect(deleteVisible, hasLength(1));

        expect(deleteVisible.first.deleteRequestedAt, isNotNull);
      } finally {
        DatabaseService.instance.close();
      }
    },
  );
}
