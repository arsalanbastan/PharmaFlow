import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/network/api_client.dart';
import 'package:pharmaflow/core/sync/cheque_attachment_push_service.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/cheque_attachment.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_attachment_repository.dart';
import 'package:pharmaflow/data/repositories/local/local_cheque_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';
import 'package:pharmaflow/data/repositories/remote/remote_cheque_attachment_repository.dart';
import 'package:sqlite3/sqlite3.dart';

const _parentUuid = '11111111-1111-4111-8111-111111111111';

class _FakeRemoteAttachmentRepository extends RemoteChequeAttachmentRepository {
  _FakeRemoteAttachmentRepository() : super(ApiClient());

  int prepareCalls = 0;
  int uploadCalls = 0;
  int confirmCalls = 0;
  int deleteCalls = 0;

  ChequeAttachmentUploadMetadata? lastMetadata;
  Uint8List? uploadedBytes;

  static const storageKey =
      'cheques/'
      '11111111-1111-4111-8111-111111111111/'
      '22222222-2222-4222-8222-222222222222.pdf';

  @override
  Future<RemoteAttachmentPrepareResult> prepareUpload(
    ChequeAttachmentUploadMetadata metadata,
  ) async {
    prepareCalls += 1;
    lastMetadata = metadata;

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
  Future<RemoteChequeAttachmentRecord> confirm(
    ChequeAttachmentUploadMetadata metadata,
  ) async {
    confirmCalls += 1;

    return RemoteChequeAttachmentRecord(
      id: metadata.id,
      chequeId: metadata.chequeId,
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
  Future<void> delete(String attachmentUuid) async {
    deleteCalls += 1;
    expect(attachmentUuid, '22222222-2222-4222-8222-222222222222');
  }
}

void main() {
  late Database db;
  late Directory tempDirectory;

  late LocalChequeAttachmentRepository localAttachmentRepository;
  late LocalChequeRepository localChequeRepository;
  late SyncQueueRepository queueRepository;
  late _FakeRemoteAttachmentRepository remoteRepository;
  late ChequeAttachmentPushService service;

  setUp(() async {
    db = sqlite3.openInMemory();

    MigrationManager.migrate(db);

    DatabaseService.instance.injectDatabaseForTesting(db);

    tempDirectory = await Directory.systemTemp.createTemp(
      'pharmaflow_attachment_push_',
    );

    _insertParentCheque(db, id: 1, serverUuid: _parentUuid);

    localAttachmentRepository = LocalChequeAttachmentRepository(
      DatabaseService.instance,
    );

    localChequeRepository = LocalChequeRepository(DatabaseService.instance);

    queueRepository = SyncQueueRepository(DatabaseService.instance);

    remoteRepository = _FakeRemoteAttachmentRepository();

    service = ChequeAttachmentPushService(
      localAttachmentRepository: localAttachmentRepository,
      localChequeRepository: localChequeRepository,
      remoteAttachmentRepository: remoteRepository,
      syncQueueRepository: queueRepository,
    );
  });

  tearDown(() async {
    DatabaseService.instance.close();

    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'CREATE performs prepare upload confirm persists storage key and syncs queue',
    () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

      final attachmentId = await _insertAttachment(
        repository: localAttachmentRepository,
        directory: tempDirectory,
        bytes: bytes,
      );

      final pending = await queueRepository.getPending();

      final createItem = pending.singleWhere(
        (item) =>
            item.entityType == syncEntityTypeChequeAttachment &&
            item.entityId == attachmentId &&
            item.operation == SyncOperation.create,
      );

      await queueRepository.markProcessing(createItem.id!);

      final result = await service.push(createItem);

      expect(result, isTrue);

      expect(remoteRepository.prepareCalls, 1);
      expect(remoteRepository.uploadCalls, 1);
      expect(remoteRepository.confirmCalls, 1);

      expect(remoteRepository.lastMetadata?.chequeId, _parentUuid);

      expect(
        remoteRepository.lastMetadata?.id,
        '22222222-2222-4222-8222-222222222222',
      );

      expect(remoteRepository.uploadedBytes, orderedEquals(bytes));

      final saved = await localAttachmentRepository.findById(attachmentId);

      expect(saved, isNotNull);
      expect(saved!.storageKey, _FakeRemoteAttachmentRepository.storageKey);

      final queueAfter = await queueRepository.findById(createItem.id!);

      expect(queueAfter, isNotNull);
      expect(queueAfter!.status, SyncStatus.synced);
    },
  );

  test(
    'delete intent during PROCESSING CREATE becomes follow-up DELETE',
    () async {
      final bytes = Uint8List.fromList(<int>[5, 6, 7, 8]);

      final attachmentId = await _insertAttachment(
        repository: localAttachmentRepository,
        directory: tempDirectory,
        bytes: bytes,
      );

      final pending = await queueRepository.getPending();

      final createItem = pending.singleWhere(
        (item) =>
            item.entityType == syncEntityTypeChequeAttachment &&
            item.entityId == attachmentId &&
            item.operation == SyncOperation.create,
      );

      await queueRepository.markProcessing(createItem.id!);

      await localAttachmentRepository.requestDelete(attachmentId);

      final beforeCreateCompletes = await queueRepository.getProcessable();

      expect(
        beforeCreateCompletes.where(
          (item) =>
              item.entityType == syncEntityTypeChequeAttachment &&
              item.entityId == attachmentId &&
              item.operation == SyncOperation.delete,
        ),
        isEmpty,
      );

      await service.push(createItem);

      final processable = await queueRepository.getProcessable();

      final deleteItems = processable
          .where(
            (item) =>
                item.entityType == syncEntityTypeChequeAttachment &&
                item.entityId == attachmentId &&
                item.operation == SyncOperation.delete &&
                item.status == SyncStatus.pending,
          )
          .toList();

      expect(deleteItems, hasLength(1));

      final deleteItem = deleteItems.single;

      await queueRepository.markProcessing(deleteItem.id!);

      final deleted = await service.push(deleteItem);

      expect(deleted, isTrue);
      expect(remoteRepository.deleteCalls, 1);

      expect(await queueRepository.findById(deleteItem.id!), isNull);
    },
  );

  test('CREATE rejects source file mutation before network upload', () async {
    final originalBytes = Uint8List.fromList(<int>[10, 11, 12, 13]);

    final attachmentId = await _insertAttachment(
      repository: localAttachmentRepository,
      directory: tempDirectory,
      bytes: originalBytes,
    );

    final saved = await localAttachmentRepository.findById(attachmentId);

    expect(saved, isNotNull);

    await File(
      saved!.localPath!,
    ).writeAsBytes(<int>[99, 98, 97, 96], flush: true);

    final pending = await queueRepository.getPending();

    final createItem = pending.singleWhere(
      (item) =>
          item.entityType == syncEntityTypeChequeAttachment &&
          item.entityId == attachmentId &&
          item.operation == SyncOperation.create,
    );

    await queueRepository.markProcessing(createItem.id!);

    await expectLater(
      service.push(createItem),
      throwsA(isA<ChequeAttachmentPushException>()),
    );

    expect(remoteRepository.prepareCalls, 0);
    expect(remoteRepository.uploadCalls, 0);
    expect(remoteRepository.confirmCalls, 0);
  });
}

Future<int> _insertAttachment({
  required LocalChequeAttachmentRepository repository,
  required Directory directory,
  required Uint8List bytes,
}) async {
  final file = File(
    '${directory.path}'
    '${Platform.pathSeparator}'
    '22222222-2222-4222-8222-222222222222.pdf',
  );

  await file.writeAsBytes(bytes, flush: true);

  final digest = sha256.convert(bytes).toString();

  final now = DateTime.now().toUtc();

  return repository.insert(
    ChequeAttachment(
      serverUuid: '22222222-2222-4222-8222-222222222222',
      chequeId: 1,
      kind: ChequeAttachmentKind.statement,
      fileName: 'statement.pdf',
      mimeType: 'application/pdf',
      originalFileSize: bytes.length,
      fileSize: bytes.length,
      sha256: digest,
      localPath: file.path,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _insertParentCheque(
  Database db, {
  required int id,
  required String serverUuid,
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;

  db.execute('PRAGMA foreign_keys = OFF;');

  db.execute(
    '''
INSERT INTO companies (
  id,
  server_uuid,
  name,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, NULL, ?, ?)
''',
    [1, '33333333-3333-4333-8333-333333333333', 'Test Company', now, now],
  );

  db.execute(
    '''
INSERT INTO bank_accounts (
  id,
  server_uuid,
  bank_name,
  account_title,
  account_holder,
  account_number,
  card_number,
  iban,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
''',
    [
      1,
      '44444444-4444-4444-8444-444444444444',
      'Test Bank',
      'Main',
      'Owner',
      '1',
      '2',
      'IR3',
      now,
      now,
    ],
  );

  db.execute(
    '''
INSERT INTO cheques (
  id,
  server_uuid,
  bank_account_id,
  company_id,
  receiver_name,
  cheque_number,
  amount_rial,
  issue_date,
  due_date,
  status,
  description,
  is_registered_in_sayad,
  sayad_id,
  image_data,
  archived_at,
  delete_requested_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
    [
      id,
      serverUuid,
      1,
      1,
      null,
      '1001',
      1000000,
      DateTime.utc(2026, 8, 15).toIso8601String(),
      DateTime.utc(2026, 9, 15).toIso8601String(),
      'Issued',
      null,
      0,
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
