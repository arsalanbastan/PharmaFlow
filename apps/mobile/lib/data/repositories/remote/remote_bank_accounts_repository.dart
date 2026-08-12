import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';

class RemoteBankAccountsRepository {
  RemoteBankAccountsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> updateByServerUuid(
    String serverUuid,
    Map<String, dynamic> payload,
  ) async {
    await _apiClient.patch(
      '${ApiConstants.bankAccountsEndpoint}/$serverUuid',
      body: payload,
    );
  }
}
