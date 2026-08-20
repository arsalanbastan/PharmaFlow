import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/manager_order.dart';
import '../domain/manager_order_details.dart';

class ManagerOrdersRepository {
  const ManagerOrdersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ManagerOrder>> getAll({String? status, String? category}) async {
    final queryParameters = <String, String>{};

    final normalizedStatus = status?.trim();
    final normalizedCategory = category?.trim();

    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      queryParameters['status'] = normalizedStatus;
    }

    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      queryParameters['category'] = normalizedCategory;
    }

    final payload = await _apiClient.get(
      ApiConstants.ordersEndpoint,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    if (payload is! List<dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON list from the Orders endpoint.',
      );
    }

    return payload
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException(
              'Order list item is not a JSON object.',
            );
          }

          return ManagerOrder.fromJson(raw);
        })
        .toList(growable: false);
  }

  Future<ManagerOrderDetails> getById(String orderId) async {
    final normalizedOrderId = orderId.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    final payload = await _apiClient.get(
      '${ApiConstants.ordersEndpoint}/$normalizedOrderId',
    );

    if (payload is! Map<String, dynamic>) {
      throw const ApiDecodingException(
        'Expected a JSON object from the Order details endpoint.',
      );
    }

    return ManagerOrderDetails.fromJson(payload);
  }

  Future<ManagerOrderPhoto?> getPhoto(String orderId) async {
    final normalizedOrderId = orderId.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    try {
      final payload = await _apiClient.get(
        '${ApiConstants.ordersEndpoint}/$normalizedOrderId/photo',
      );

      if (payload is! Map<String, dynamic>) {
        throw const ApiDecodingException(
          'Expected a JSON object from the Order photo endpoint.',
        );
      }

      return ManagerOrderPhoto.fromJson(payload);
    } on ApiHttpException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<void> assign({
    required String orderId,
    required String companyId,
    int? quantity,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedCompanyId = companyId.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    if (normalizedCompanyId.isEmpty) {
      throw ArgumentError('companyId cannot be empty.');
    }

    if (quantity != null && (quantity < 1 || quantity > 1000000)) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Order quantity must be between 1 and 1000000.',
      );
    }

    await _apiClient.post(
      '${ApiConstants.ordersEndpoint}/$normalizedOrderId/assign',
      body: <String, dynamic>{
        'companyId': normalizedCompanyId,
        if (quantity != null) 'quantity': quantity,
      },
    );
  }

  Future<void> updatePending({
    required String orderId,
    required String category,
    required String itemText,
    int? requestedQuantity,
    String? suggestedCompanyText,
    String? notes,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedCategory = category.trim().toUpperCase();
    final normalizedItemText = itemText.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    if (normalizedCategory != 'DRUG' && normalizedCategory != 'GOODS') {
      throw ArgumentError.value(
        category,
        'category',
        'Invalid order category.',
      );
    }

    if (normalizedItemText.isEmpty || normalizedItemText.length > 300) {
      throw ArgumentError.value(
        itemText,
        'itemText',
        'Order item text must be between 1 and 300 characters.',
      );
    }

    if (requestedQuantity != null &&
        (requestedQuantity < 1 || requestedQuantity > 1000000)) {
      throw ArgumentError.value(
        requestedQuantity,
        'requestedQuantity',
        'Order quantity must be between 1 and 1000000.',
      );
    }

    await _apiClient.post(
      '${ApiConstants.ordersEndpoint}/$normalizedOrderId/edit',
      body: <String, dynamic>{
        'category': normalizedCategory,
        'itemText': normalizedItemText,
        'requestedQuantity': requestedQuantity,
        'suggestedCompanyText': _nullIfBlank(suggestedCompanyText),
        'notes': _nullIfBlank(notes),
      },
    );
  }

  Future<void> returnToPending({required String orderId}) async {
    final normalizedOrderId = orderId.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    await _apiClient.post(
      '${ApiConstants.ordersEndpoint}/$normalizedOrderId/return-to-pending',
    );
  }

  Future<void> cancel({required String orderId}) async {
    final normalizedOrderId = orderId.trim();

    if (normalizedOrderId.isEmpty) {
      throw ArgumentError('orderId cannot be empty.');
    }

    await _apiClient.post(
      '${ApiConstants.ordersEndpoint}/$normalizedOrderId/cancel',
    );
  }

  String? _nullIfBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
