import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/sales_invoice.dart';

class SalesInvoicesRepository {
  const SalesInvoicesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SalesInvoicePage> getPage({
    String? query,
    int page = 1,
    int pageSize = 25,
  }) async {
    final payload = await _apiClient.get(
      ApiConstants.salesInvoicesEndpoint,
      queryParameters: <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException('Sales invoice list is invalid.');
    }
    return SalesInvoicePage.fromJson(payload);
  }

  Future<SalesInvoiceDetails> getById(String id) async {
    final payload = await _apiClient.get(
      '${ApiConstants.salesInvoicesEndpoint}/${id.trim()}',
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException('Sales invoice details are invalid.');
    }
    return SalesInvoiceDetails.fromJson(payload);
  }

  Future<SalesInvoiceDetails> create(Map<String, dynamic> request) async {
    final payload = await _apiClient.post(
      ApiConstants.salesInvoicesEndpoint,
      body: request,
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException('Created sales invoice is invalid.');
    }
    return SalesInvoiceDetails.fromJson(payload);
  }

  Future<SalesInvoiceProfile> getProfile() async {
    final payload = await _apiClient.get(
      '${ApiConstants.salesInvoicesEndpoint}/profile',
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException('Sales invoice profile is invalid.');
    }
    return SalesInvoiceProfile.fromJson(payload);
  }

  Future<SalesInvoiceProfile> updateProfile(
    Map<String, dynamic> request,
  ) async {
    final payload = await _apiClient.put(
      '${ApiConstants.salesInvoicesEndpoint}/profile',
      body: request,
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException('Sales invoice profile is invalid.');
    }
    return SalesInvoiceProfile.fromJson(payload);
  }
}
