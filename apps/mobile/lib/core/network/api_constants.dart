import '../config/endpoints.dart';

abstract final class ApiConstants {
  ApiConstants._();

  static const String companiesEndpoint = Endpoints.companies;
  static const String bankAccountsEndpoint = Endpoints.bankAccounts;
  static const String chequesEndpoint = Endpoints.cheques;
  static const String chequeAttachmentsEndpoint = Endpoints.chequeAttachments;
  static const String cashPaymentsEndpoint = Endpoints.cashPayments;
  static const String cashPaymentAttachmentsEndpoint =
      Endpoints.cashPaymentAttachments;
  static const String syncChequesEndpoint = Endpoints.syncCheques;
  static const String healthEndpoint = Endpoints.health;
  static const String androidAppUpdateEndpoint = Endpoints.appUpdateAndroid;

  static const String authLoginEndpoint = '/auth/login';
  static const String authMeEndpoint = '/auth/me';
  static const String authLogoutEndpoint = '/auth/logout';
  static const String authUsersEndpoint = '/auth/users';
  static const String pushDeviceRegisterEndpoint = '/push/devices/register';
  static const String pushDeviceUnregisterEndpoint = '/push/devices/unregister';
  static const String pushDevicePreferencesReadEndpoint =
      '/push/devices/preferences/read';
  static const String pushDevicePreferencesEndpoint =
      '/push/devices/preferences';
  static const String pushNotificationAcknowledgeEndpoint =
      '/push/notifications/acknowledge';
  static const String pushNotificationsAcknowledgeAllEndpoint =
      '/push/notifications/acknowledge-all';
  static const String ordersEndpoint = '/orders';
}
