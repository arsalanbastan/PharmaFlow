import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cash_payment_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/data/models/cash_payment.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cash_payment_repository.dart';

void main() {
  test(
    'remote cash payment record accepts Prisma decimal text and both methods',
    () {
      final base = <String, dynamic>{
        'id': '11111111-1111-4111-8111-111111111111',
        'amount': '250000000.00',
        'paymentDate': '2026-08-16T00:00:00.000Z',
        'companyId': '22222222-2222-4222-8222-222222222222',
        'bankAccountId': '33333333-3333-4333-8333-333333333333',
        'paymentMethod': 'BANK_DEPOSIT',
        'trackingNumber': 'REF-1',
        'description': 'invoice',
        'notes': null,
        'archivedAt': null,
        'deletedAt': null,
        'createdAt': '2026-08-16T00:00:00.000Z',
        'updatedAt': '2026-08-16T00:01:00.000Z',
      };

      final bankDeposit = RemoteCashPaymentRecord.fromJson(base);

      expect(bankDeposit.amountRial, 250000000);

      expect(bankDeposit.paymentMethod, CashPaymentMethod.bankDeposit);

      final pos = RemoteCashPaymentRecord.fromJson(<String, dynamic>{
        ...base,
        'paymentMethod': 'POS_PAYMENT',
      });

      expect(pos.paymentMethod, CashPaymentMethod.posPayment);
    },
  );

  test(
    'cash payment pull merge resolves dependencies, advances cursor and applies tombstone',
    () async {
      final db = sqlite3.openInMemory();

      MigrationManager.migrate(db);

      DatabaseService.instance.injectDatabaseForTesting(db);

      try {
        const companyUuid = '22222222-2222-4222-8222-222222222222';

        const bankUuid = '33333333-3333-4333-8333-333333333333';

        const paymentUuid = '11111111-1111-4111-8111-111111111111';

        final createdAt = DateTime.utc(2026, 8, 16, 6, 0);

        final firstUpdatedAt = DateTime.utc(2026, 8, 16, 6, 1);

        final deletedUpdatedAt = DateTime.utc(2026, 8, 16, 6, 2);

        db.execute(
          '''
INSERT INTO companies (
  server_uuid,
  name,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?)
''',
          [
            companyUuid,
            'Test Company',
            createdAt.millisecondsSinceEpoch,
            createdAt.millisecondsSinceEpoch,
          ],
        );

        final companyLocalId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

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
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
          [
            bankUuid,
            'Test Bank',
            'Main Account',
            'Pharmacy',
            'TEST-ACCOUNT-001',
            '6037991234567890',
            'IR000000000000000000000000',
            'Cash payment sync test fixture',
            0,
            createdAt.millisecondsSinceEpoch,
            createdAt.millisecondsSinceEpoch,
          ],
        );

        final bankLocalId =
            db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

        final activeRecord = RemoteCashPaymentRecord(
          id: paymentUuid,
          amountRial: 5000000,
          paymentDate: DateTime.utc(2026, 8, 16),
          companyId: companyUuid,
          bankAccountId: bankUuid,
          paymentMethod: CashPaymentMethod.bankDeposit,
          trackingNumber: 'REF-100',
          description: 'test payment',
          notes: 'test note',
          archivedAt: null,
          deletedAt: null,
          createdAt: createdAt,
          updatedAt: firstUpdatedAt,
        );

        final firstCursor = SyncCursor(
          entityType: syncEntityTypeCashPayment,
          updatedAt: firstUpdatedAt,
          serverUuid: paymentUuid,
        );

        final deletedRecord = RemoteCashPaymentRecord(
          id: paymentUuid,
          amountRial: 5000000,
          paymentDate: DateTime.utc(2026, 8, 16),
          companyId: companyUuid,
          bankAccountId: bankUuid,
          paymentMethod: CashPaymentMethod.bankDeposit,
          trackingNumber: 'REF-100',
          description: 'test payment',
          notes: 'test note',
          archivedAt: null,
          deletedAt: deletedUpdatedAt,
          createdAt: createdAt,
          updatedAt: deletedUpdatedAt,
        );

        final secondCursor = SyncCursor(
          entityType: syncEntityTypeCashPayment,
          updatedAt: deletedUpdatedAt,
          serverUuid: paymentUuid,
        );

        final remote = _FakeRemoteCashPaymentRepository(
          <RemoteCashPaymentChangesPage>[
            RemoteCashPaymentChangesPage(
              items: <RemoteCashPaymentRecord>[activeRecord],
              hasMore: false,
              nextCursor: firstCursor,
            ),
            RemoteCashPaymentChangesPage(
              items: <RemoteCashPaymentRecord>[deletedRecord],
              hasMore: false,
              nextCursor: secondCursor,
            ),
          ],
        );

        final cursorRepository = SyncCursorRepository(DatabaseService.instance);

        final service = CashPaymentPullMergeService(
          databaseService: DatabaseService.instance,
          remoteRepository: remote,
          cursorRepository: cursorRepository,
        );

        final firstResult = await service.pullAndMerge();

        expect(firstResult.inserted, 1);

        expect(firstResult.updated, 0);

        var rows = db.select(
          '''
SELECT *
FROM cash_payments
WHERE server_uuid = ?
''',
          [paymentUuid],
        );

        expect(rows, hasLength(1));

        expect(rows.first['company_id'], companyLocalId);

        expect(rows.first['bank_account_id'], bankLocalId);

        expect(rows.first['payment_method'], 'BANK_DEPOSIT');

        expect(rows.first['deleted_at'], isNull);

        final storedCursor1 = await cursorRepository.getByEntityType(
          syncEntityTypeCashPayment,
        );

        expect(storedCursor1, isNotNull);

        expect(storedCursor1!.serverUuid, paymentUuid);

        expect(storedCursor1.updatedAt.toUtc(), firstUpdatedAt);

        final secondResult = await service.pullAndMerge();

        expect(secondResult.updated, 1);

        expect(secondResult.tombstonesApplied, 1);

        rows = db.select(
          '''
SELECT *
FROM cash_payments
WHERE server_uuid = ?
''',
          [paymentUuid],
        );

        expect(rows, hasLength(1));

        expect(
          rows.first['deleted_at'],
          deletedUpdatedAt.millisecondsSinceEpoch,
        );

        expect(rows.first['delete_requested_at'], isNull);

        final storedCursor2 = await cursorRepository.getByEntityType(
          syncEntityTypeCashPayment,
        );

        expect(storedCursor2, isNotNull);

        expect(storedCursor2!.updatedAt.toUtc(), deletedUpdatedAt);
      } finally {
        DatabaseService.instance.close();
      }
    },
  );
}

class _FakeRemoteCashPaymentRepository extends RemoteCashPaymentRepository {
  _FakeRemoteCashPaymentRepository(this._pages) : super(ApiClient());

  final List<RemoteCashPaymentChangesPage> _pages;

  int _index = 0;

  @override
  Future<RemoteCashPaymentChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteCashPaymentRepository.defaultChangesLimit,
  }) async {
    if (_index >= _pages.length) {
      return RemoteCashPaymentChangesPage(
        items: const <RemoteCashPaymentRecord>[],
        hasMore: false,
        nextCursor: cursor,
      );
    }

    final page = _pages[_index];

    _index += 1;

    return page;
  }
}
