import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cash_payment_attachment.dart';
import 'package:pharmaflow/data/repositories/local/local_cash_payment_attachment_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';

void main() {
  late Database database;
  late LocalCashPaymentAttachmentRepository repository;
  late SyncQueueRepository queueRepository;

  setUp(() {
    database = sqlite3.openInMemory();

    MigrationManager.migrate(database);

    DatabaseService.instance.injectDatabaseForTesting(database);

    repository = LocalCashPaymentAttachmentRepository(DatabaseService.instance);

    queueRepository = SyncQueueRepository(DatabaseService.instance);

    _insertParentCashPayment(database, id: 1);
  });

  tearDown(() {
    DatabaseService.instance.close();
  });

  test('migration 13 preserves cash payment attachments table', () {
    final version =
        database.select('PRAGMA user_version').first['user_version'] as int;

    expect(version, 13);

    final table = database.select('''
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name = 'cash_payment_attachments'
''');

    expect(table, isNotEmpty);

    final columns = database
        .select('PRAGMA table_info(cash_payment_attachments)')
        .map((row) => row['name'].toString())
        .toSet();

    expect(
      columns,
      containsAll(<String>{
        'id',
        'server_uuid',
        'cash_payment_id',
        'kind',
        'file_name',
        'mime_type',
        'original_file_size',
        'file_size',
        'sha256',
        'local_path',
        'storage_key',
        'delete_requested_at',
        'deleted_at',
        'created_at',
        'updated_at',
      }),
    );
  });

  test(
    'local attachment insert persists metadata and enqueues CREATE',
    () async {
      final now = DateTime.now().toUtc();

      final id = await repository.insert(
        CashPaymentAttachment(
          cashPaymentId: 1,
          kind: CashPaymentAttachmentKind.receipt,
          fileName: 'receipt.jpg',
          mimeType: 'image/jpeg',
          originalFileSize: 500000,
          fileSize: 220000,
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          localPath: r'C:\temp\receipt.jpg',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final saved = await repository.findById(id);

      expect(saved, isNotNull);
      expect(saved!.serverUuid, isNotNull);
      expect(saved.serverUuid, isNotEmpty);

      expect(saved.kind, CashPaymentAttachmentKind.receipt);

      expect(saved.cashPaymentId, 1);

      expect(saved.mimeType, 'image/jpeg');

      expect(saved.fileSize, 220000);

      expect(saved.localPath, r'C:\temp\receipt.jpg');

      final pending = await queueRepository.getPending();

      final createItems = pending
          .where(
            (item) =>
                item.entityType == syncEntityTypeCashPaymentAttachment &&
                item.entityId == id &&
                item.operation == SyncOperation.create &&
                item.status == SyncStatus.pending,
          )
          .toList();

      expect(createItems, hasLength(1));
    },
  );

  test('delete before unsynced CREATE cancels remote work', () async {
    final now = DateTime.now().toUtc();

    final id = await repository.insert(
      CashPaymentAttachment(
        cashPaymentId: 1,
        kind: CashPaymentAttachmentKind.statement,
        fileName: 'statement.pdf',
        mimeType: 'application/pdf',
        originalFileSize: 351,
        fileSize: 351,
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        localPath: r'C:\temp\statement.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.requestDelete(id);

    final saved = await repository.findById(id);

    expect(saved!.deleteRequestedAt, isNotNull);

    final processable = await queueRepository.getProcessable();

    final activeItems = processable
        .where(
          (item) =>
              item.entityType == syncEntityTypeCashPaymentAttachment &&
              item.entityId == id,
        )
        .toList();

    expect(activeItems, isEmpty);
  });

  test('delete after successful CREATE enqueues DELETE', () async {
    final now = DateTime.now().toUtc();

    final id = await repository.insert(
      CashPaymentAttachment(
        cashPaymentId: 1,
        kind: CashPaymentAttachmentKind.receipt,
        fileName: 'receipt.jpg',
        mimeType: 'image/jpeg',
        originalFileSize: 300000,
        fileSize: 200000,
        sha256:
            'cccccccccccccccccccccccccccccccc'
            'cccccccccccccccccccccccccccccccc',
        localPath: r'C:\temp\receipt2.jpg',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final pending = await queueRepository.getPending();

    final createItem = pending.firstWhere(
      (item) =>
          item.entityType == syncEntityTypeCashPaymentAttachment &&
          item.entityId == id &&
          item.operation == SyncOperation.create,
    );

    await queueRepository.markSynced(createItem.id!);

    await repository.requestDelete(id);

    final processable = await queueRepository.getProcessable();

    final deleteItems = processable
        .where(
          (item) =>
              item.entityType == syncEntityTypeCashPaymentAttachment &&
              item.entityId == id &&
              item.operation == SyncOperation.delete &&
              item.status == SyncStatus.pending,
        )
        .toList();

    expect(deleteItems, hasLength(1));
  });
}

void _insertParentCashPayment(Database db, {required int id}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;

  db.execute('PRAGMA foreign_keys = OFF;');

  db.execute(
    '''
INSERT INTO cash_payments (
  id,
  server_uuid,
  amount_rial,
  payment_date,
  company_id,
  bank_account_id,
  payment_method,
  tracking_number,
  description,
  notes,
  archived_at,
  delete_requested_at,
  deleted_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
    [
      id,
      '11111111-1111-4111-8111-111111111111',
      1000000,
      now,
      1,
      1,
      'BANK_DEPOSIT',
      null,
      null,
      null,
      null,
      null,
      null,
      now,
      now,
    ],
  );

  db.execute('PRAGMA foreign_keys = ON;');
}
