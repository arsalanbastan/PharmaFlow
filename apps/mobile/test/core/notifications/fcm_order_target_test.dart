import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/core/notifications/fcm_order_target.dart';

void main() {
  const validOrderId = '9d5eaa73-4c17-467e-995f-2af4a428b5a1';

  test('accepts ORDER_CREATED with a valid UUID orderId', () {
    final target = FcmOrderTarget.fromData(<String, dynamic>{
      'type': 'ORDER_CREATED',
      'orderId': validOrderId,
    });

    expect(target, isNotNull);
    expect(target!.orderId, validOrderId);
  });

  test('normalizes type casing and surrounding whitespace', () {
    final target = FcmOrderTarget.fromData(<String, dynamic>{
      'type': '  order_created  ',
      'orderId': '  $validOrderId  ',
    });

    expect(target, isNotNull);
    expect(target!.orderId, validOrderId);
  });

  test('ignores unrelated notification types', () {
    final target = FcmOrderTarget.fromData(<String, dynamic>{
      'type': 'MESSAGE_CREATED',
      'orderId': validOrderId,
    });

    expect(target, isNull);
  });

  test('ignores missing or invalid orderId', () {
    expect(
      FcmOrderTarget.fromData(<String, dynamic>{'type': 'ORDER_CREATED'}),
      isNull,
    );

    expect(
      FcmOrderTarget.fromData(<String, dynamic>{
        'type': 'ORDER_CREATED',
        'orderId': 'not-a-uuid',
      }),
      isNull,
    );
  });
}
