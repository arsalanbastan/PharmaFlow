import 'package:sqlite3/sqlite3.dart';

import '../database/database_service.dart';
import '../../data/mappers/cash_payment_attachment_mapper.dart';
import '../../data/repositories/local/sync_cursor_repository.dart';
import '../../data/repositories/remote/remote_cash_payment_attachment_repository.dart';
import 'sync_cursor.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class CashPaymentAttachmentPullMergeException implements Exception {
  const CashPaymentAttachmentPullMergeException(this.message);

  final String message;

  @override
  String toString() => 'CashPaymentAttachmentPullMergeException: $message';
}

class CashPaymentAttachmentPullBlockedByLocalChangesException
    extends CashPaymentAttachmentPullMergeException {
  const CashPaymentAttachmentPullBlockedByLocalChangesException({
    required this.localId,
    required this.serverUuid,
  }) : super(
         'Cash payment attachment pull merge blocked because local '
         'attachment $localId has unsynced work.',
       );

  final int localId;
  final String serverUuid;
}

class CashPaymentAttachmentMergeConflictException
    extends CashPaymentAttachmentPullMergeException {
  const CashPaymentAttachmentMergeConflictException(super.message);
}

class CashPaymentAttachmentPullMergeResult {
  const CashPaymentAttachmentPullMergeResult({
    required this.pagesFetched,
    required this.changesReceived,
    required this.uniqueChanges,
    required this.inserted,
    required this.updated,
    required this.tombstonesApplied,
    required this.tombstonesIgnored,
    required this.cursorBefore,
    required this.cursorAfter,
  });

  final int pagesFetched;
  final int changesReceived;
  final int uniqueChanges;
  final int inserted;
  final int updated;
  final int tombstonesApplied;
  final int tombstonesIgnored;

  final SyncCursor? cursorBefore;
  final SyncCursor? cursorAfter;

  bool get changedLocalData =>
      inserted > 0 || updated > 0 || tombstonesApplied > 0;
}

class CashPaymentAttachmentPullMergeService {
  factory CashPaymentAttachmentPullMergeService({
    required DatabaseService databaseService,
    required RemoteCashPaymentAttachmentRepository remoteRepository,
    required SyncCursorRepository cursorRepository,
    int pageLimit = RemoteCashPaymentAttachmentRepository.defaultChangesLimit,
  }) {
    return CashPaymentAttachmentPullMergeService._(
      databaseService,
      remoteRepository,
      cursorRepository,
      pageLimit,
    );
  }

  CashPaymentAttachmentPullMergeService._(
    this._databaseService,
    this._remoteRepository,
    this._cursorRepository,
    this.pageLimit,
  );

  static const int _maximumPagesPerRun = 10000;

  final DatabaseService _databaseService;
  final RemoteCashPaymentAttachmentRepository _remoteRepository;
  final SyncCursorRepository _cursorRepository;

  final int pageLimit;

  Future<CashPaymentAttachmentPullMergeResult> pullAndMerge() async {
    final cursorBefore = await _cursorRepository.getByEntityType(
      syncEntityTypeCashPaymentAttachment,
    );

    var requestCursor = cursorBefore;
    var cursorAfter = cursorBefore;

    var pagesFetched = 0;
    var changesReceived = 0;

    final latestChangesByUuid = <String, RemoteCashPaymentAttachmentRecord>{};

    while (true) {
      if (pagesFetched >= _maximumPagesPerRun) {
        throw const CashPaymentAttachmentPullMergeException(
          'Cash payment attachment pull exceeded the maximum allowed '
          'page count.',
        );
      }

      final page = await _remoteRepository.getChanges(
        cursor: requestCursor,
        limit: pageLimit,
      );

      pagesFetched += 1;
      changesReceived += page.items.length;

      _validatePage(page: page, requestCursor: requestCursor);

      for (final change in page.items) {
        latestChangesByUuid[change.id] = change;
      }

      if (page.nextCursor != null) {
        cursorAfter = page.nextCursor;
      }

      if (!page.hasMore) {
        break;
      }

      requestCursor = page.nextCursor;
    }

    if (latestChangesByUuid.isEmpty) {
      return CashPaymentAttachmentPullMergeResult(
        pagesFetched: pagesFetched,
        changesReceived: changesReceived,
        uniqueChanges: 0,
        inserted: 0,
        updated: 0,
        tombstonesApplied: 0,
        tombstonesIgnored: 0,
        cursorBefore: cursorBefore,
        cursorAfter: cursorAfter,
      );
    }

    final changes = latestChangesByUuid.values.toList(growable: false);

    var inserted = 0;
    var updated = 0;
    var tombstonesApplied = 0;
    var tombstonesIgnored = 0;

    _databaseService.transaction((db) {
      final localIdsByUuid = <String, int?>{};
      final parentIdsByUuid = <String, int>{};

      // ------------------------------------------------------
      // PRE-FLIGHT
      // Nothing is mutated until all incoming changes pass.
      // ------------------------------------------------------

      for (final change in changes) {
        final localId = _findLocalAttachmentIdByServerUuid(db, change.id);

        localIdsByUuid[change.id] = localId;

        if (localId != null && _hasActiveLocalSyncWork(db, localId)) {
          throw CashPaymentAttachmentPullBlockedByLocalChangesException(
            localId: localId,
            serverUuid: change.id,
          );
        }

        // Historical tombstone that never existed on this device.
        if (localId == null && change.isDeleted) {
          continue;
        }

        if (change.isDeleted) {
          // Existing tombstones keep their existing parent mapping.
          parentIdsByUuid[change.id] = _existingParentLocalId(db, localId!);

          continue;
        }

        final parentLocalId = _requireCashPaymentLocalId(
          db,
          cashPaymentUuid: change.cashPaymentId,
          attachmentUuid: change.id,
        );

        if (localId != null) {
          final existingParentId = _existingParentLocalId(db, localId);

          if (existingParentId != parentLocalId) {
            throw CashPaymentAttachmentMergeConflictException(
              'Attachment ${change.id} is linked to local cash payment '
              '$existingParentId but server resolves it to '
              '$parentLocalId.',
            );
          }
        }

        parentIdsByUuid[change.id] = parentLocalId;
      }

      // ------------------------------------------------------
      // APPLY FINAL SERVER STATE
      // ------------------------------------------------------

      for (final change in changes) {
        final localId = localIdsByUuid[change.id];

        if (localId == null && change.isDeleted) {
          tombstonesIgnored += 1;
          continue;
        }

        final parentLocalId = parentIdsByUuid[change.id]!;

        final values = <String, Object?>{
          'server_uuid': change.id,
          'cash_payment_id': parentLocalId,
          'kind': CashPaymentAttachmentMapper.kindToWireValue(change.kind),
          'file_name': change.fileName,
          'mime_type': change.mimeType.trim().toLowerCase(),
          'original_file_size': change.originalFileSize,
          'file_size': change.fileSize,
          'sha256': change.sha256.trim().toLowerCase(),
          'storage_key': change.storageKey.trim(),
          'deleted_at': change.deletedAt?.millisecondsSinceEpoch,
          'created_at': change.createdAt.millisecondsSinceEpoch,
          'updated_at': change.updatedAt.millisecondsSinceEpoch,
        };

        if (localId == null) {
          _insertRemoteAttachment(db, values);
          inserted += 1;
        } else {
          _updateRemoteAttachment(db, localId: localId, values: values);

          updated += 1;
        }

        if (change.isDeleted) {
          tombstonesApplied += 1;
        }
      }

      // ------------------------------------------------------
      // CURSOR ADVANCE IN SAME TRANSACTION
      // ------------------------------------------------------

      final finalCursor = cursorAfter;

      if (finalCursor != null) {
        _cursorRepository.upsertInDatabase(db, finalCursor);
      }
    });

    return CashPaymentAttachmentPullMergeResult(
      pagesFetched: pagesFetched,
      changesReceived: changesReceived,
      uniqueChanges: changes.length,
      inserted: inserted,
      updated: updated,
      tombstonesApplied: tombstonesApplied,
      tombstonesIgnored: tombstonesIgnored,
      cursorBefore: cursorBefore,
      cursorAfter: cursorAfter,
    );
  }

  void _validatePage({
    required RemoteCashPaymentAttachmentChangesPage page,
    required SyncCursor? requestCursor,
  }) {
    if (page.hasMore && page.nextCursor == null) {
      throw const CashPaymentAttachmentPullMergeException(
        'Attachment changes page hasMore=true but nextCursor is null.',
      );
    }

    if (page.items.isEmpty) {
      if (page.hasMore) {
        throw const CashPaymentAttachmentPullMergeException(
          'Attachment changes page is empty while hasMore=true.',
        );
      }

      return;
    }

    RemoteCashPaymentAttachmentRecord? previousItem;

    for (final item in page.items) {
      if (previousItem != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.id,
            cursorUpdatedAt: previousItem.updatedAt,
            cursorServerUuid: previousItem.id,
          )) {
        throw const CashPaymentAttachmentPullMergeException(
          'Attachment changes page is not strictly ordered by '
          'updatedAt and server UUID.',
        );
      }

      if (requestCursor != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.id,
            cursorUpdatedAt: requestCursor.updatedAt,
            cursorServerUuid: requestCursor.serverUuid,
          )) {
        throw const CashPaymentAttachmentPullMergeException(
          'Attachment changes page contains an item at or before '
          'the requested cursor.',
        );
      }

      previousItem = item;
    }

    final nextCursor = page.nextCursor;

    if (nextCursor == null) {
      throw const CashPaymentAttachmentPullMergeException(
        'Non-empty attachment changes page has no next cursor.',
      );
    }

    if (nextCursor.entityType.trim().toUpperCase() !=
        syncEntityTypeCashPaymentAttachment) {
      throw const CashPaymentAttachmentPullMergeException(
        'Attachment changes nextCursor has an invalid entity type.',
      );
    }

    final lastItem = page.items.last;

    if (!nextCursor.updatedAt.isAtSameMomentAs(lastItem.updatedAt) ||
        nextCursor.serverUuid.trim() != lastItem.id.trim()) {
      throw const CashPaymentAttachmentPullMergeException(
        'Attachment changes nextCursor does not match the last page item.',
      );
    }

    if (requestCursor != null &&
        !_isPositionAfter(
          itemUpdatedAt: nextCursor.updatedAt,
          itemServerUuid: nextCursor.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
      throw const CashPaymentAttachmentPullMergeException(
        'Attachment changes cursor did not advance.',
      );
    }
  }

  bool _isPositionAfter({
    required DateTime itemUpdatedAt,
    required String itemServerUuid,
    required DateTime cursorUpdatedAt,
    required String cursorServerUuid,
  }) {
    final itemTime = itemUpdatedAt.toUtc();
    final cursorTime = cursorUpdatedAt.toUtc();

    if (itemTime.isAfter(cursorTime)) {
      return true;
    }

    if (itemTime.isBefore(cursorTime)) {
      return false;
    }

    return itemServerUuid.trim().compareTo(cursorServerUuid.trim()) > 0;
  }

  int? _findLocalAttachmentIdByServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM cash_payment_attachments
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw CashPaymentAttachmentMergeConflictException(
        'More than one local attachment has server UUID '
        '$serverUuid.',
      );
    }

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['id'] as int;
  }

  bool _hasActiveLocalSyncWork(Database db, int localId) {
    final rows = db.select(
      '''
SELECT id
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
  AND status IN (?, ?, ?)
LIMIT 1
''',
      [
        syncEntityTypeCashPaymentAttachment,
        localId,
        SyncStatus.pending.dbValue,
        SyncStatus.failed.dbValue,
        SyncStatus.processing.dbValue,
      ],
    );

    return rows.isNotEmpty;
  }

  int _requireCashPaymentLocalId(
    Database db, {
    required String cashPaymentUuid,
    required String attachmentUuid,
  }) {
    final rows = db.select(
      '''
SELECT id
FROM cash_payments
WHERE server_uuid = ?
  AND deleted_at IS NULL
LIMIT 2
''',
      [cashPaymentUuid.trim()],
    );

    if (rows.length > 1) {
      throw CashPaymentAttachmentMergeConflictException(
        'Cash payment server UUID $cashPaymentUuid maps to multiple '
        'local rows while merging attachment $attachmentUuid.',
      );
    }

    if (rows.isEmpty) {
      throw CashPaymentAttachmentMergeConflictException(
        'Cash payment server UUID $cashPaymentUuid is missing locally '
        'while merging attachment $attachmentUuid.',
      );
    }

    return rows.first['id'] as int;
  }

  int _existingParentLocalId(Database db, int attachmentLocalId) {
    final rows = db.select(
      '''
SELECT cash_payment_id
FROM cash_payment_attachments
WHERE id = ?
LIMIT 1
''',
      [attachmentLocalId],
    );

    if (rows.isEmpty) {
      throw CashPaymentAttachmentMergeConflictException(
        'Attachment local id $attachmentLocalId disappeared during merge.',
      );
    }

    return rows.first['cash_payment_id'] as int;
  }

  void _insertRemoteAttachment(Database db, Map<String, Object?> values) {
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
VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, NULL, ?, ?, ?)
''',
      [
        values['server_uuid'],
        values['cash_payment_id'],
        values['kind'],
        values['file_name'],
        values['mime_type'],
        values['original_file_size'],
        values['file_size'],
        values['sha256'],
        values['storage_key'],
        values['deleted_at'],
        values['created_at'],
        values['updated_at'],
      ],
    );
  }

  void _updateRemoteAttachment(
    Database db, {
    required int localId,
    required Map<String, Object?> values,
  }) {
    /*
     * local_path is intentionally NOT overwritten.
     *
     * It belongs only to the current device. A server metadata refresh
     * must not discard an already cached/downloaded local file.
     */
    db.execute(
      '''
UPDATE cash_payment_attachments
SET
  server_uuid = ?,
  cash_payment_id = ?,
  kind = ?,
  file_name = ?,
  mime_type = ?,
  original_file_size = ?,
  file_size = ?,
  sha256 = ?,
  storage_key = ?,
  delete_requested_at = NULL,
  deleted_at = ?,
  created_at = ?,
  updated_at = ?
WHERE id = ?
''',
      [
        values['server_uuid'],
        values['cash_payment_id'],
        values['kind'],
        values['file_name'],
        values['mime_type'],
        values['original_file_size'],
        values['file_size'],
        values['sha256'],
        values['storage_key'],
        values['deleted_at'],
        values['created_at'],
        values['updated_at'],
        localId,
      ],
    );
  }
}
