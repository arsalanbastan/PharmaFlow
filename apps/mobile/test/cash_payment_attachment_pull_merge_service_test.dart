import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cash_payment_attachment_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cash_payment_attachment.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cash_payment_attachment_repository.dart';
import 'package:sqlite3/sqlite3.dart';

const parentUuid = '11111111-1111-4111-8111-111111111111';

class _FakeRemoteAttachmentRepository
    extends RemoteCashPaymentAttachmentRepository {
  _FakeRemoteAttachmentRepository(this.pages) : super(ApiClient());

  final List<RemoteCashPaymentAttachmentChangesPage> pages;

  int callCount = 0;
  final List<SyncCursor?> requestedCursors = <SyncCursor?>[];

  @override
  Future<RemoteCashPaymentAttachmentChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteCashPaymentAttachmentRepository.defaultChangesLimit,
  }) async {
    requestedCursors.add(cursor);

    if (callCount >= pages.length) {
      throw StateError('Unexpected attachment changes request.');
    }

    return pages[callCount++];
  }
}

RemoteCashPaymentAttachmentRecord _record({
  required String id,
  required DateTime updatedAt,
  String cashPaymentId = parentUuid,
  CashPaymentAttachmentKind kind = CashPaymentAttachmentKind.receipt,
  String fileName = 'receipt.jpg',
  String mimeType = 'image/jpeg',
  int? originalFileSize = 200,
  int fileSize = 100,
  String sha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String storageKey = 'cash-payments/test/receipt.jpg',
  DateTime? deletedAt,
}) {
  return RemoteCashPaymentAttachmentRecord(
    id: id,
    cashPaymentId: cashPaymentId,
    kind: kind,
    fileName: fileName,
    mimeType: mimeType,
    originalFileSize: originalFileSize,
    fileSize: fileSize,
    sha256: sha256,
    storageKey: storageKey,
    deletedAt: deletedAt,
    createdAt: DateTime.utc(2026, 8, 15, 8),
    updatedAt: updatedAt,
  );
}

SyncCursor _cursorFor(RemoteCashPaymentAttachmentRecord record) {
  return SyncCursor(
    entityType: syncEntityTypeCashPaymentAttachment,
    updatedAt: record.updatedAt,
    serverUuid: record.id,
  );
}

void main() {
  late Database db;
  late SyncCursorRepository cursorRepository;

  setUp(() {
    db = sqlite3.openInMemory();

    MigrationManager.migrate(db);

    DatabaseService.instance.injectDatabaseForTesting(db);

    cursorRepository = SyncCursorRepository(DatabaseService.instance);

    _insertParentCashPayment(db, id: 1, serverUuid: parentUuid);
  });

  tearDown(() {
    DatabaseService.instance.close();
  });

  test('paged pull inserts active attachment ignores absent tombstone '
      'and saves final cursor', () async {
    final first = _record(
      id: '22222222-2222-4222-8222-222222222222',
      updatedAt: DateTime.utc(2026, 8, 16, 8),
      storageKey: 'cash-payments/parent/first.jpg',
    );

    final absentTombstone = _record(
      id: '33333333-3333-4333-8333-333333333333',
      updatedAt: DateTime.utc(2026, 8, 16, 9),
      deletedAt: DateTime.utc(2026, 8, 16, 9),
      storageKey: 'cash-payments/parent/deleted.jpg',
    );

    final remote = _FakeRemoteAttachmentRepository(
      <RemoteCashPaymentAttachmentChangesPage>[
        RemoteCashPaymentAttachmentChangesPage(
          items: <RemoteCashPaymentAttachmentRecord>[first],
          hasMore: true,
          nextCursor: _cursorFor(first),
        ),
        RemoteCashPaymentAttachmentChangesPage(
          items: <RemoteCashPaymentAttachmentRecord>[absentTombstone],
          hasMore: false,
          nextCursor: _cursorFor(absentTombstone),
        ),
      ],
    );

    final service = CashPaymentAttachmentPullMergeService(
      databaseService: DatabaseService.instance,
      remoteRepository: remote,
      cursorRepository: cursorRepository,
    );

    final result = await service.pullAndMerge();

    expect(result.pagesFetched, 2);
    expect(result.changesReceived, 2);
    expect(result.uniqueChanges, 2);
    expect(result.inserted, 1);
    expect(result.updated, 0);
    expect(result.tombstonesApplied, 0);
    expect(result.tombstonesIgnored, 1);

    final rows = db.select('''
SELECT *
FROM cash_payment_attachments
ORDER BY id
''');

    expect(rows, hasLength(1));

    final row = rows.single;

    expect(row['server_uuid'], '22222222-2222-4222-8222-222222222222');

    expect(row['cash_payment_id'], 1);
    expect(row['storage_key'], 'cash-payments/parent/first.jpg');

    expect(
      row['local_path'],
      isNull,
      reason: 'Remote metadata pull must not invent a local device file path.',
    );

    final queueCount =
        db.select('SELECT COUNT(*) AS count FROM sync_queue').first['count']
            as int;

    expect(
      queueCount,
      0,
      reason: 'Remote merge must never enqueue local push work.',
    );

    final storedCursor = await cursorRepository.getByEntityType(
      syncEntityTypeCashPaymentAttachment,
    );

    expect(storedCursor, isNotNull);

    expect(storedCursor!.serverUuid, absentTombstone.id);

    expect(storedCursor.updatedAt, absentTombstone.updatedAt);

    expect(remote.callCount, 2);

    expect(remote.requestedCursors[1]?.serverUuid, first.id);
  });

  test('remote metadata update preserves existing localPath', () async {
    const attachmentUuid = '44444444-4444-4444-8444-444444444444';

    final localId = _seedLocalAttachment(
      db,
      serverUuid: attachmentUuid,
      cashPaymentId: 1,
      fileName: 'old.jpg',
      storageKey: 'old/storage/key',
      localPath: r'C:\cache\receipt.jpg',
    );

    final change = _record(
      id: attachmentUuid,
      updatedAt: DateTime.utc(2026, 8, 16, 10),
      fileName: 'server-name.jpg',
      fileSize: 150,
      originalFileSize: 300,
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      storageKey: 'new/storage/key',
    );

    final remote = _FakeRemoteAttachmentRepository(
      <RemoteCashPaymentAttachmentChangesPage>[
        RemoteCashPaymentAttachmentChangesPage(
          items: <RemoteCashPaymentAttachmentRecord>[change],
          hasMore: false,
          nextCursor: _cursorFor(change),
        ),
      ],
    );

    final service = CashPaymentAttachmentPullMergeService(
      databaseService: DatabaseService.instance,
      remoteRepository: remote,
      cursorRepository: cursorRepository,
    );

    final result = await service.pullAndMerge();

    expect(result.updated, 1);

    final row = db
        .select(
          '''
SELECT *
FROM cash_payment_attachments
WHERE id = ?
''',
          <Object?>[localId],
        )
        .single;

    expect(row['file_name'], 'server-name.jpg');
    expect(row['storage_key'], 'new/storage/key');

    expect(
      row['local_path'],
      r'C:\cache\receipt.jpg',
      reason:
          'Server metadata refresh must preserve the device-local cache path.',
    );

    expect(row['delete_requested_at'], isNull);
  });

  test('remote tombstone soft deletes existing local attachment', () async {
    const attachmentUuid = '55555555-5555-4555-8555-555555555555';

    final localId = _seedLocalAttachment(
      db,
      serverUuid: attachmentUuid,
      cashPaymentId: 1,
      localPath: r'C:\cache\old.pdf',
    );

    final deletedAt = DateTime.utc(2026, 8, 16, 11);

    final tombstone = _record(
      id: attachmentUuid,
      updatedAt: deletedAt,
      kind: CashPaymentAttachmentKind.statement,
      fileName: 'statement.pdf',
      mimeType: 'application/pdf',
      storageKey: 'cash-payments/parent/statement.pdf',
      deletedAt: deletedAt,
    );

    final remote = _FakeRemoteAttachmentRepository(
      <RemoteCashPaymentAttachmentChangesPage>[
        RemoteCashPaymentAttachmentChangesPage(
          items: <RemoteCashPaymentAttachmentRecord>[tombstone],
          hasMore: false,
          nextCursor: _cursorFor(tombstone),
        ),
      ],
    );

    final service = CashPaymentAttachmentPullMergeService(
      databaseService: DatabaseService.instance,
      remoteRepository: remote,
      cursorRepository: cursorRepository,
    );

    final result = await service.pullAndMerge();

    expect(result.tombstonesApplied, 1);

    final row = db
        .select(
          '''
SELECT deleted_at, local_path
FROM cash_payment_attachments
WHERE id = ?
''',
          <Object?>[localId],
        )
        .single;

    expect(row['deleted_at'], deletedAt.millisecondsSinceEpoch);

    expect(row['local_path'], r'C:\cache\old.pdf');

    expect(
      db
          .select('SELECT COUNT(*) AS count FROM cash_payment_attachments')
          .single['count'],
      1,
      reason: 'Server tombstone must not hard-delete the local row.',
    );
  });

  test(
    'pending local attachment work blocks overwrite and cursor advancement',
    () async {
      const attachmentUuid = '66666666-6666-4666-8666-666666666666';

      final localId = _seedLocalAttachment(
        db,
        serverUuid: attachmentUuid,
        cashPaymentId: 1,
        fileName: 'local-unsynced.jpg',
        storageKey: 'local/storage/key',
      );

      _enqueuePendingAttachmentUpdate(db, localId);

      final change = _record(
        id: attachmentUuid,
        updatedAt: DateTime.utc(2026, 8, 16, 12),
        fileName: 'remote-name.jpg',
        storageKey: 'remote/storage/key',
      );

      final remote = _FakeRemoteAttachmentRepository(
        <RemoteCashPaymentAttachmentChangesPage>[
          RemoteCashPaymentAttachmentChangesPage(
            items: <RemoteCashPaymentAttachmentRecord>[change],
            hasMore: false,
            nextCursor: _cursorFor(change),
          ),
        ],
      );

      final service = CashPaymentAttachmentPullMergeService(
        databaseService: DatabaseService.instance,
        remoteRepository: remote,
        cursorRepository: cursorRepository,
      );

      await expectLater(
        service.pullAndMerge(),
        throwsA(isA<CashPaymentAttachmentPullBlockedByLocalChangesException>()),
      );

      final row = db
          .select(
            '''
SELECT file_name, storage_key
FROM cash_payment_attachments
WHERE id = ?
''',
            <Object?>[localId],
          )
          .single;

      expect(row['file_name'], 'local-unsynced.jpg');
      expect(row['storage_key'], 'local/storage/key');

      final cursor = await cursorRepository.getByEntityType(
        syncEntityTypeCashPaymentAttachment,
      );

      expect(
        cursor,
        isNull,
        reason:
            'Cursor must not advance past an attachment with local unsynced work.',
      );
    },
  );
}

void _insertParentCashPayment(
  Database db, {
  required int id,
  required String serverUuid,
}) {
  final now = DateTime.utc(2026, 8, 15).millisecondsSinceEpoch;

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
    <Object?>[
      id,
      serverUuid,
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

int _seedLocalAttachment(
  Database db, {
  required String serverUuid,
  required int cashPaymentId,
  String fileName = 'receipt.jpg',
  String mimeType = 'image/jpeg',
  String sha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String storageKey = 'cash-payments/local/receipt.jpg',
  String? localPath,
}) {
  final created = DateTime.utc(2026, 8, 15, 8);
  final updated = DateTime.utc(2026, 8, 15, 9);

  db.execute(
    '''
INSERT INTO cash_payment_attachments (
  server_uuid,
  cash_payment_id,
  kind,
  file_name,
  mime_type,
  original_file_size,
  file_size,
  sha256,
  local_path,
  storage_key,
  delete_requested_at,
  deleted_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?)
''',
    <Object?>[
      serverUuid,
      cashPaymentId,
      'RECEIPT',
      fileName,
      mimeType,
      200,
      100,
      sha256,
      localPath,
      storageKey,
      created.millisecondsSinceEpoch,
      updated.millisecondsSinceEpoch,
    ],
  );

  return db.select('SELECT last_insert_rowid() AS id').single['id'] as int;
}

void _enqueuePendingAttachmentUpdate(Database db, int attachmentId) {
  db.execute(
    '''
INSERT INTO sync_queue (
  entityType,
  entityId,
  operation,
  status,
  retryCount,
  createdAt,
  lastAttemptAt,
  errorMessage
)
VALUES (?, ?, ?, ?, 0, ?, NULL, NULL)
''',
    <Object?>[
      syncEntityTypeCashPaymentAttachment,
      attachmentId,
      SyncOperation.update.dbValue,
      SyncStatus.pending.dbValue,
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
}
