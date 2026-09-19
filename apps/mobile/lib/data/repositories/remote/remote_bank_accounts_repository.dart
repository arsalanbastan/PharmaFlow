import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/sync_cursor.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../models/bank_account.dart';

class RemoteBankAccountChange {
  const RemoteBankAccountChange({
    required this.account,
    required this.deletedAt,
  });

  final BankAccount account;
  final DateTime? deletedAt;

  String get serverUuid {
    final value = account.serverUuid?.trim();

    if (value == null || value.isEmpty) {
      throw StateError('Remote bank account change has no server UUID.');
    }

    return value;
  }

  DateTime get updatedAt => account.updatedAt;

  bool get isDeleted => deletedAt != null;
}

class RemoteBankAccountChangesPage {
  const RemoteBankAccountChangesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RemoteBankAccountChange> items;
  final bool hasMore;
  final SyncCursor? nextCursor;
}

class RemoteBankAccountsRepository {
  RemoteBankAccountsRepository(this._apiClient);

  static const int defaultChangesLimit = 200;
  static const int maximumChangesLimit = 500;

  final ApiClient _apiClient;

  Future<List<BankAccount>> getAll({bool includeArchived = false}) async {
    final payload = await _apiClient.get(ApiConstants.bankAccountsEndpoint);

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON list from remote bank accounts endpoint.',
      );
    }

    final accounts = <BankAccount>[];

    for (final rawItem in payload) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Remote bank accounts endpoint contained a non-object item.',
        );
      }

      accounts.add(_bankAccountFromJson(rawItem));
    }

    if (includeArchived) {
      return accounts;
    }

    return accounts.where((account) => account.archivedAt == null).toList();
  }

  Future<RemoteBankAccountChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = defaultChangesLimit,
  }) async {
    if (limit <= 0 || limit > maximumChangesLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Bank account changes limit must be between 1 and $maximumChangesLimit.',
      );
    }

    if (cursor != null) {
      final normalizedEntityType = cursor.entityType.trim().toUpperCase();

      if (normalizedEntityType != syncEntityTypeBankAccount) {
        throw ArgumentError(
          'Bank account changes requires a BANK_ACCOUNT cursor, '
          'but received ${cursor.entityType}.',
        );
      }

      if (cursor.serverUuid.trim().isEmpty) {
        throw ArgumentError(
          'Bank account changes cursor serverUuid cannot be empty.',
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
      '${ApiConstants.bankAccountsEndpoint}/changes',
      queryParameters: queryParameters,
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from remote bank account changes endpoint.',
      );
    }

    final rawItems = payload['items'];

    if (rawItems is! List<dynamic>) {
      throw const ApiDecodingException(
        'Bank account changes response is missing a valid items list.',
      );
    }

    final items = <RemoteBankAccountChange>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Bank account changes response contained a non-object item.',
        );
      }

      items.add(
        RemoteBankAccountChange(
          account: _bankAccountFromJson(rawItem),
          deletedAt: _readDateTime(
            rawItem,
            'deletedAt',
            fallbackKey: 'deleted_at',
          ),
        ),
      );
    }

    final rawHasMore = payload['hasMore'];

    if (rawHasMore is! bool) {
      throw const ApiDecodingException(
        'Bank account changes response is missing a valid hasMore flag.',
      );
    }

    final nextCursor = _cursorFromJson(payload['nextCursor']);

    if (rawHasMore && nextCursor == null) {
      throw const ApiDecodingException(
        'Bank account changes response has more data but no next cursor.',
      );
    }

    return RemoteBankAccountChangesPage(
      items: items,
      hasMore: rawHasMore,
      nextCursor: nextCursor,
    );
  }

  Future<String> createWithClientUuid(Map<String, dynamic> payload) async {
    final requestedId = _readString(payload, 'id');

    if (requestedId == null) {
      throw ArgumentError(
        'Bank account CREATE payload must contain a non-empty client UUID in id.',
      );
    }

    final response = await _apiClient.post(
      ApiConstants.bankAccountsEndpoint,
      body: payload,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from BankAccount CREATE endpoint.',
      );
    }

    final returnedId =
        _readString(response, 'id') ??
        _readString(response, 'serverUuid', fallbackKey: 'server_uuid');

    if (returnedId == null) {
      throw const ApiDecodingException(
        'BankAccount CREATE response did not contain a server UUID.',
      );
    }

    return returnedId;
  }

  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    await _apiClient.patch(
      '${ApiConstants.bankAccountsEndpoint}/$serverUuid',
      body: payload,
    );
  }

  BankAccount _bankAccountFromJson(Map<String, dynamic> json) {
    final serverUuid =
        _readString(json, 'id') ??
        _readString(json, 'serverUuid', fallbackKey: 'server_uuid');

    if (serverUuid == null) {
      throw const ApiDecodingException(
        'Bank account server UUID is missing in remote response.',
      );
    }

    final bankName = _readString(json, 'bankName', fallbackKey: 'bank_name');

    if (bankName == null) {
      throw const ApiDecodingException(
        'Bank account bankName is missing in remote response.',
      );
    }

    final createdAt = _readDateTime(
      json,
      'createdAt',
      fallbackKey: 'created_at',
    );

    if (createdAt == null) {
      throw const ApiDecodingException(
        'Bank account createdAt is missing or invalid in remote response.',
      );
    }

    final updatedAt = _readDateTime(
      json,
      'updatedAt',
      fallbackKey: 'updated_at',
    );

    if (updatedAt == null) {
      throw const ApiDecodingException(
        'Bank account updatedAt is missing or invalid in remote response.',
      );
    }

    return BankAccount(
      id: null,
      serverUuid: serverUuid,
      bankName: bankName,
      accountTitle:
          _readString(json, 'accountTitle', fallbackKey: 'account_title') ?? '',
      accountHolder:
          _readString(json, 'accountHolder', fallbackKey: 'account_holder') ??
          '',
      accountNumber:
          _readString(json, 'accountNumber', fallbackKey: 'account_number') ??
          '',
      cardNumber:
          _readString(json, 'cardNumber', fallbackKey: 'card_number') ?? '',
      iban:
          _readString(json, 'shebaNumber', fallbackKey: 'sheba_number') ??
          _readString(json, 'iban') ??
          '',
      note: _readString(json, 'notes') ?? _readString(json, 'note'),
      archivedAt: _readDateTime(json, 'archivedAt', fallbackKey: 'archived_at'),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SyncCursor? _cursorFromJson(Object? raw) {
    if (raw == null) {
      return null;
    }

    if (raw is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Bank account changes nextCursor must be an object or null.',
      );
    }

    final updatedAt = _readDateTime(
      raw,
      'updatedAt',
      fallbackKey: 'updated_at',
    );

    final serverUuid =
        _readString(raw, 'id') ??
        _readString(raw, 'serverUuid', fallbackKey: 'server_uuid');

    if (updatedAt == null || serverUuid == null) {
      throw const ApiDecodingException(
        'Bank account changes nextCursor is invalid.',
      );
    }

    return SyncCursor(
      entityType: syncEntityTypeBankAccount,
      updatedAt: updatedAt,
      serverUuid: serverUuid,
    );
  }

  String? _readString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final primary = json[key];

    if (primary != null) {
      final normalized = primary.toString().trim();

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    if (fallbackKey != null) {
      final fallback = json[fallbackKey];

      if (fallback != null) {
        final normalized = fallback.toString().trim();

        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }

    return null;
  }

  DateTime? _readDateTime(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final raw = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

    if (raw == null) {
      return null;
    }

    if (raw is DateTime) {
      return raw;
    }

    return DateTime.tryParse(raw.toString());
  }
}
