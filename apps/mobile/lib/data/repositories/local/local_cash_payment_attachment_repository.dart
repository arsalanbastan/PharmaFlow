import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_trigger.dart';
import '../../../core/sync/sync_trigger_dispatcher.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../mappers/cash_payment_attachment_mapper.dart';
import '../../models/cash_payment_attachment.dart';
import '../interfaces/cash_payment_attachment_repository.dart';
import 'sync_queue_repository.dart';

class LocalCashPaymentAttachmentRepository
    implements CashPaymentAttachmentRepository {
  LocalCashPaymentAttachmentRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  SyncQueueRepository get _syncQueueRepository =>
      SyncQueueRepository(_databaseService);

  @override
  Future<int> insert(CashPaymentAttachment attachment) async {
    _validate(attachment);

    late final int insertedId;

    _databaseService.transaction((db) {
      _throwIfParentMissing(db, attachment.cashPaymentId);

      final requestedUuid = _trimOrNull(attachment.serverUuid);

      final serverUuid = requestedUuid ?? _generateUniqueServerUuid(db);

      _throwIfDuplicateServerUuid(db, serverUuid);

      final now = DateTime.now().toUtc();

      final entity = attachment.copyWith(
        id: null,
        serverUuid: serverUuid,
        fileName: attachment.fileName.trim(),
        mimeType: attachment.mimeType.trim().toLowerCase(),
        sha256: attachment.sha256.trim().toLowerCase(),
        localPath: _trimOrNull(attachment.localPath),
        storageKey: _trimOrNull(attachment.storageKey),
        createdAt: attachment.createdAt.toUtc(),
        updatedAt: now,
      );

      final values = CashPaymentAttachmentMapper.toMap(entity);

      final statement = db.prepare('''
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
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''');

      try {
        statement.execute([
          values['server_uuid'],
          values['cash_payment_id'],
          values['kind'],
          values['file_name'],
          values['mime_type'],
          values['original_file_size'],
          values['file_size'],
          values['sha256'],
          values['local_path'],
          values['storage_key'],
          values['delete_requested_at'],
          values['deleted_at'],
          values['created_at'],
          values['updated_at'],
        ]);
      } finally {
        statement.dispose();
      }

      insertedId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      _syncQueueRepository.addInDatabase(
        db,
        SyncQueueItem(
          entityType: syncEntityTypeCashPaymentAttachment,
          entityId: insertedId,
          operation: SyncOperation.create,
          status: SyncStatus.pending,
          retryCount: 0,
          createdAt: now,
        ),
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);

    return insertedId;
  }

  @override
  Future<CashPaymentAttachment?> findById(int id) async {
    final rows = _db.select(
      '''
SELECT *
FROM cash_payment_attachments
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (rows.isEmpty) {
      return null;
    }

    return CashPaymentAttachmentMapper.fromMap(rows.first);
  }

  @override
  Future<CashPaymentAttachment?> findByServerUuid(String serverUuid) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      return null;
    }

    final rows = _db.select(
      '''
SELECT *
FROM cash_payment_attachments
WHERE server_uuid = ?
LIMIT 1
''',
      [normalized],
    );

    if (rows.isEmpty) {
      return null;
    }

    return CashPaymentAttachmentMapper.fromMap(rows.first);
  }

  @override
  Future<List<CashPaymentAttachment>> findByCashPaymentId(
    int cashPaymentId, {
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  }) async {
    return _findWhere(
      cashPaymentId: cashPaymentId,
      includeDeleteRequested: includeDeleteRequested,
      includeDeleted: includeDeleted,
    );
  }

  @override
  Future<List<CashPaymentAttachment>> getAll({
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  }) async {
    return _findWhere(
      includeDeleteRequested: includeDeleteRequested,
      includeDeleted: includeDeleted,
    );
  }

  List<CashPaymentAttachment> _findWhere({
    int? cashPaymentId,
    required bool includeDeleteRequested,
    required bool includeDeleted,
  }) {
    final clauses = <String>[];
    final parameters = <Object?>[];

    if (!includeDeleted) {
      clauses.add('deleted_at IS NULL');
    }

    if (!includeDeleteRequested) {
      clauses.add('delete_requested_at IS NULL');
    }

    if (cashPaymentId != null) {
      clauses.add('cash_payment_id = ?');
      parameters.add(cashPaymentId);
    }

    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

    final rows = _db.select('''
SELECT *
FROM cash_payment_attachments
$where
ORDER BY created_at DESC, id DESC
''', parameters);

    return rows.map(CashPaymentAttachmentMapper.fromMap).toList();
  }

  @override
  Future<void> requestDelete(int id) async {
    final attachment = await findById(id);

    if (attachment == null) {
      throw StateError(
        'Cash payment attachment '
        '$id not found locally.',
      );
    }

    if (attachment.deleteRequestedAt != null) {
      return;
    }

    final now = DateTime.now().toUtc();

    _databaseService.transaction((db) {
      db.execute(
        '''
UPDATE cash_payment_attachments
SET
  delete_requested_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, id],
      );

      _syncQueueRepository.enqueueDeleteWithMergeInDatabase(
        db,
        entityType: syncEntityTypeCashPaymentAttachment,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  Future<void> applyConfirmedRemoteState({
    required int id,
    required String storageKey,
    required DateTime updatedAt,
  }) async {
    final normalizedStorageKey = storageKey.trim();

    if (normalizedStorageKey.isEmpty) {
      throw ArgumentError('Attachment storageKey cannot be empty.');
    }

    final existing = await findById(id);

    if (existing == null) {
      throw StateError('Cash payment attachment $id not found locally.');
    }

    _db.execute(
      '''
UPDATE cash_payment_attachments
SET
  storage_key = ?,
  deleted_at = NULL,
  updated_at = ?
WHERE id = ?
''',
      [normalizedStorageKey, updatedAt.toUtc().millisecondsSinceEpoch, id],
    );
  }

  Future<void> applyDownloadedLocalPath({
    required int id,
    required String localPath,
  }) async {
    final normalized = localPath.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Downloaded attachment localPath cannot be empty.');
    }

    final existing = _db.select(
      '''
SELECT id
FROM cash_payment_attachments
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (existing.isEmpty) {
      throw StateError('Cash payment attachment $id not found locally.');
    }

    // local_path is device-local cache state only.
    // Do not enqueue UPDATE and do not change server metadata.
    _db.execute(
      '''
UPDATE cash_payment_attachments
SET local_path = ?
WHERE id = ?
''',
      [normalized, id],
    );
  }

  void _validate(CashPaymentAttachment attachment) {
    if (attachment.cashPaymentId <= 0) {
      throw ArgumentError(
        'Cash payment attachment '
        'cashPaymentId must be positive.',
      );
    }

    if (attachment.fileName.trim().isEmpty) {
      throw ArgumentError('Attachment fileName cannot be empty.');
    }

    final mimeType = attachment.mimeType.trim().toLowerCase();

    const allowedMimeTypes = <String>{
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    };

    if (!allowedMimeTypes.contains(mimeType)) {
      throw ArgumentError(
        'Unsupported attachment MIME type: '
        '$mimeType',
      );
    }

    if (attachment.fileSize <= 0) {
      throw ArgumentError('Attachment fileSize must be positive.');
    }

    const maximumFileSize = 25 * 1024 * 1024;

    if (attachment.fileSize > maximumFileSize) {
      throw ArgumentError('Attachment exceeds the 25 MB limit.');
    }

    final originalFileSize = attachment.originalFileSize;

    if (originalFileSize != null && originalFileSize <= 0) {
      throw ArgumentError(
        'originalFileSize must be positive '
        'when provided.',
      );
    }

    final sha256 = attachment.sha256.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256)) {
      throw ArgumentError(
        'Attachment SHA256 must be '
        '64 hexadecimal characters.',
      );
    }
  }

  void _throwIfParentMissing(Database db, int cashPaymentId) {
    final rows = db.select(
      '''
SELECT id
FROM cash_payments
WHERE id = ?
  AND deleted_at IS NULL
LIMIT 1
''',
      [cashPaymentId],
    );

    if (rows.isEmpty) {
      throw StateError(
        'Parent cash payment '
        '$cashPaymentId not found locally.',
      );
    }
  }

  String _generateUniqueServerUuid(Database db) {
    while (true) {
      final candidate = generateUuidV4();

      final rows = db.select(
        '''
SELECT id
FROM cash_payment_attachments
WHERE server_uuid = ?
LIMIT 1
''',
        [candidate],
      );

      if (rows.isEmpty) {
        return candidate;
      }
    }
  }

  void _throwIfDuplicateServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM cash_payment_attachments
WHERE server_uuid = ?
LIMIT 1
''',
      [serverUuid],
    );

    if (rows.isNotEmpty) {
      throw StateError(
        'Cash payment attachment '
        'server UUID already exists locally: '
        '$serverUuid',
      );
    }
  }

  String? _trimOrNull(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();

    return normalized.isEmpty ? null : normalized;
  }
}
