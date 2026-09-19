import 'dart:io';

import 'package:crypto/crypto.dart';

import '../network/api_client.dart';
import '../../data/models/cheque_attachment.dart';
import '../../data/repositories/local/local_cheque_attachment_repository.dart';
import '../../data/repositories/local/local_cheque_repository.dart';
import '../../data/repositories/local/sync_queue_repository.dart';
import '../../data/repositories/remote/remote_cheque_attachment_repository.dart';
import 'sync_operation.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class ChequeAttachmentPushException implements Exception {
  const ChequeAttachmentPushException(this.message);

  final String message;

  @override
  String toString() => 'ChequeAttachmentPushException: $message';
}

class ChequeAttachmentPushService {
  const ChequeAttachmentPushService({
    required LocalChequeAttachmentRepository localAttachmentRepository,
    required LocalChequeRepository localChequeRepository,
    required RemoteChequeAttachmentRepository remoteAttachmentRepository,
    required SyncQueueRepository syncQueueRepository,
  }) : _localAttachmentRepository = localAttachmentRepository,
       _localChequeRepository = localChequeRepository,
       _remoteAttachmentRepository = remoteAttachmentRepository,
       _syncQueueRepository = syncQueueRepository;

  final LocalChequeAttachmentRepository _localAttachmentRepository;
  final LocalChequeRepository _localChequeRepository;
  final RemoteChequeAttachmentRepository _remoteAttachmentRepository;
  final SyncQueueRepository _syncQueueRepository;

  Future<bool> push(SyncQueueItem item) async {
    final entityType = item.entityType.trim().toUpperCase();

    if (entityType != syncEntityTypeChequeAttachment) {
      throw ChequeAttachmentPushException(
        'Expected CHEQUE_ATTACHMENT queue item, '
        'received ${item.entityType}.',
      );
    }

    final queueId = item.id;

    if (queueId == null) {
      throw const ChequeAttachmentPushException(
        'Attachment queue item has no id.',
      );
    }

    final attachment = await _localAttachmentRepository.findById(item.entityId);

    if (attachment == null || attachment.id == null) {
      throw ChequeAttachmentPushException(
        'Cheque attachment ${item.entityId} not found locally.',
      );
    }

    switch (item.operation) {
      case SyncOperation.create:
        await _pushCreate(item: item, attachment: attachment);
        return true;

      case SyncOperation.delete:
        await _pushDelete(item: item, attachment: attachment);
        return true;

      case SyncOperation.update:
        throw const ChequeAttachmentPushException(
          'Attachment UPDATE push is not supported. '
          'Attachment metadata is immutable after CREATE.',
        );
    }
  }

  Future<void> _pushCreate({
    required SyncQueueItem item,
    required ChequeAttachment attachment,
  }) async {
    final attachmentUuid = _requireUuid(
      attachment.serverUuid,
      'Attachment local id ${attachment.id} has no server UUID.',
    );

    final parent = await _localChequeRepository.findById(attachment.chequeId);

    if (parent == null) {
      throw ChequeAttachmentPushException(
        'Parent cheque ${attachment.chequeId} '
        'not found locally.',
      );
    }

    final parentUuid = _requireUuid(
      parent.serverUuid,
      'Parent cheque ${parent.id} has no server UUID.',
    );

    final localPath = attachment.localPath?.trim();

    if (localPath == null || localPath.isEmpty) {
      throw ChequeAttachmentPushException(
        'Attachment local id ${attachment.id} has no durable local file path.',
      );
    }

    final file = File(localPath);

    if (!await file.exists()) {
      throw ChequeAttachmentPushException(
        'Attachment source file does not exist: $localPath',
      );
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw ChequeAttachmentPushException(
        'Attachment source file is empty: $localPath',
      );
    }

    if (bytes.length != attachment.fileSize) {
      throw ChequeAttachmentPushException(
        'Attachment file size changed before upload. '
        'expected=${attachment.fileSize} actual=${bytes.length}',
      );
    }

    final actualSha256 = sha256.convert(bytes).toString().toLowerCase();
    final expectedSha256 = attachment.sha256.trim().toLowerCase();

    if (actualSha256 != expectedSha256) {
      throw ChequeAttachmentPushException(
        'Attachment SHA256 changed before upload. '
        'expected=$expectedSha256 actual=$actualSha256',
      );
    }

    final metadata = ChequeAttachmentUploadMetadata(
      id: attachmentUuid,
      chequeId: parentUuid,
      kind: attachment.kind,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      originalFileSize: attachment.originalFileSize,
      fileSize: attachment.fileSize,
      sha256: expectedSha256,
    );

    final prepared = await _remoteAttachmentRepository.prepareUpload(metadata);

    if (!_sameUuid(prepared.attachmentId, attachmentUuid)) {
      throw ChequeAttachmentPushException(
        'Attachment prepare identity mismatch. '
        'requested=$attachmentUuid returned=${prepared.attachmentId}',
      );
    }

    await _remoteAttachmentRepository.uploadBytes(
      uploadUrl: prepared.uploadUrl,
      bytes: bytes,
      mimeType: attachment.mimeType,
    );

    final confirmed = await _remoteAttachmentRepository.confirm(metadata);

    if (!_sameUuid(confirmed.id, attachmentUuid)) {
      throw ChequeAttachmentPushException(
        'Attachment confirm identity mismatch. '
        'requested=$attachmentUuid returned=${confirmed.id}',
      );
    }

    if (!_sameUuid(confirmed.chequeId, parentUuid)) {
      throw ChequeAttachmentPushException(
        'Attachment confirm parent mismatch. '
        'expected=$parentUuid returned=${confirmed.chequeId}',
      );
    }

    if (confirmed.storageKey.trim() != prepared.storageKey.trim()) {
      throw ChequeAttachmentPushException(
        'Attachment storage key mismatch between prepare and confirm.',
      );
    }

    await _localAttachmentRepository.applyConfirmedRemoteState(
      id: attachment.id!,
      storageKey: confirmed.storageKey,
      updatedAt: confirmed.updatedAt,
    );

    await _syncQueueRepository.markSynced(item.id!);

    /*
     * requestDelete may happen while CREATE is PROCESSING.
     * In that case LocalChequeAttachmentRepository preserves CREATE
     * and only records delete_requested_at.
     *
     * Once CREATE succeeds, convert that local intent into a follow-up
     * remote DELETE, matching the existing Cheque lifecycle.
     */
    final latest = await _localAttachmentRepository.findById(attachment.id!);

    if (latest?.deleteRequestedAt != null) {
      await _syncQueueRepository.add(
        SyncQueueItem(
          entityType: syncEntityTypeChequeAttachment,
          entityId: attachment.id!,
          operation: SyncOperation.delete,
          status: SyncStatus.pending,
          retryCount: 0,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _pushDelete({
    required SyncQueueItem item,
    required ChequeAttachment attachment,
  }) async {
    final attachmentUuid = _requireUuid(
      attachment.serverUuid,
      'Attachment local id ${attachment.id} has no server UUID for DELETE.',
    );

    try {
      await _remoteAttachmentRepository.delete(attachmentUuid);
    } on ApiHttpException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 410) {
        rethrow;
      }
    }

    await _syncQueueRepository.deleteQueueItem(item.id!);
  }

  String _requireUuid(String? value, String message) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      throw ChequeAttachmentPushException(message);
    }

    return normalized;
  }

  bool _sameUuid(String left, String right) {
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }
}
