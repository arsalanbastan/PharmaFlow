import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/auth/staff_auth_token_storage.dart';
import 'sales_invoice.dart';
import 'catalog_item_details.dart';

class StaffCatalogItem {
  StaffCatalogItem(Map<String, dynamic> data)
      : id = data['id'] as String,
        name = (data['persianName'] ?? data['persianBrandName'] ?? data['brandName'] ?? data['genericName'] ?? '') as String,
        unit = data['unit'] as String?,
        category = data['category'] as String? ?? 'DRUG',
        shape = data['shapeName'] as String?,
        packetQuantity = data['packetQuantity'] as int?,
        alternateName = data['genericName'] as String?,
        price = double.tryParse('${data['salesPrice'] ?? 0}') ?? 0;
  final String id;
  final String name;
  final String category;
  final String? shape, alternateName;
  final int? packetQuantity;
  final String? unit;
  String get details => catalogItemDetails(
      category: category, name: name, alternateName: alternateName,
      shape: shape, unit: unit, packetQuantity: packetQuantity);
  final double price;
}

class StaffSalesApi {
  static const _base = String.fromEnvironment('PHARMAFLOW_API_BASE_URL',
      defaultValue: 'https://naughty-haslett-zvtszb2yr.liara.run/api/v1');
  final _client = http.Client();
  final _storage = StaffAuthTokenStorage();
  void close() => _client.close();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) throw StateError('لطفاً دوباره وارد شوید.');
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<Map<String, dynamic>> _request(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final headers = await _headers();
    final response = body == null
        ? await _client.get(uri, headers: headers).timeout(const Duration(seconds: 25))
        : await _client.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('خطای سرور (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
    }
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)) as Map);
  }

  Future<SalesInvoicePage> list({String query = ''}) async => SalesInvoicePage.fromJson(
      await _request('/sales-invoices?page=1&pageSize=25&q=${Uri.encodeQueryComponent(query)}'));
  Future<SalesInvoiceDetails> detail(String id) async => SalesInvoiceDetails.fromJson(
      await _request('/sales-invoices/${Uri.encodeComponent(id)}'));
  Future<SalesInvoiceDetails> create(Map<String, dynamic> body) async => SalesInvoiceDetails.fromJson(
      await _request('/sales-invoices', body: body));
  Future<List<StaffCatalogItem>> search(String query) async {
    final items = <StaffCatalogItem>[];
    var page = 1;
    while (true) {
      final data = await _request('/catalog/staff-search?q=${Uri.encodeQueryComponent(query)}&page=$page');
      items.addAll((data['items'] as List).map((row) =>
          StaffCatalogItem(Map<String, dynamic>.from(row as Map))));
      if (page >= (data['totalPages'] as int)) return items;
      page++;
    }
  }
}
