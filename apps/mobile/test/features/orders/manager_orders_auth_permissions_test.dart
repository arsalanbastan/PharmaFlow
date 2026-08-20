import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/orders/data/manager_orders_auth_service.dart';

void main() {
  test('manager always has effective full Manager access', () {
    final user = ManagerOrdersAuthUser.fromJson(<String, dynamic>{
      'userId': '11111111-1111-4111-8111-111111111111',
      'username': 'manager',
      'displayName': 'مدیر',
      'role': 'MANAGER',
    });

    expect(user.isManager, isTrue);
    expect(user.canUseManagerApp, isTrue);
    expect(user.permissions.managerAppAccess, isTrue);
    expect(user.permissions.canCreateCheques, isTrue);
    expect(user.permissions.canCreateCashPayments, isTrue);
    expect(user.permissions.canViewFinancialReports, isTrue);
  });

  test('staff can enter Manager only when managerAppAccess is true', () {
    final allowed = ManagerOrdersAuthUser.fromJson(<String, dynamic>{
      'userId': '22222222-2222-4222-8222-222222222222',
      'username': 'staff',
      'displayName': 'کارمند',
      'role': 'STAFF',
      'permissions': <String, dynamic>{
        'managerAppAccess': true,
        'canCreateOrders': true,
        'canCreateCheques': false,
        'canCreateCashPayments': true,
        'canViewFinancialReports': false,
      },
    });

    final denied = ManagerOrdersAuthUser.fromJson(<String, dynamic>{
      'userId': '33333333-3333-4333-8333-333333333333',
      'username': 'staff2',
      'displayName': 'کارمند ۲',
      'role': 'STAFF',
      'permissions': <String, dynamic>{
        'managerAppAccess': false,
        'canCreateOrders': true,
        'canCreateCheques': false,
        'canCreateCashPayments': false,
        'canViewFinancialReports': false,
      },
    });

    expect(allowed.canUseManagerApp, isTrue);
    expect(allowed.permissions.canCreateCashPayments, isTrue);
    expect(allowed.permissions.canViewFinancialReports, isFalse);

    expect(denied.canUseManagerApp, isFalse);
  });

  test('legacy staff response remains blocked from Manager app', () {
    final user = ManagerOrdersAuthUser.fromJson(<String, dynamic>{
      'userId': '44444444-4444-4444-8444-444444444444',
      'username': 'legacy',
      'displayName': 'Legacy Staff',
      'role': 'STAFF',
    });

    expect(user.permissions.canCreateOrders, isTrue);
    expect(user.permissions.managerAppAccess, isFalse);
    expect(user.canUseManagerApp, isFalse);
  });
}
