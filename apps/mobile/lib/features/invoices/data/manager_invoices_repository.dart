import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/manager_invoice.dart';
import '../domain/manager_invoice_settlement.dart';

class ManagerInvoicesRepository {
  const ManagerInvoicesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ManagerInvoicePage> getPage({
    String? query,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 50,
  }) async {
    final normalizedQuery = query?.trim();

    final payload = await _apiClient.get(
      ApiConstants.invoicesEndpoint,
      queryParameters: <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (normalizedQuery != null && normalizedQuery.isNotEmpty)
          'q': normalizedQuery,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the Invoices endpoint.',
      );
    }

    return ManagerInvoicePage.fromJson(payload);
  }

  Future<void> setPaid({
    required String invoiceId,
    required bool isPaid,
  }) async {
    final normalizedId = invoiceId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('invoiceId cannot be empty.');
    }

    await _apiClient.patch(
      '${ApiConstants.invoicesEndpoint}/$normalizedId/payment-status',
      body: <String, dynamic>{'isPaid': isPaid},
    );
  }

  Future<ManagerInvoiceDetails> getById(String invoiceId) async {
    final normalizedId = invoiceId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('invoiceId cannot be empty.');
    }

    final payload = await _apiClient.get(
      '${ApiConstants.invoicesEndpoint}/$normalizedId',
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the Invoice details endpoint.',
      );
    }

    return ManagerInvoiceDetails.fromJson(payload);
  }

  Future<InvoiceSettlementPreparation> prepareSettlement(
    Iterable<String> invoiceIds,
  ) async {
    final ids = invoiceIds.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final joined = ids.join(',');
    if (joined.isEmpty) {
      throw ArgumentError('At least one invoice id is required.');
    }

    final payload = await _apiClient.get(
      '${ApiConstants.invoicesEndpoint}/settlement/prepare',
      queryParameters: <String, String>{'invoiceIds': joined},
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the settlement preparation endpoint.',
      );
    }
    return InvoiceSettlementPreparation.fromJson(payload);
  }

  Future<Map<String, dynamic>> createSettlement(
    Map<String, dynamic> request,
  ) async {
    final payload = await _apiClient.post(
      '${ApiConstants.invoicesEndpoint}/settlement',
      body: request,
    );
    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the settlement endpoint.',
      );
    }
    return payload;
  }
}
