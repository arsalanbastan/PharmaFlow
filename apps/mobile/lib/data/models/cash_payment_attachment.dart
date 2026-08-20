enum CashPaymentAttachmentKind { receipt, statement }

class CashPaymentAttachment {
  const CashPaymentAttachment({
    this.id,
    this.serverUuid,
    required this.cashPaymentId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    this.originalFileSize,
    required this.fileSize,
    required this.sha256,
    this.localPath,
    this.storageKey,
    this.deleteRequestedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;

  /// Client/server UUID identity for the attachment.
  ///
  /// A local CREATE receives its UUID before sync so the remote
  /// prepare/confirm flow can remain idempotent.
  final String? serverUuid;

  /// Local SQLite id of the parent CashPayment.
  final int cashPaymentId;

  final CashPaymentAttachmentKind kind;

  final String fileName;
  final String mimeType;

  final int? originalFileSize;
  final int fileSize;

  final String sha256;

  /// Durable local cached/source file.
  ///
  /// This is intentionally local-only and is never sent as server metadata.
  final String? localPath;

  /// Object Storage key returned/confirmed by the backend.
  final String? storageKey;

  /// Local deletion intent waiting for synchronization.
  final DateTime? deleteRequestedAt;

  /// Server tombstone state after pull/merge.
  final DateTime? deletedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  CashPaymentAttachment copyWith({
    Object? id = _unset,
    Object? serverUuid = _unset,
    int? cashPaymentId,
    CashPaymentAttachmentKind? kind,
    String? fileName,
    String? mimeType,
    Object? originalFileSize = _unset,
    int? fileSize,
    String? sha256,
    Object? localPath = _unset,
    Object? storageKey = _unset,
    Object? deleteRequestedAt = _unset,
    Object? deletedAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashPaymentAttachment(
      id: identical(id, _unset) ? this.id : id as int?,
      serverUuid: identical(serverUuid, _unset)
          ? this.serverUuid
          : serverUuid as String?,
      cashPaymentId: cashPaymentId ?? this.cashPaymentId,
      kind: kind ?? this.kind,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      originalFileSize: identical(originalFileSize, _unset)
          ? this.originalFileSize
          : originalFileSize as int?,
      fileSize: fileSize ?? this.fileSize,
      sha256: sha256 ?? this.sha256,
      localPath: identical(localPath, _unset)
          ? this.localPath
          : localPath as String?,
      storageKey: identical(storageKey, _unset)
          ? this.storageKey
          : storageKey as String?,
      deleteRequestedAt: identical(deleteRequestedAt, _unset)
          ? this.deleteRequestedAt
          : deleteRequestedAt as DateTime?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unset = Object();
