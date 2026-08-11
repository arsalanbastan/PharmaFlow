import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';

class RemoteChequeRecord {
  const RemoteChequeRecord({
    required this.id,
    required this.companyId,
    required this.bankAccountId,
    required this.chequeNumber,
    required this.amount,
    required this.chequeDate,
    required this.dueDate,
    required this.isRegisteredInSayad,
    required this.sayadId,
    required this.description,
  });

  final String id;
  final String companyId;
  final String bankAccountId;
  final String chequeNumber;
  final num amount;
  final DateTime chequeDate;
  final DateTime? dueDate;
  final bool? isRegisteredInSayad;
  final String? sayadId;
  final String? description;

  factory RemoteChequeRecord.fromJson(Map<String, dynamic> json) {
    return RemoteChequeRecord(
      id: (json['id'] ?? '').toString().trim(),
      companyId: (json['companyId'] ?? '').toString().trim(),
      bankAccountId: (json['bankAccountId'] ?? '').toString().trim(),
      chequeNumber: (json['chequeNumber'] ?? '').toString().trim(),
      amount: _readAmount(json['amount']),
      chequeDate: DateTime.parse(json['chequeDate'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      isRegisteredInSayad: json['isRegisteredInSayad'] as bool?,
      sayadId: (json['sayadId'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
    );
  }
}

class RemoteChequeRepository {
  RemoteChequeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<RemoteChequeRecord>> getAll() async {
    final payload = await _apiClient.get(ApiConstants.chequesEndpoint);

    if (payload is! List) {
      throw const ApiDecodingException(
        'Expected cheques endpoint to return a JSON list.',
      );
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(RemoteChequeRecord.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<String?> create(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      ApiConstants.chequesEndpoint,
      body: payload,
    );

    if (response is Map<String, dynamic>) {
      final id = response['id']?.toString().trim();
      return id == null || id.isEmpty ? null : id;
    }

    return null;
  }

  Future<void> update(String serverUuid, Map<String, dynamic> payload) async {
    await _apiClient.patch(
      '${ApiConstants.chequesEndpoint}/$serverUuid',
      body: payload,
    );
  }

  Future<void> delete(String serverUuid) async {
    await _apiClient.delete('${ApiConstants.chequesEndpoint}/$serverUuid');
  }
}

num _readAmount(Object? raw) {
  if (raw is num) {
    return raw;
  }

  if (raw is String) {
    final normalized = raw.trim().replaceAll(',', '');
    final parsed = num.tryParse(normalized);
    if (parsed != null) {
      return parsed;
    }
  }

  return 0;
}
