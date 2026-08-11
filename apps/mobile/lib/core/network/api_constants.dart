import '../config/endpoints.dart';

abstract final class ApiConstants {
  ApiConstants._();

  static const String companiesEndpoint = Endpoints.companies;
  static const String bankAccountsEndpoint = Endpoints.bankAccounts;
  static const String chequesEndpoint = Endpoints.cheques;
  static const String syncChequesEndpoint = Endpoints.syncCheques;
  static const String healthEndpoint = Endpoints.health;
}
