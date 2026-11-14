import 'sales_invoice.dart';
import 'catalog_item_details.dart';

typedef SalesRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      Map<String, dynamic>? body,
      String? method,
    });

class StaffCatalogItem {
  StaffCatalogItem(Map<String, dynamic> data)
    : id = data['id'] as String,
      name =
          (data['persianName'] ??
                  data['persianBrandName'] ??
                  data['brandName'] ??
                  data['genericName'] ??
                  '')
              as String,
      unit = data['unit'] as String?,
      category = data['category'] as String? ?? 'UNKNOWN',
      matchedBarcode = data['matchedBarcode'] as String?,
      shape = data['shapeName'] as String?,
      brand = (data['persianBrandName'] ?? data['brandName']) as String?,
      packetQuantity = data['packetQuantity'] as int?,
      alternateName = data['genericName'] as String?,
      price = double.tryParse('${data['salesPrice'] ?? 0}') ?? 0;
  final String id;
  final String name;
  final String category;
  final String? matchedBarcode;
  final String? shape, alternateName, brand;
  final int? packetQuantity;
  final String? unit;
  String get details => catalogItemDetails(
    category: category,
    name: name,
    alternateName: alternateName,
    shape: shape,
    unit: unit,
    packetQuantity: packetQuantity,
    brand: brand,
  );
  final double price;
}

class SalesApi {
  SalesApi(this._request, {required this.canManage});

  final SalesRequest _request;
  final Future<bool> Function() canManage;

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
    String? method,
  }) => _request(path, body: body, method: method);

  void close() {}

  Future<SalesInvoiceProfile> profile() async =>
      SalesInvoiceProfile.fromJson(await _request('/sales-invoices/profile'));
  Future<SalesInvoiceProfile> updateProfile(Map<String, dynamic> body) async =>
      SalesInvoiceProfile.fromJson(
        await _request('/sales-invoices/profile', body: body, method: 'PUT'),
      );

  Future<SalesInvoicePage> list({
    String query = '',
    int page = 1,
  }) async => SalesInvoicePage.fromJson(
    await _request(
      '/sales-invoices?page=$page&pageSize=25&q=${Uri.encodeQueryComponent(query)}',
    ),
  );
  Future<SalesInvoiceDetails> detail(String id) async =>
      SalesInvoiceDetails.fromJson(
        await _request('/sales-invoices/${Uri.encodeComponent(id)}'),
      );
  Future<SalesInvoiceDetails> create(Map<String, dynamic> body) async =>
      SalesInvoiceDetails.fromJson(
        await _request('/sales-invoices', body: body),
      );
  Future<List<StaffCatalogItem>> searchBarcodeExact(
    List<String> candidates,
  ) async {
    final codes = candidates.toSet().toList();
    final response = await _request(
      '/catalog/staff-barcode?codes=${Uri.encodeQueryComponent(codes.join(','))}',
    );
    return (response['items'] as List)
        .map((row) => StaffCatalogItem(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<StaffCatalogItem>> search(String query) async {
    // The API already ranks the complete match set and returns the best 100.
    // Fetching every page repeated the same expensive ranking query for each
    // page, causing multi-request 10–20 second delays while typing.
    final data = await _request(
      '/catalog/staff-search?q=${Uri.encodeQueryComponent(query)}&page=1',
    );
    return (data['items'] as List)
        .map((row) => StaffCatalogItem(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }
}
