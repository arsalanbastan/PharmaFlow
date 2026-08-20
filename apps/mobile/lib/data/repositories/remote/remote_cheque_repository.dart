import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/sync_cursor.dart';
import '../../../core/sync/sync_queue_item.dart';

class RemoteChequeRecord {
  const RemoteChequeRecord({
    required this.id,
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amount,
    required this.chequeDate,
    required this.dueDate,
    required this.status,
    required this.isRegisteredInSayad,
    required this.sayadId,
    required this.imageData,
    required this.description,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String companyId;
  final String bankAccountId;
  final String chequeNumber;
  final num amount;
  final DateTime chequeDate;
  final DateTime? dueDate;
  final String? status;
  final bool? isRegisteredInSayad;
  final String? sayadId;
  final String? imageData;
  final String? description;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  factory RemoteChequeRecord.fromJson(Map<String, dynamic> json) {
    final id = _readRequiredString(json, 'id');
    final companyId = _readRequiredString(json, 'companyId');
    final bankAccountId = _readRequiredString(json, 'bankAccountId');
    final chequeNumber = _readRequiredString(json, 'chequeNumber');
    final chequeDate = _readRequiredDateTime(json, 'chequeDate');
    final createdAt = _readRequiredDateTime(json, 'createdAt');
    final updatedAt = _readRequiredDateTime(json, 'updatedAt');

    return RemoteChequeRecord(
      id: id,
      companyId: companyId,
      bankAccountId: bankAccountId,
      chequeNumber: chequeNumber,
      amount: _readAmount(json['amount']),
      chequeDate: chequeDate,
      dueDate: _readDateTime(json['dueDate']),
      status: _readOptionalString(json['status']),
      isRegisteredInSayad: _readOptionalBool(json['isRegisteredInSayad']),
      sayadId: _readOptionalString(json['sayadId']),
      imageData: _readOptionalString(json['imageData']),
      description: _readOptionalString(json['description']),
      archivedAt: _readDateTime(json['archivedAt']),
      deletedAt: _readDateTime(json['deletedAt']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class RemoteChequeChangesPage {
  const RemoteChequeChangesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RemoteChequeRecord> items;
  final bool hasMore;
  final SyncCursor? nextCursor;
}

class RemoteChequeRepository {
  RemoteChequeRepository(this._apiClient);

  static const int defaultChangesLimit = 200;
  static const int maximumChangesLimit = 500;

  final ApiClient _apiClient;

  Future<List<RemoteChequeRecord>> getAll() async {
    final payload = await _apiClient.get(ApiConstants.chequesEndpoint);

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected cheques endpoint to return a JSON list.',
      );
    }

    final items = <RemoteChequeRecord>[];

    for (final rawItem in payload) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Remote cheques endpoint contained a non-object item.',
        );
      }

      items.add(RemoteChequeRecord.fromJson(rawItem));
    }

    return items;
  }

  Future<RemoteChequeChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = defaultChangesLimit,
  }) async {
    if (limit <= 0 || limit > maximumChangesLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Cheque changes limit must be between 1 and $maximumChangesLimit.',
      );
    }

    if (cursor != null) {
      final normalizedEntityType = cursor.entityType.trim().toUpperCase();

      if (normalizedEntityType != syncEntityTypeCheque) {
        throw ArgumentError(
          'Cheque changes requires a CHEQUE cursor, '
          'but received ${cursor.entityType}.',
        );
      }

      if (cursor.serverUuid.trim().isEmpty) {
        throw ArgumentError(
          'Cheque changes cursor serverUuid cannot be empty.',
        );
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
      '${ApiConstants.chequesEndpoint}/changes',
      queryParameters: queryParameters,
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from remote cheque changes endpoint.',
      );
    }

    final rawItems = payload['items'];

    if (rawItems is! List<dynamic>) {
      throw const ApiDecodingException(
        'Cheque changes response is missing a valid items list.',
      );
    }

    final items = <RemoteChequeRecord>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Cheque changes response contained a non-object item.',
        );
      }

      items.add(RemoteChequeRecord.fromJson(rawItem));
    }

    final rawHasMore = payload['hasMore'];

    if (rawHasMore is! bool) {
      throw const ApiDecodingException(
        'Cheque changes response is missing a valid hasMore flag.',
      );
    }

    final nextCursor = _cursorFromJson(payload['nextCursor']);

    if (rawHasMore && nextCursor == null) {
      throw const ApiDecodingException(
        'Cheque changes response has more data but no next cursor.',
      );
    }

    return RemoteChequeChangesPage(
      items: items,
      hasMore: rawHasMore,
      nextCursor: nextCursor,
    );
  }

  Future<String?> create(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      ApiConstants.chequesEndpoint,
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      final id = response['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }

    return null;
  }

  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    await _apiClient.patch(
      '${ApiConstants.chequesEndpoint}/$serverUuid',
      body: payload,
    );
  }

  Future<void> delete(String serverUuid) async {
    await _apiClient.delete('${ApiConstants.chequesEndpoint}/$serverUuid');
  }

  SyncCursor? _cursorFromJson(Object? raw) {
    if (raw == null) {
      return null;
    }

    if (raw is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Cheque changes nextCursor must be an object or null.',
      );
    }

    final updatedAt = _readDateTime(raw['updatedAt']);
    final id = _readOptionalString(raw['id']);

    if (updatedAt == null || id == null) {
      throw const ApiDecodingException('Cheque changes nextCursor is invalid.');
    }

    return SyncCursor(
      entityType: syncEntityTypeCheque,
      updatedAt: updatedAt,
      serverUuid: id,
    );
  }
}

num _readAmount(Object? raw) {
  if (raw is num) {
    return raw;
  }

  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '');
    final parsed = num.tryParse(normalized);

    if (parsed != null) {
      return parsed;
    }
  }

  throw const ApiDecodingException(
    'Cheque amount is missing or invalid in remote response.',
  );
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = _readOptionalString(json[key]);

  if (value == null) {
    throw ApiDecodingException('Cheque $key is missing in remote response.');
  }

  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = _readDateTime(json[key]);

  if (value == null) {
    throw ApiDecodingException(
      'Cheque $key is missing or invalid in remote response.',
    );
  }

  return value;
}

String? _readOptionalString(Object? raw) {
  if (raw == null) {
    return null;
  }

  final normalized = raw.toString().trim();

  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}

DateTime? _readDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is DateTime) {
    return raw;
  }

  return DateTime.tryParse(raw.toString());
}

bool? _readOptionalBool(Object? raw) {
  if (raw == null) {
    return null;
  }

  if (raw is bool) {
    return raw;
  }

  if (raw is num) {
    return raw != 0;
  }

  final normalized = raw.toString().trim().toLowerCase();

  if (normalized == 'true' || normalized == '1') {
    return true;
  }

  if (normalized == 'false' || normalized == '0') {
    return false;
  }

  throw const ApiDecodingException(
    'Cheque boolean field is invalid in remote response.',
  );
}
