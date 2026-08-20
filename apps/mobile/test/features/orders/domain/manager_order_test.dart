import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/features/orders/domain/manager_order.dart';

void main() {
  test('parses production-shaped pending order payload', () {
    final order = ManagerOrder.fromJson(<String, dynamic>{
      'id': '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
      'category': 'DRUG',
      'itemText': 'آتورواستاتین 20 تست',
      'requestedQuantity': 2,
      'suggestedCompanyText': null,
      'notes': 'تست اولین سفارش PharmaFlow',
      'status': 'PENDING',
      'possibleDuplicate': false,
      'requestedByName': 'ارسلان2',
      'requestedByUserId': '11111111-1111-4111-8111-111111111111',
      'createdAt': '2026-08-18T04:00:00.000Z',
      'assignedCompany': null,
    });

    expect(order.id, '9d5eaa73-4c17-467e-995f-2af4a428b5a1');
    expect(order.category, 'DRUG');
    expect(order.itemText, 'آتورواستاتین 20 تست');
    expect(order.requestedQuantity, 2);
    expect(order.requestedByName, 'ارسلان2');
    expect(order.isPending, isTrue);
  });

  test('parses assigned company when present', () {
    final order = ManagerOrder.fromJson(<String, dynamic>{
      'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'category': 'GOODS',
      'itemText': 'کالای تست',
      'requestedQuantity': null,
      'status': 'ORDERED',
      'possibleDuplicate': false,
      'requestedByName': 'کاربر',
      'createdAt': '2026-08-18T04:00:00.000Z',
      'assignedCompany': <String, dynamic>{
        'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'name': 'شرکت تست',
      },
    });

    expect(order.assignedCompanyName, 'شرکت تست');
    expect(order.status, 'ORDERED');
  });
}
