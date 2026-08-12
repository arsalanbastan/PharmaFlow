import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/utils/company_name_normalizer.dart';
import '../../models/company.dart';
import '../interfaces/company_repository.dart';

class RemoteCompanyRepository implements CompanyRepository {
  RemoteCompanyRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Company>> getAll({bool includeArchived = false}) async {
    final payload = await _apiClient.get(ApiConstants.companiesEndpoint);

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON list from remote companies endpoint.',
      );
    }

    final companies = payload
        .whereType<Map<String, dynamic>>()
        .map(_companyFromJson)
        .toList();

    if (includeArchived) {
      return companies;
    }

    return companies.where((company) => company.archivedAt == null).toList();
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

      return matchesName || matchesNationalId || matchesEconomicCode;
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
    throw UnsupportedError('Remote insert is not implemented yet.');
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

  Company _companyFromJson(Map<String, dynamic> json) {
    final name = _readString(json, 'name');

    if (name == null) {
      throw const ApiDecodingException(
        'Company name is missing in remote response.',
      );
    }

    return Company(
      id: _readInt(json, 'id'),
      name: name,
      nationalId: _readString(json, 'nationalId', fallbackKey: 'national_id'),
      economicCode: _readString(
        json,
        'economicCode',
        fallbackKey: 'economic_code',
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
      createdAt:
          _readDateTime(json, 'createdAt', fallbackKey: 'created_at') ??
          DateTime.now(),
      updatedAt:
          _readDateTime(json, 'updatedAt', fallbackKey: 'updated_at') ??
          DateTime.now(),
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

  int? _readInt(Map<String, dynamic> json, String key, {String? fallbackKey}) {
    final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
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
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    return null;
  }
}
