import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/features/orders/domain/manager_order.dart';

void main() {
  test('ordered list quantity uses server orderedQuantity when present', () {
    final order = ManagerOrder.fromJson(<String, dynamic>{
      'id': '9d5eaa73-4c17-467e-995f-2af4a428b5a1',
      'category': 'DRUG',
      'itemText': 'آتورواستاتین 20 تست',
      'requestedQuantity': 2,
      'orderedQuantity': 5,
      'suggestedCompanyText': null,
      'notes': null,
      'status': 'ORDERED',
      'possibleDuplicate': false,
      'requestedByName': 'ارسلان2',
      'requestedByUserId': '11111111-1111-4111-8111-111111111111',
      'createdAt': '2026-08-18T04:00:00.000Z',
      'assignedCompany': <String, dynamic>{
        'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'name': 'شرکت تست',
      },
    });

    expect(order.requestedQuantity, 2);
    expect(order.orderedQuantity, 5);
    expect(order.assignedCompanyName, 'شرکت تست');
    expect(order.status, 'ORDERED');
  });

  test('orderedQuantity remains optional for pending orders', () {
    final order = ManagerOrder.fromJson(<String, dynamic>{
      'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'category': 'GOODS',
      'itemText': 'کالای تست',
      'requestedQuantity': 3,
      'status': 'PENDING',
      'possibleDuplicate': false,
      'requestedByName': 'کاربر تست',
      'createdAt': '2026-08-18T04:00:00.000Z',
    });

    expect(order.requestedQuantity, 3);
    expect(order.orderedQuantity, isNull);
  });
}
