import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cash_payment_attachment_pull_merge_service.dart';
import 'package:pharmaflow/core/sync/cash_payment_attachment_push_service.dart';
import 'package:pharmaflow/core/sync/cheque_sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_cursor.dart';
import 'package:pharmaflow/core/sync/sync_identity_resolver.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_service.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cash_payment_attachment.dart';
import 'package:pharmaflow/data/repositories/local/local_bank_account_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cash_payment_attachment_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cash_payment_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_cursor_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_bank_accounts_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cash_payment_attachment_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_company_repository.dart';
import 'package:sqlite3/sqlite3.dart';

const _parentUuid = '11111111-1111-4111-8111-111111111111';
const _attachmentUuid = '22222222-2222-4222-8222-222222222222';

class _FakeAttachmentRemote extends RemoteCashPaymentAttachmentRepository {
  _FakeAttachmentRemote() : super(ApiClient());

  int prepareCalls = 0;
  int uploadCalls = 0;
  int confirmCalls = 0;
  int changesCalls = 0;

  Uint8List? uploadedBytes;

  static const storageKey =
      'cash-payments/'
      '11111111-1111-4111-8111-111111111111/'
      '22222222-2222-4222-8222-222222222222.pdf';

  @override
  Future<RemoteAttachmentPrepareResult> prepareUpload(
    CashPaymentAttachmentUploadMetadata metadata,
  ) async {
    prepareCalls += 1;

    expect(metadata.id, _attachmentUuid);
    expect(metadata.cashPaymentId, _parentUuid);

    return RemoteAttachmentPrepareResult(
      attachmentId: metadata.id,
      storageKey: storageKey,
      uploadUrl: 'https://storage.test/upload',
      expiresInSeconds: 1800,
    );
  }

  @override
  Future<void> uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    uploadCalls += 1;
    uploadedBytes = Uint8List.fromList(bytes);

    expect(uploadUrl, 'https://storage.test/upload');
    expect(mimeType, 'application/pdf');
  }

  @override
  Future<RemoteCashPaymentAttachmentRecord> confirm(
    CashPaymentAttachmentUploadMetadata metadata,
  ) async {
    confirmCalls += 1;

    return RemoteCashPaymentAttachmentRecord(
      id: metadata.id,
      cashPaymentId: metadata.cashPaymentId,
      kind: metadata.kind,
      fileName: metadata.fileName,
      mimeType: metadata.mimeType,
      originalFileSize: metadata.originalFileSize,
      fileSize: metadata.fileSize,
      sha256: metadata.sha256,
      storageKey: storageKey,
      deletedAt: null,
      createdAt: DateTime.utc(2026, 8, 16, 12),
      updatedAt: DateTime.utc(2026, 8, 16, 12, 1),
    );
  }

  @override
  Future<RemoteCashPaymentAttachmentChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = RemoteCashPaymentAttachmentRepository.defaultChangesLimit,
  }) async {
    changesCalls += 1;

    return const RemoteCashPaymentAttachmentChangesPage(
      items: <RemoteCashPaymentAttachmentRecord>[],
      hasMore: false,
      nextCursor: null,
    );
  }
}

void main() {
  late Database db;
  late Directory tempDirectory;

  late LocalCashPaymentRepository cashRepository;
  late LocalCashPaymentAttachmentRepository attachmentRepository;
  late SyncQueueRepository queueRepository;
  late _FakeAttachmentRemote attachmentRemote;

  setUp(() async {
    db = sqlite3.openInMemory();

    MigrationManager.migrate(db);

    DatabaseService.instance.injectDatabaseForTesting(db);

    tempDirectory = await Directory.systemTemp.createTemp(
      'pharmaflow_attachment_sync_c3_',
    );

    final fixture = _seedDependencies(db);

    _insertParentCashPayment(
      db,
      id: 1,
      serverUuid: _parentUuid,
      companyId: fixture.companyLocalId,
      bankAccountId: fixture.bankLocalId,
    );

    cashRepository = LocalCashPaymentRepository(DatabaseService.instance);

    attachmentRepository = LocalCashPaymentAttachmentRepository(
      DatabaseService.instance,
    );

    queueRepository = SyncQueueRepository(DatabaseService.instance);

    attachmentRemote = _FakeAttachmentRemote();
  });

  tearDown(() async {
    DatabaseService.instance.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'CASH_PAYMENT_ATTACHMENT CREATE runs as phase 5 after CASH_PAYMENT',
    () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

      final file = File(
        '${tempDirectory.path}'
        '${Platform.pathSeparator}'
        '$_attachmentUuid.pdf',
      );

      await file.writeAsBytes(bytes, flush: true);

      final now = DateTime.utc(2026, 8, 16, 13);

      final attachmentId = await attachmentRepository.insert(
        CashPaymentAttachment(
          serverUuid: _attachmentUuid,
          cashPaymentId: 1,
          kind: CashPaymentAttachmentKind.statement,
          fileName: 'statement.pdf',
          mimeType: 'application/pdf',
          originalFileSize: bytes.length,
          fileSize: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          localPath: file.path,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = _buildSyncService(
        cashRepository: cashRepository,
        attachmentRepository: attachmentRepository,
        queueRepository: queueRepository,
        attachmentRemote: attachmentRemote,
      );

      final result = await service.sync();

      expect(result.failed, 0);
      expect(result.processed, 1);
      expect(result.succeeded, 1);

      expect(attachmentRemote.prepareCalls, 1);
      expect(attachmentRemote.uploadCalls, 1);
      expect(attachmentRemote.confirmCalls, 1);

      expect(
        attachmentRemote.changesCalls,
        1,
        reason: 'Phase 5B pull must run after successful attachment push.',
      );

      expect(attachmentRemote.uploadedBytes, orderedEquals(bytes));

      final saved = await attachmentRepository.findById(attachmentId);

      expect(saved, isNotNull);

      expect(saved!.storageKey, _FakeAttachmentRemote.storageKey);

      final queueItems = await queueRepository.getAllItems();

      final attachmentQueue = queueItems
          .where(
            (item) =>
                item.entityType == syncEntityTypeCashPaymentAttachment &&
                item.entityId == attachmentId,
          )
          .toList();

      expect(attachmentQueue, hasLength(1));
      expect(attachmentQueue.single.status, SyncStatus.synced);
    },
  );

  test(
    'CASH_PAYMENT failure gates older CASH_PAYMENT_ATTACHMENT work',
    () async {
      final bytes = Uint8List.fromList(<int>[9, 8, 7, 6]);

      final file = File(
        '${tempDirectory.path}'
        '${Platform.pathSeparator}'
        'gated.pdf',
      );

      await file.writeAsBytes(bytes, flush: true);

      final now = DateTime.utc(2026, 8, 16, 14);

      final attachmentId = await attachmentRepository.insert(
        CashPaymentAttachment(
          serverUuid: _attachmentUuid,
          cashPaymentId: 1,
          kind: CashPaymentAttachmentKind.statement,
          fileName: 'gated.pdf',
          mimeType: 'application/pdf',
          originalFileSize: bytes.length,
          fileSize: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          localPath: file.path,
          createdAt: now,
          updatedAt: now,
        ),
      );

      /*
       * This CASH_PAYMENT item is newer than the attachment item and
       * deliberately references a missing local payment.
       *
       * Dependency order must win over queue chronology:
       * CASH_PAYMENT must fail first and attachment Phase 5 must not run.
       */
      await queueRepository.add(
        SyncQueueItem(
          entityType: syncEntityTypeCashPayment,
          entityId: 999999,
          operation: SyncOperation.create,
          status: SyncStatus.pending,
          retryCount: 0,
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );

      final service = _buildSyncService(
        cashRepository: cashRepository,
        attachmentRepository: attachmentRepository,
        queueRepository: queueRepository,
        attachmentRemote: attachmentRemote,
      );

      final result = await service.sync();

      expect(result.failed, 1);

      expect(attachmentRemote.prepareCalls, 0);
      expect(attachmentRemote.uploadCalls, 0);
      expect(attachmentRemote.confirmCalls, 0);

      expect(
        attachmentRemote.changesCalls,
        0,
        reason: 'Attachment pull must also be gated by CASH_PAYMENT failure.',
      );

      final processable = await queueRepository.getProcessable();

      final attachmentItems = processable
          .where(
            (item) =>
                item.entityType == syncEntityTypeCashPaymentAttachment &&
                item.entityId == attachmentId,
          )
          .toList();

      expect(attachmentItems, hasLength(1));

      expect(
        attachmentItems.single.status,
        SyncStatus.pending,
        reason: 'Gated attachment work must remain untouched for a later run.',
      );

      final failedCashItems = (await queueRepository.getAllItems())
          .where(
            (item) =>
                item.entityType == syncEntityTypeCashPayment &&
                item.entityId == 999999,
          )
          .toList();

      expect(failedCashItems, hasLength(1));
      expect(failedCashItems.single.status, SyncStatus.failed);
    },
  );
}

SyncService _buildSyncService({
  required LocalCashPaymentRepository cashRepository,
  required LocalCashPaymentAttachmentRepository attachmentRepository,
  required SyncQueueRepository queueRepository,
  required _FakeAttachmentRemote attachmentRemote,
}) {
  final localCompanyRepository = LocalCompanyRepository(
    DatabaseService.instance,
  );

  final localBankRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );

  final localChequeRepository = LocalChequeRepository(DatabaseService.instance);

  final identityResolver = SyncIdentityResolver(DatabaseService.instance);

  final apiClient = ApiClient();

  final remoteCompanyRepository = RemoteCompanyRepository(apiClient);

  final remoteBankRepository = RemoteBankAccountsRepository(apiClient);

  final remoteChequeRepository = RemoteChequeRepository(apiClient);

  final pushService = CashPaymentAttachmentPushService(
    localAttachmentRepository: attachmentRepository,
    localCashPaymentRepository: cashRepository,
    remoteAttachmentRepository: attachmentRemote,
    syncQueueRepository: queueRepository,
  );

  final pullService = CashPaymentAttachmentPullMergeService(
    databaseService: DatabaseService.instance,
    remoteRepository: attachmentRemote,
    cursorRepository: SyncCursorRepository(DatabaseService.instance),
  );

  return SyncService(
    syncQueueRepository: queueRepository,
    localCompanyRepository: localCompanyRepository,
    localBankAccountRepository: localBankRepository,
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
    cashPaymentAttachmentPushService: pushService,
    cashPaymentAttachmentPullMergeService: pullService,
  );
}

({int companyLocalId, int bankLocalId}) _seedDependencies(Database db) {
  const companyUuid = '33333333-3333-4333-8333-333333333333';

  const bankUuid = '44444444-4444-4444-8444-444444444444';

  final now = DateTime.utc(2026, 8, 16, 6);

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
    <Object?>[
      companyUuid,
      'Attachment Sync Company',
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ],
  );

  final companyLocalId =
      db.select('SELECT last_insert_rowid() AS id').single['id'] as int;

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
    <Object?>[
      bankUuid,
      'Test Bank',
      'Main',
      'Pharmacy',
      'TEST-ACCOUNT-C3',
      '6037991234567890',
      'IR000000000000000000000000',
      'Attachment sync C3',
      0,
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ],
  );

  final bankLocalId =
      db.select('SELECT last_insert_rowid() AS id').single['id'] as int;

  return (companyLocalId: companyLocalId, bankLocalId: bankLocalId);
}

void _insertParentCashPayment(
  Database db, {
  required int id,
  required String serverUuid,
  required int companyId,
  required int bankAccountId,
}) {
  final now = DateTime.utc(2026, 8, 16, 7).millisecondsSinceEpoch;

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
      companyId,
      bankAccountId,
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
}
