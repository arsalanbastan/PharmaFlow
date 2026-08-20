import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/sync/sync_cursor.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/utils/company_name_normalizer.dart';
import '../../models/company.dart';
import '../interfaces/company_repository.dart';

class RemoteCompanyChange {
  const RemoteCompanyChange({required this.company, required this.deletedAt});

  final Company company;
  final DateTime? deletedAt;

  String get serverUuid {
    final value = company.serverUuid?.trim();

    if (value == null || value.isEmpty) {
      throw StateError('Remote company change has no server UUID.');
    }

    return value;
  }

  DateTime get updatedAt => company.updatedAt;

  bool get isDeleted => deletedAt != null;
}

class RemoteCompanyChangesPage {
  const RemoteCompanyChangesPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<RemoteCompanyChange> items;
  final bool hasMore;
  final SyncCursor? nextCursor;
}

class RemoteCompanyRepository implements CompanyRepository {
  RemoteCompanyRepository(this._apiClient);

  static const int defaultChangesLimit = 200;
  static const int maximumChangesLimit = 500;

  final ApiClient _apiClient;

  @override
  Future<List<Company>> getAll({bool includeArchived = false}) async {
    final payload = await _apiClient.get(ApiConstants.companiesEndpoint);

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON list from remote companies endpoint.',
      );
    }

    final companies = <Company>[];

    for (final rawItem in payload) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Remote companies endpoint contained a non-object item.',
        );
      }

      companies.add(_companyFromJson(rawItem));
    }

    if (includeArchived) {
      return companies;
    }

    return companies.where((company) => company.archivedAt == null).toList();
  }

  Future<RemoteCompanyChangesPage> getChanges({
    SyncCursor? cursor,
    int limit = defaultChangesLimit,
  }) async {
    if (limit <= 0 || limit > maximumChangesLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Company changes limit must be between 1 and $maximumChangesLimit.',
      );
    }

    if (cursor != null) {
      final normalizedEntityType = cursor.entityType.trim().toUpperCase();

      if (normalizedEntityType != syncEntityTypeCompany) {
        throw ArgumentError(
          'Company changes requires a COMPANY cursor, '
          'but received ${cursor.entityType}.',
        );
      }

      if (cursor.serverUuid.trim().isEmpty) {
        throw ArgumentError(
          'Company changes cursor serverUuid cannot be empty.',
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
      '${ApiConstants.companiesEndpoint}/changes',
      queryParameters: queryParameters,
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from remote company changes endpoint.',
      );
    }

    final rawItems = payload['items'];

    if (rawItems is! List<dynamic>) {
      throw const ApiDecodingException(
        'Company changes response is missing a valid items list.',
      );
    }

    final items = <RemoteCompanyChange>[];

    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Company changes response contained a non-object item.',
        );
      }

      items.add(_companyChangeFromJson(rawItem));
    }

    final rawHasMore = payload['hasMore'];

    if (rawHasMore is! bool) {
      throw const ApiDecodingException(
        'Company changes response is missing a valid hasMore flag.',
      );
    }

    final nextCursor = _cursorFromJson(payload['nextCursor']);

    if (rawHasMore && nextCursor == null) {
      throw const ApiDecodingException(
        'Company changes response has more data but no next cursor.',
      );
    }

    return RemoteCompanyChangesPage(
      items: items,
      hasMore: rawHasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<List<Company>> search(
    String query, {
    bool includeArchived = false,
  }) async {
    final trimmedQuery = query.trim().toLowerCase();

    final companies = await getAll(includeArchived: includeArchived);

    if (trimmedQuery.isEmpty) {
      return companies;
    }

    return companies.where((company) {
      final matchesName = company.name.toLowerCase().contains(trimmedQuery);
      final matchesNationalId =
          company.nationalId?.toLowerCase().contains(trimmedQuery) ?? false;
      final matchesEconomicCode =
          company.economicCode?.toLowerCase().contains(trimmedQuery) ?? false;

      final matchesBankName =
          company.bankName?.toLowerCase().contains(trimmedQuery) ?? false;

      final matchesAccountNumber =
          company.accountNumber?.toLowerCase().contains(trimmedQuery) ?? false;

      final matchesCardNumber =
          company.cardNumber?.toLowerCase().contains(trimmedQuery) ?? false;

      final matchesShebaNumber =
          company.shebaNumber?.toLowerCase().contains(trimmedQuery) ?? false;

      return matchesName ||
          matchesNationalId ||
          matchesEconomicCode ||
          matchesBankName ||
          matchesAccountNumber ||
          matchesCardNumber ||
          matchesShebaNumber;
    }).toList();
  }

  @override
  Future<List<Company>> findSimilar(String name) async {
    final normalizedInput = CompanyNameNormalizer.normalize(name);

    if (normalizedInput.isEmpty) {
      return [];
    }

    final companies = await getAll();

    return companies.where((company) {
      final normalizedCompany = CompanyNameNormalizer.normalize(company.name);
      return normalizedCompany == normalizedInput;
    }).toList();
  }

  @override
  Future<int> insert(Company company) {
    throw UnsupportedError(
      'Use createWithClientUuid() for offline-first Company CREATE.',
    );
  }

  Future<String> createWithClientUuid(Map<String, dynamic> payload) async {
    final requestedId = _readString(payload, 'id');

    if (requestedId == null) {
      throw ArgumentError(
        'Company CREATE payload must contain a non-empty client UUID in id.',
      );
    }

    final response = await _apiClient.post(
      ApiConstants.companiesEndpoint,
      body: payload,
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from Company CREATE endpoint.',
      );
    }

    final returnedId =
        _readString(response, 'id') ??
        _readString(response, 'serverUuid', fallbackKey: 'server_uuid');

    if (returnedId == null) {
      throw const ApiDecodingException(
        'Company CREATE response did not contain a server UUID.',
      );
    }

    return returnedId;
  }

  @override
  Future<void> update(Company company) {
    throw UnsupportedError('Remote update is not implemented yet.');
  }

  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    await _apiClient.patch(
      '${ApiConstants.companiesEndpoint}/$serverUuid',
      body: payload,
    );
  }

  @override
  Future<void> archive(int id) {
    throw UnsupportedError('Remote archive is not implemented yet.');
  }

  @override
  Future<void> restore(int id) {
    throw UnsupportedError('Remote restore is not implemented yet.');
  }

  Future<int> verifyCompaniesEndpoint() async {
    final companies = await getAll();
    return companies.length;
  }

  RemoteCompanyChange _companyChangeFromJson(Map<String, dynamic> json) {
    return RemoteCompanyChange(
      company: _companyFromJson(json),
      deletedAt: _readDateTime(json, 'deletedAt', fallbackKey: 'deleted_at'),
    );
  }

  Company _companyFromJson(Map<String, dynamic> json) {
    final name = _readString(json, 'name');

    if (name == null) {
      throw const ApiDecodingException(
        'Company name is missing in remote response.',
      );
    }

    final serverUuid =
        _readString(json, 'id') ??
        _readString(json, 'serverUuid', fallbackKey: 'server_uuid');

    if (serverUuid == null) {
      throw const ApiDecodingException(
        'Company server UUID is missing in remote response.',
      );
    }

    final createdAt = _readDateTime(
      json,
      'createdAt',
      fallbackKey: 'created_at',
    );

    if (createdAt == null) {
      throw const ApiDecodingException(
        'Company createdAt is missing or invalid in remote response.',
      );
    }

    final updatedAt = _readDateTime(
      json,
      'updatedAt',
      fallbackKey: 'updated_at',
    );

    if (updatedAt == null) {
      throw const ApiDecodingException(
        'Company updatedAt is missing or invalid in remote response.',
      );
    }

    return Company(
      id: null,
      serverUuid: serverUuid,
      name: name,
      nationalId: _readString(json, 'nationalId', fallbackKey: 'national_id'),
      economicCode: _readString(
        json,
        'economicCode',
        fallbackKey: 'economic_code',
      ),
      bankName: _readString(json, 'bankName', fallbackKey: 'bank_name'),
      accountNumber: _readString(
        json,
        'accountNumber',
        fallbackKey: 'account_number',
      ),
      cardNumber: _readString(json, 'cardNumber', fallbackKey: 'card_number'),
      shebaNumber: _readString(
        json,
        'shebaNumber',
        fallbackKey: 'sheba_number',
      ),
      notes: _readString(json, 'notes'),
      visitorName: _readString(
        json,
        'visitorName',
        fallbackKey: 'visitor_name',
      ),
      visitorPhone: _readString(
        json,
        'visitorPhone',
        fallbackKey: 'visitor_phone',
      ),
      accountantName: _readString(
        json,
        'accountantName',
        fallbackKey: 'accountant_name',
      ),
      accountantPhone: _readString(
        json,
        'accountantPhone',
        fallbackKey: 'accountant_phone',
      ),
      archivedAt: _readDateTime(json, 'archivedAt', fallbackKey: 'archived_at'),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SyncCursor? _cursorFromJson(Object? rawCursor) {
    if (rawCursor == null) {
      return null;
    }

    if (rawCursor is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Company changes nextCursor must be a JSON object.',
      );
    }

    final updatedAt = _readDateTime(rawCursor, 'updatedAt');
    final serverUuid = _readString(rawCursor, 'id');

    if (updatedAt == null || serverUuid == null) {
      throw const ApiDecodingException(
        'Company changes nextCursor is incomplete.',
      );
    }

    return SyncCursor(
      entityType: syncEntityTypeCompany,
      updatedAt: updatedAt.toUtc(),
      serverUuid: serverUuid,
    );
  }

  String? _readString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

    if (value == null) {
      return null;
    }

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return value.toString();
  }

  DateTime? _readDateTime(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }

    return null;
  }
}
