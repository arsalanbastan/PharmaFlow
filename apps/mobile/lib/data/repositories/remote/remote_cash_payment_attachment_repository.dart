import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/sync_cursor.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../mappers/cash_payment_attachment_mapper.dart';
import '../../models/cash_payment_attachment.dart';

class CashPaymentAttachmentUploadMetadata {
  const CashPaymentAttachmentUploadMetadata({
    required this.id,
    required this.cashPaymentId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    this.originalFileSize,
    required this.fileSize,
    required this.sha256,
  });

  final String id;
  final String cashPaymentId;
  final CashPaymentAttachmentKind kind;
  final String fileName;
  final String mimeType;
  final int? originalFileSize;
  final int fileSize;
  final String sha256;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id.trim(),
      'cashPaymentId': cashPaymentId.trim(),
      'kind': CashPaymentAttachmentMapper.kindToWireValue(kind),
      'fileName': fileName.trim(),
      'mimeType': mimeType.trim().toLowerCase(),
      if (originalFileSize != null) 'originalFileSize': originalFileSize,
      'fileSize': fileSize,
      'sha256': sha256.trim().toLowerCase(),
    };
  }
}

class RemoteAttachmentPrepareResult {
  const RemoteAttachmentPrepareResult({
    required this.attachmentId,
    required this.storageKey,
    required this.uploadUrl,
    this.expiresInSeconds,
  });

  final String attachmentId;
  final String storageKey;
  final String uploadUrl;
  final int? expiresInSeconds;

  factory RemoteAttachmentPrepareResult.fromJson(Map<String, dynamic> json) {
    return RemoteAttachmentPrepareResult(
      attachmentId: _readRequiredString(json, 'attachmentId'),
      storageKey: _readRequiredString(json, 'storageKey'),
      uploadUrl: _readRequiredString(json, 'uploadUrl'),
      expiresInSeconds: _readOptionalInt(json['expiresInSeconds']),
    );
  }
}

class RemoteCashPaymentAttachmentRecord {
  const RemoteCashPaymentAttachmentRecord({
    required this.id,
    required this.cashPaymentId,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.originalFileSize,
    required this.fileSize,
    required this.sha256,
    required this.storageKey,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cashPaymentId;
  final CashPaymentAttachmentKind kind;

  final String fileName;
  final String mimeType;

  final int? originalFileSize;
  final int fileSize;

  final String sha256;
  final String storageKey;

  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  factory RemoteCashPaymentAttachmentRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return RemoteCashPaymentAttachmentRecord(
      id: _readRequiredString(json, 'id'),
      cashPaymentId: _readRequiredString(json, 'cashPaymentId'),
      kind: CashPaymentAttachmentMapper.kindFromWireValue(
        _readRequiredString(json, 'kind'),
      ),
      fileName: _readRequiredString(json, 'fileName'),
      mimeType: _readRequiredString(json, 'mimeType').toLowerCase(),
      originalFileSize: _readOptionalInt(json['originalFileSize']),
      fileSize: _readRequiredPositiveInt(json['fileSize'], 'fileSize'),
      sha256: _readRequiredString(json, 'sha256').toLowerCase(),
      storageKey: _readRequiredString(json, 'storageKey'),
      deletedAt: _readDateTime(json['deletedAt']),
      createdAt: _readRequiredDateTime(json, 'createdAt'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }
}

class RemoteCashPaymentAttachmentChangesPage {
  const RemoteCashPaymentAttachmentChangesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RemoteCashPaymentAttachmentRecord> items;
  final bool hasMore;
  final SyncCursor? nextCursor;
}

class RemoteAttachmentDownloadInfo {
  const RemoteAttachmentDownloadInfo({
    required this.attachment,
    required this.downloadUrl,
    this.expiresInSeconds,
  });

  final RemoteCashPaymentAttachmentRecord attachment;
  final String downloadUrl;
  final int? expiresInSeconds;

  factory RemoteAttachmentDownloadInfo.fromJson(Map<String, dynamic> json) {
    final rawAttachment = json['attachment'];

    if (rawAttachment is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment download response is missing attachment metadata.',
      );
    }

    return RemoteAttachmentDownloadInfo(
      attachment: RemoteCashPaymentAttachmentRecord.fromJson(rawAttachment),
      downloadUrl: _readRequiredString(json, 'downloadUrl'),
      expiresInSeconds: _readOptionalInt(json['expiresInSeconds']),
    );
  }
}

class RemoteCashPaymentAttachmentRepository {
  RemoteCashPaymentAttachmentRepository(
    this._apiClient, {
    http.Client? uploadClient,
    Duration uploadTimeout = const Duration(seconds: 90),
  }) : _uploadClient = uploadClient ?? http.Client(),
       _ownsUploadClient = uploadClient == null,
       _uploadTimeout = uploadTimeout;

  static const int defaultChangesLimit = 200;
  static const int maximumChangesLimit = 500;

  final ApiClient _apiClient;
  final http.Client _uploadClient;
  final bool _ownsUploadClient;
  final Duration _uploadTimeout;

  void close() {
    if (_ownsUploadClient) {
      _uploadClient.close();
    }
  }

  Future<RemoteAttachmentPrepareResult> prepareUpload(
    CashPaymentAttachmentUploadMetadata metadata,
  ) async {
    final payload = await _apiClient.post(
      '${ApiConstants.cashPaymentAttachmentsEndpoint}/prepare-upload',
      body: metadata.toJson(),
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment prepare-upload response must be a JSON object.',
      );
    }

    return RemoteAttachmentPrepareResult.fromJson(payload);
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final normalizedUrl = uploadUrl.trim();
    final normalizedMimeType = mimeType.trim().toLowerCase();

    if (normalizedUrl.isEmpty) {
      throw ArgumentError('Presigned upload URL cannot be empty.');
    }

    if (bytes.isEmpty) {
      throw ArgumentError('Attachment upload bytes cannot be empty.');
    }

    try {
      final response = await _uploadClient
          .put(
            Uri.parse(normalizedUrl),
            headers: <String, String>{
              HttpHeaders.contentTypeHeader: normalizedMimeType,
            },
            body: bytes,
          )
          .timeout(_uploadTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiHttpException(
          statusCode: response.statusCode,
          message: 'Object Storage upload failed.',
          body: response.body,
        );
      }
    } on TimeoutException catch (error) {
      throw ApiTimeoutException('Object Storage upload timed out.', error);
    } on SocketException catch (error) {
      throw ApiNetworkException('Object Storage is unreachable.', error);
    } on http.ClientException catch (error) {
      throw ApiNetworkException('Object Storage upload failed.', error);
    }
  }

  Future<RemoteCashPaymentAttachmentRecord> confirm(
    CashPaymentAttachmentUploadMetadata metadata,
  ) async {
    final payload = await _apiClient.post(
      '${ApiConstants.cashPaymentAttachmentsEndpoint}/confirm',
      body: metadata.toJson(),
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment confirm response must be a JSON object.',
      );
    }

    return RemoteCashPaymentAttachmentRecord.fromJson(payload);
  }

  Future<List<RemoteCashPaymentAttachmentRecord>> getAll({
    String? cashPaymentId,
  }) async {
    final normalizedPaymentId = cashPaymentId?.trim();

    final queryParameters = <String, String>{};

    if (normalizedPaymentId != null && normalizedPaymentId.isNotEmpty) {
      queryParameters['cashPaymentId'] = normalizedPaymentId;
    }

    final payload = await _apiClient.get(
      ApiConstants.cashPaymentAttachmentsEndpoint,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Attachment list response must be a JSON list.',
      );
    }

    return payload
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const ApiDecodingException(
              'Attachment list contains a non-object item.',
            );
          }

          return RemoteCashPaymentAttachmentRecord.fromJson(raw);
        })
        .toList(growable: false);
  }

  Future<RemoteCashPaymentAttachmentChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = defaultChangesLimit,
  }) async {
    if (limit <= 0 || limit > maximumChangesLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Attachment changes limit must be between '
            '1 and $maximumChangesLimit.',
      );
    }

    if (cursor != null) {
      final entityType = cursor.entityType.trim().toUpperCase();

      if (entityType != syncEntityTypeCashPaymentAttachment) {
        throw ArgumentError(
          'Attachment changes requires a '
          'CASH_PAYMENT_ATTACHMENT cursor.',
        );
      }

      if (cursor.serverUuid.trim().isEmpty) {
        throw ArgumentError('Attachment changes cursor UUID cannot be empty.');
      }
    }

    final queryParameters = <String, String>{'limit': limit.toString()};

    if (cursor != null) {
      queryParameters['updatedAfter'] = cursor.updatedAt
          .toUtc()
          .toIso8601String();

      queryParameters['afterId'] = cursor.serverUuid.trim();
    }

    final payload = await _apiClient.get(
      '${ApiConstants.cashPaymentAttachmentsEndpoint}/changes',
      queryParameters: queryParameters,
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment changes response must be a JSON object.',
      );
    }

    final rawItems = payload['items'];

    if (rawItems is! List<dynamic>) {
      throw const ApiDecodingException(
        'Attachment changes response has no valid items list.',
      );
    }

    final items = <RemoteCashPaymentAttachmentRecord>[];

    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Attachment changes contains a non-object item.',
        );
      }

      items.add(RemoteCashPaymentAttachmentRecord.fromJson(raw));
    }

    final rawHasMore = payload['hasMore'];

    if (rawHasMore is! bool) {
      throw const ApiDecodingException(
        'Attachment changes response has no valid hasMore flag.',
      );
    }

    final nextCursor = _cursorFromJson(payload['nextCursor']);

    if (rawHasMore && nextCursor == null) {
      throw const ApiDecodingException(
        'Attachment changes hasMore=true but nextCursor is null.',
      );
    }

    return RemoteCashPaymentAttachmentChangesPage(
      items: items,
      hasMore: rawHasMore,
      nextCursor: nextCursor,
    );
  }

  Future<RemoteAttachmentDownloadInfo> getDownloadInfo(
    String attachmentUuid,
  ) async {
    final normalized = attachmentUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Attachment UUID cannot be empty.');
    }

    final payload = await _apiClient.get(
      '${ApiConstants.cashPaymentAttachmentsEndpoint}/'
      '$normalized/download-url',
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment download response must be a JSON object.',
      );
    }

    return RemoteAttachmentDownloadInfo.fromJson(payload);
  }

  Future<void> delete(String attachmentUuid) async {
    final normalized = attachmentUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Attachment UUID cannot be empty.');
    }

    await _apiClient.delete(
      '${ApiConstants.cashPaymentAttachmentsEndpoint}/$normalized',
    );
  }

  SyncCursor? _cursorFromJson(Object? raw) {
    if (raw == null) {
      return null;
    }

    if (raw is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Attachment nextCursor must be an object or null.',
      );
    }

    final updatedAt = _readDateTime(raw['updatedAt']);

    final id = _readOptionalString(raw['id']);

    if (updatedAt == null || id == null) {
      throw const ApiDecodingException('Attachment nextCursor is invalid.');
    }

    return SyncCursor(
      entityType: syncEntityTypeCashPaymentAttachment,
      updatedAt: updatedAt.toUtc(),
      serverUuid: id,
    );
  }
}

int _readRequiredPositiveInt(Object? raw, String field) {
  final value = _readOptionalInt(raw);

  if (value == null || value <= 0) {
    throw ApiDecodingException(
      'Attachment field "$field" '
      'must be a positive integer.',
    );
  }

  return value;
}

int? _readOptionalInt(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is int) {
    return raw;
  }

  if (raw is num) {
    final integerValue = raw.toInt();

    if (raw == integerValue) {
      return integerValue;
    }

    return null;
  }

  if (raw is String) {
    return int.tryParse(raw.trim());
  }

  return null;
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = _readOptionalString(json[key]);

  if (value == null) {
    throw ApiDecodingException(
      'Attachment field "$key" '
      'is missing or invalid.',
    );
  }

  return value;
}

String? _readOptionalString(Object? raw) {
  if (raw == null) {
    return null;
  }

  final value = raw.toString().trim();

  return value.isEmpty ? null : value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = _readDateTime(json[key]);

  if (value == null) {
    throw ApiDecodingException(
      'Attachment field "$key" '
      'is missing or invalid.',
    );
  }

  return value;
}

DateTime? _readDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is DateTime) {
    return raw.toUtc();
  }

  if (raw is String) {
    return DateTime.tryParse(raw.trim())?.toUtc();
  }

  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
  }

  return null;
}
