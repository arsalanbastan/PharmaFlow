import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cash_payment.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cash_payment_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cash_payment_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';

void main() {
  test(
    'CASH_PAYMENT CREATE UPDATE DELETE push lifecycle works through phase 4',
    () async {
      final db = sqlite3.openInMemory();

      MigrationManager.migrate(db);

      DatabaseService.instance.injectDatabaseForTesting(db);

      try {
        final fixture = _seedDependencies(db);

        final queueRepository = SyncQueueRepository(DatabaseService.instance);

        final cashRepository = LocalCashPaymentRepository(
          DatabaseService.instance,
        );

        const paymentUuid = '44444444-4444-4444-8444-444444444444';

        final now = DateTime.utc(2026, 8, 16, 7, 0);

        final localId = await cashRepository.insert(
          CashPayment(
            serverUuid: paymentUuid,
            amountRial: 5000000,
            paymentDate: now,
            companyId: fixture.companyLocalId,
            bankAccountId: fixture.bankLocalId,
            paymentMethod: CashPaymentMethod.bankDeposit,
            trackingNumber: 'REF-CREATE',
            description: 'create',
            createdAt: now,
            updatedAt: now,
          ),
        );

        var processable = await queueRepository.getProcessable();

        expect(processable, hasLength(1));
        expect(processable.single.entityType, syncEntityTypeCashPayment);
        expect(processable.single.operation, SyncOperation.create);

        final fakeCashRemote = _FakeRemoteCashPaymentRepository();

        final service = _buildSyncService(
          cashRepository: cashRepository,
          queueRepository: queueRepository,
          fakeCashRemote: fakeCashRemote,
        );

        final createResult = await service.sync();

        expect(createResult.failed, 0);
        expect(fakeCashRemote.operations, <String>['CREATE']);

        final inserted = await cashRepository.findById(localId);

        expect(inserted, isNotNull);

        await cashRepository.update(
          inserted!.copyWith(
            amountRial: 7000000,
            paymentMethod: CashPaymentMethod.posPayment,
            trackingNumber: 'REF-UPDATE',
            description: 'updated',
          ),
        );

        processable = await queueRepository.getProcessable();

        final updateItems = processable
            .where(
              (item) =>
                  item.entityType == syncEntityTypeCashPayment &&
                  item.operation == SyncOperation.update,
            )
            .toList();

        expect(updateItems, hasLength(1));

        final updateResult = await service.sync();

        expect(updateResult.failed, 0);
        expect(fakeCashRemote.operations, <String>['CREATE', 'UPDATE']);

        await cashRepository.requestDelete(localId);
        await cashRepository.requestDelete(localId);

        processable = await queueRepository.getProcessable();

        final deleteItems = processable
            .where(
              (item) =>
                  item.entityType == syncEntityTypeCashPayment &&
                  item.operation == SyncOperation.delete,
            )
            .toList();

        expect(deleteItems, hasLength(1));

        final deleteResult = await service.sync();

        expect(deleteResult.failed, 0);

        expect(fakeCashRemote.operations, <String>[
          'CREATE',
          'UPDATE',
          'DELETE',
        ]);

        processable = await queueRepository.getProcessable();

        expect(
          processable.where(
            (item) => item.entityType == syncEntityTypeCashPayment,
          ),
          isEmpty,
        );

        final deletedLocal = await cashRepository.findById(localId);

        expect(deletedLocal!.deleteRequestedAt, isNotNull);
      } finally {
        DatabaseService.instance.close();
      }
    },
  );

  test(
    'CHEQUE failure gates CASH_PAYMENT even when cash queue item is older',
    () async {
      final db = sqlite3.openInMemory();

      MigrationManager.migrate(db);

      DatabaseService.instance.injectDatabaseForTesting(db);

      try {
        final fixture = _seedDependencies(db);

        final queueRepository = SyncQueueRepository(DatabaseService.instance);

        final cashRepository = LocalCashPaymentRepository(
          DatabaseService.instance,
        );

        final now = DateTime.utc(2026, 8, 16, 7, 0);

        await cashRepository.insert(
          CashPayment(
            serverUuid: '55555555-5555-4555-8555-555555555555',
            amountRial: 9000000,
            paymentDate: now,
            companyId: fixture.companyLocalId,
            bankAccountId: fixture.bankLocalId,
            paymentMethod: CashPaymentMethod.bankDeposit,
            createdAt: now,
            updatedAt: now,
          ),
        );

        /*
         * This CHEQUE queue item is newer than CASH_PAYMENT but deliberately
         * references a missing local cheque. Dependency phases must still
         * process CHEQUE first and leave CASH_PAYMENT untouched.
         */
        await queueRepository.add(
          SyncQueueItem(
            entityType: syncEntityTypeCheque,
            entityId: 999999,
            operation: SyncOperation.create,
            status: SyncStatus.pending,
            retryCount: 0,
            createdAt: now.add(const Duration(seconds: 1)),
          ),
        );

        final fakeCashRemote = _FakeRemoteCashPaymentRepository();

        final service = _buildSyncService(
          cashRepository: cashRepository,
          queueRepository: queueRepository,
          fakeCashRemote: fakeCashRemote,
        );

        final result = await service.sync();

        expect(result.failed, 1);
        expect(fakeCashRemote.operations, isEmpty);

        final processable = await queueRepository.getProcessable();

        final cashItems = processable
            .where((item) => item.entityType == syncEntityTypeCashPayment)
            .toList();

        expect(cashItems, hasLength(1));
        expect(cashItems.single.status, SyncStatus.pending);
      } finally {
        DatabaseService.instance.close();
      }
    },
  );
}

SyncService _buildSyncService({
  required LocalCashPaymentRepository cashRepository,
  required SyncQueueRepository queueRepository,
  required _FakeRemoteCashPaymentRepository fakeCashRemote,
}) {
  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );

  final localBankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );

  final localChequeRepository = LocalChequeRepository(DatabaseService.instance);

  final identityResolver = SyncIdentityResolver(DatabaseService.instance);

  final apiClient = ApiClient();

  final remoteCompanyRepository = RemoteCompanyRepository(apiClient);

  final remoteBankRepository = RemoteBankAccountsRepository(apiClient);

  final remoteChequeRepository = RemoteChequeRepository(apiClient);

  return SyncService(
    syncQueueRepository: queueRepository,
    localCompanyRepository: localCompanyRepository,
    localBankAccountRepository: localBankAccountRepository,
    localChequeRepository: localChequeRepository,
    identityResolver: identityResolver,
    remoteCompanyRepository: remoteCompanyRepository,
    remoteBankAccountsRepository: remoteBankRepository,
    remoteChequeRepository: remoteChequeRepository,
    chequeSyncIdentityResolver: ChequeSyncIdentityResolver(
      localChequeRepository: localChequeRepository,
      remoteChequeRepository: remoteChequeRepository,
      identityResolver: identityResolver,
    ),
    localCashPaymentRepository: cashRepository,
    remoteCashPaymentRepository: fakeCashRemote,
  );
}

({int companyLocalId, int bankLocalId}) _seedDependencies(Database db) {
  const companyUuid = '22222222-2222-4222-8222-222222222222';

  const bankUuid = '33333333-3333-4333-8333-333333333333';

  final now = DateTime.utc(2026, 8, 16, 6, 0);

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
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
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
      'Cash payment activation test',
      0,
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ],
  );

  final bankLocalId =
      db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

  return (companyLocalId: companyLocalId, bankLocalId: bankLocalId);
}

class _FakeRemoteCashPaymentRepository extends RemoteCashPaymentRepository {
  _FakeRemoteCashPaymentRepository() : super(ApiClient());

  final List<String> operations = <String>[];

  @override
  Future<String> create(Map<String, dynamic> payload) async {
    operations.add('CREATE');

    final id = payload['id'];

    if (id is! String || id.trim().isEmpty) {
      throw StateError('Test CREATE payload did not contain a client UUID.');
    }

    return id;
  }

  @override
  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    operations.add('UPDATE');

    if (serverUuid.trim().isEmpty) {
      throw StateError('Test UPDATE received an empty server UUID.');
    }
  }

  @override
  Future<void> delete(String serverUuid) async {
    operations.add('DELETE');

    if (serverUuid.trim().isEmpty) {
      throw StateError('Test DELETE received an empty server UUID.');
    }
  }
}
