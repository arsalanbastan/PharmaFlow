import 'dart:io';

import 'package:crypto/crypto.dart';

import '../network/api_client.dart';
import '../../data/models/cash_payment_attachment.dart';
import '../../data/repositories/local/local_cash_payment_attachment_repository.dart';
import '../../data/repositories/local/local_cash_payment_repository.dart';
import '../../data/repositories/local/sync_queue_repository.dart';
import '../../data/repositories/remote/remote_cash_payment_attachment_repository.dart';
import 'sync_operation.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class CashPaymentAttachmentPushException implements Exception {
  const CashPaymentAttachmentPushException(this.message);

  final String message;

  @override
  String toString() => 'CashPaymentAttachmentPushException: $message';
}

class CashPaymentAttachmentPushService {
  const CashPaymentAttachmentPushService({
    required LocalCashPaymentAttachmentRepository localAttachmentRepository,
    required LocalCashPaymentRepository localCashPaymentRepository,
    required RemoteCashPaymentAttachmentRepository remoteAttachmentRepository,
    required SyncQueueRepository syncQueueRepository,
  }) : _localAttachmentRepository = localAttachmentRepository,
       _localCashPaymentRepository = localCashPaymentRepository,
       _remoteAttachmentRepository = remoteAttachmentRepository,
       _syncQueueRepository = syncQueueRepository;

  final LocalCashPaymentAttachmentRepository _localAttachmentRepository;
  final LocalCashPaymentRepository _localCashPaymentRepository;
  final RemoteCashPaymentAttachmentRepository _remoteAttachmentRepository;
  final SyncQueueRepository _syncQueueRepository;

  Future<bool> push(SyncQueueItem item) async {
    final entityType = item.entityType.trim().toUpperCase();

    if (entityType != syncEntityTypeCashPaymentAttachment) {
      throw CashPaymentAttachmentPushException(
        'Expected CASH_PAYMENT_ATTACHMENT queue item, '
        'received ${item.entityType}.',
      );
    }

    final queueId = item.id;

    if (queueId == null) {
      throw const CashPaymentAttachmentPushException(
        'Attachment queue item has no id.',
      );
    }

    final attachment = await _localAttachmentRepository.findById(item.entityId);

    if (attachment == null || attachment.id == null) {
      throw CashPaymentAttachmentPushException(
        'Cash payment attachment ${item.entityId} not found locally.',
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
        throw const CashPaymentAttachmentPushException(
          'Attachment UPDATE push is not supported. '
          'Attachment metadata is immutable after CREATE.',
        );
    }
  }

  Future<void> _pushCreate({
    required SyncQueueItem item,
    required CashPaymentAttachment attachment,
  }) async {
    final attachmentUuid = _requireUuid(
      attachment.serverUuid,
      'Attachment local id ${attachment.id} has no server UUID.',
    );

    final parent = await _localCashPaymentRepository.findById(
      attachment.cashPaymentId,
    );

    if (parent == null || parent.id == null) {
      throw CashPaymentAttachmentPushException(
        'Parent cash payment ${attachment.cashPaymentId} '
        'not found locally.',
      );
    }

    final parentUuid = _requireUuid(
      parent.serverUuid,
      'Parent cash payment ${parent.id} has no server UUID.',
    );

    final localPath = attachment.localPath?.trim();

    if (localPath == null || localPath.isEmpty) {
      throw CashPaymentAttachmentPushException(
        'Attachment local id ${attachment.id} has no durable local file path.',
      );
    }

    final file = File(localPath);

    if (!await file.exists()) {
      throw CashPaymentAttachmentPushException(
        'Attachment source file does not exist: $localPath',
      );
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw CashPaymentAttachmentPushException(
        'Attachment source file is empty: $localPath',
      );
    }

    if (bytes.length != attachment.fileSize) {
      throw CashPaymentAttachmentPushException(
        'Attachment file size changed before upload. '
        'expected=${attachment.fileSize} actual=${bytes.length}',
      );
    }

    final actualSha256 = sha256.convert(bytes).toString().toLowerCase();
    final expectedSha256 = attachment.sha256.trim().toLowerCase();

    if (actualSha256 != expectedSha256) {
      throw CashPaymentAttachmentPushException(
        'Attachment SHA256 changed before upload. '
        'expected=$expectedSha256 actual=$actualSha256',
      );
    }

    final metadata = CashPaymentAttachmentUploadMetadata(
      id: attachmentUuid,
      cashPaymentId: parentUuid,
      kind: attachment.kind,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      originalFileSize: attachment.originalFileSize,
      fileSize: attachment.fileSize,
      sha256: expectedSha256,
    );

    final prepared = await _remoteAttachmentRepository.prepareUpload(metadata);

    if (!_sameUuid(prepared.attachmentId, attachmentUuid)) {
      throw CashPaymentAttachmentPushException(
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
      throw CashPaymentAttachmentPushException(
        'Attachment confirm identity mismatch. '
        'requested=$attachmentUuid returned=${confirmed.id}',
      );
    }

    if (!_sameUuid(confirmed.cashPaymentId, parentUuid)) {
      throw CashPaymentAttachmentPushException(
        'Attachment confirm parent mismatch. '
        'expected=$parentUuid returned=${confirmed.cashPaymentId}',
      );
    }

    if (confirmed.storageKey.trim() != prepared.storageKey.trim()) {
      throw CashPaymentAttachmentPushException(
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
     * In that case LocalCashPaymentAttachmentRepository preserves CREATE
     * and only records delete_requested_at.
     *
     * Once CREATE succeeds, convert that local intent into a follow-up
     * remote DELETE, matching the existing CashPayment lifecycle.
     */
    final latest = await _localAttachmentRepository.findById(attachment.id!);

    if (latest?.deleteRequestedAt != null) {
      await _syncQueueRepository.add(
        SyncQueueItem(
          entityType: syncEntityTypeCashPaymentAttachment,
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
    required CashPaymentAttachment attachment,
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
      throw CashPaymentAttachmentPushException(message);
    }

    return normalized;
  }

  bool _sameUuid(String left, String right) {
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }
}
