import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/manager_catalog_item.dart';

class ManagerCatalogRepository {
  const ManagerCatalogRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ManagerCatalogPage> getPage({
    String? query,
    String? category,
    String? active,
    int page = 1,
    int pageSize = 50,
  }) async {
    final normalizedQuery = query?.trim();

    final normalizedCategory = category?.trim();

    final normalizedActive = active?.trim();

    final payload = await _apiClient.get(
      ApiConstants.catalogEndpoint,
      queryParameters: <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (normalizedQuery != null && normalizedQuery.isNotEmpty)
          'q': normalizedQuery,
        if (normalizedCategory != null && normalizedCategory.isNotEmpty)
          'category': normalizedCategory,
        if (normalizedActive != null && normalizedActive.isNotEmpty)
          'active': normalizedActive,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the Catalog endpoint.',
      );
    }

    return ManagerCatalogPage.fromJson(payload);
  }

  Future<ManagerCatalogDetails> getById(String itemId) async {
    final normalizedId = itemId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('itemId cannot be empty.');
    }

    final payload = await _apiClient.get(
      '${ApiConstants.catalogEndpoint}/$normalizedId',
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the Catalog details endpoint.',
      );
    }

    return ManagerCatalogDetails.fromJson(payload);
  }
}
