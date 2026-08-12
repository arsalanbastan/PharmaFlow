import '../database/database_service.dart';

class SyncIdentityMappingException implements Exception {
  const SyncIdentityMappingException(this.message);

  final String message;

  @override
  String toString() => 'SyncIdentityMappingException: $message';
}

class SyncIdentityResolver {
  SyncIdentityResolver(this._databaseService);

  final DatabaseService _databaseService;

  Future<String> resolveCompanyUuid(int localId) async {
    final result = _databaseService.database.select(
      '''
      SELECT server_uuid
      FROM companies
      WHERE id = ?
      LIMIT 1
      ''',
      [localId],
    );

    if (result.isEmpty) {
      throw SyncIdentityMappingException(
        'Company local id $localId was not found for sync.',
      );
    }

    final serverUuid = result.first['server_uuid'] as String?;
    if (serverUuid == null || serverUuid.trim().isEmpty) {
      throw SyncIdentityMappingException(
        'Company local id $localId has no server UUID mapping.',
      );
    }

    return serverUuid.trim();
  }

  Future<String> resolveBankAccountUuid(int localId) async {
    final result = _databaseService.database.select(
      '''
      SELECT server_uuid
      FROM bank_accounts
      WHERE id = ?
      LIMIT 1
      ''',
      [localId],
    );

    if (result.isEmpty) {
      throw SyncIdentityMappingException(
        'Bank account local id $localId was not found for sync.',
      );
    }

    final serverUuid = result.first['server_uuid'] as String?;
    if (serverUuid == null || serverUuid.trim().isEmpty) {
      throw SyncIdentityMappingException(
        'Bank account local id $localId has no server UUID mapping.',
      );
    }

    return serverUuid.trim();
  }
}
