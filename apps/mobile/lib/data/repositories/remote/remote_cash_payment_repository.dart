import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/sync_cursor.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../models/cash_payment.dart';

class RemoteCashPaymentRecord {
  const RemoteCashPaymentRecord({
    required this.id,
    required this.amountRial,
    required this.paymentDate,
    required this.companyId,
    required this.bankAccountId,
    required this.paymentMethod,
    required this.trackingNumber,
    required this.description,
    required this.notes,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int amountRial;
  final DateTime paymentDate;
  final String companyId;
  final String bankAccountId;
  final CashPaymentMethod paymentMethod;
  final String? trackingNumber;
  final String? description;
  final String? notes;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDeleted => deletedAt != null;

  factory RemoteCashPaymentRecord.fromJson(Map<String, dynamic> json) {
    return RemoteCashPaymentRecord(
      id: _readRequiredString(json, 'id'),
      amountRial: _readRequiredAmountRial(json['amount']),
      paymentDate: _readRequiredDateTime(json, 'paymentDate'),
      companyId: _readRequiredString(json, 'companyId'),
      bankAccountId: _readRequiredString(json, 'bankAccountId'),
      paymentMethod: _readRequiredPaymentMethod(json['paymentMethod']),
      trackingNumber: _readOptionalString(json['trackingNumber']),
      description: _readOptionalString(json['description']),
      notes: _readOptionalString(json['notes']),
      archivedAt: _readDateTime(json['archivedAt']),
      deletedAt: _readDateTime(json['deletedAt']),
      createdAt: _readRequiredDateTime(json, 'createdAt'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }
}

class RemoteCashPaymentChangesPage {
  const RemoteCashPaymentChangesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RemoteCashPaymentRecord> items;
  final bool hasMore;
  final SyncCursor? nextCursor;
}

class RemoteCashPaymentRepository {
  RemoteCashPaymentRepository(this._apiClient);

  static const int defaultChangesLimit = 200;
  static const int maximumChangesLimit = 500;

  final ApiClient _apiClient;

  Future<List<RemoteCashPaymentRecord>> getAll() async {
    final payload = await _apiClient.get(ApiConstants.cashPaymentsEndpoint);

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected cash payments endpoint to return a JSON list.',
      );
    }

    final items = <RemoteCashPaymentRecord>[];

    for (final rawItem in payload) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Remote cash payments endpoint contained a non-object item.',
        );
      }

      items.add(RemoteCashPaymentRecord.fromJson(rawItem));
    }

    return items;
  }

  Future<RemoteCashPaymentChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = defaultChangesLimit,
  }) async {
    if (limit <= 0 || limit > maximumChangesLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Cash payment changes limit must be between '
            '1 and $maximumChangesLimit.',
      );
    }

    if (cursor != null) {
      final normalizedEntityType = cursor.entityType.trim().toUpperCase();

      if (normalizedEntityType != syncEntityTypeCashPayment) {
        throw ArgumentError(
          'Cash payment changes requires a CASH_PAYMENT cursor, '
          'but received ${cursor.entityType}.',
        );
      }

      if (cursor.serverUuid.trim().isEmpty) {
        throw ArgumentError(
          'Cash payment changes cursor serverUuid cannot be empty.',
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
      '${ApiConstants.cashPaymentsEndpoint}/changes',
      queryParameters: queryParameters,
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from remote cash payment changes endpoint.',
      );
    }

    final rawItems = payload['items'];

    if (rawItems is! List<dynamic>) {
      throw const ApiDecodingException(
        'Cash payment changes response is missing a valid items list.',
      );
    }

    final items = <RemoteCashPaymentRecord>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Cash payment changes response contained a non-object item.',
        );
      }

      items.add(RemoteCashPaymentRecord.fromJson(rawItem));
    }

    final rawHasMore = payload['hasMore'];

    if (rawHasMore is! bool) {
      throw const ApiDecodingException(
        'Cash payment changes response is missing a valid hasMore flag.',
      );
    }

    final nextCursor = _cursorFromJson(payload['nextCursor']);

    if (rawHasMore && nextCursor == null) {
      throw const ApiDecodingException(
        'Cash payment changes response has more data but no next cursor.',
      );
    }

    return RemoteCashPaymentChangesPage(
      items: items,
      hasMore: rawHasMore,
      nextCursor: nextCursor,
    );
  }

  Future<String> create(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      ApiConstants.cashPaymentsEndpoint,
      body: payload,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Cash payment CREATE response must be a JSON object.',
      );
    }

    return _readRequiredString(response, 'id');
  }

  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Cash payment server UUID cannot be empty.');
    }

    await _apiClient.patch(
      '${ApiConstants.cashPaymentsEndpoint}/$normalized',
      body: payload,
    );
  }

  Future<void> delete(String serverUuid) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Cash payment server UUID cannot be empty.');
    }

    await _apiClient.delete('${ApiConstants.cashPaymentsEndpoint}/$normalized');
  }

  SyncCursor? _cursorFromJson(Object? raw) {
    if (raw == null) {
      return null;
    }

    if (raw is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Cash payment changes nextCursor must be an object or null.',
      );
    }

    final updatedAt = _readDateTime(raw['updatedAt']);

    final id = _readOptionalString(raw['id']);

    if (updatedAt == null || id == null) {
      throw const ApiDecodingException(
        'Cash payment changes nextCursor is invalid.',
      );
    }

    return SyncCursor(
      entityType: syncEntityTypeCashPayment,
      updatedAt: updatedAt.toUtc(),
      serverUuid: id,
    );
  }
}

int _readRequiredAmountRial(Object? raw) {
  if (raw is int) {
    if (raw <= 0) {
      throw const ApiDecodingException('Cash payment amount must be positive.');
    }

    return raw;
  }

  if (raw is num) {
    final integerValue = raw.toInt();

    if (raw != integerValue || integerValue <= 0) {
      throw const ApiDecodingException(
        'Cash payment amount must be a positive integer Rial value.',
      );
    }

    return integerValue;
  }

  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '');

    final match = RegExp(r'^([0-9]+)(?:\.0+)?$').firstMatch(normalized);

    if (match != null) {
      final value = int.tryParse(match.group(1)!);

      if (value != null && value > 0) {
        return value;
      }
    }
  }

  throw const ApiDecodingException(
    'Cash payment amount is missing or invalid in remote response.',
  );
}

CashPaymentMethod _readRequiredPaymentMethod(Object? raw) {
  final value = _readOptionalString(raw)?.toUpperCase();

  switch (value) {
    case 'BANK_DEPOSIT':
      return CashPaymentMethod.bankDeposit;

    case 'POS_PAYMENT':
      return CashPaymentMethod.posPayment;
  }

  throw ApiDecodingException(
    'Cash payment method "$value" is invalid in remote response.',
  );
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = _readOptionalString(json[key]);

  if (value == null) {
    throw ApiDecodingException(
      'Cash payment $key is missing in remote response.',
    );
  }

  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = _readDateTime(json[key]);

  if (value == null) {
    throw ApiDecodingException(
      'Cash payment $key is missing or invalid in remote response.',
    );
  }

  return value.toUtc();
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
    return raw.toUtc();
  }

  return DateTime.tryParse(raw.toString())?.toUtc();
}
