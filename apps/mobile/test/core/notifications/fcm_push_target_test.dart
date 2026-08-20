import '../../../lib/core/notifications/fcm_order_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '22222222-2222-4222-8222-222222222222';

  test('parses ORDER_CREATED target', () {
    final target = FcmPushTarget.fromData(<String, dynamic>{
      'type': 'ORDER_CREATED',
      'orderId': id,
    });

    expect(target?.kind, FcmPushTargetKind.order);
    expect(target?.id, id);
  });

  test('parses CHEQUE_CREATED target', () {
    final target = FcmPushTarget.fromData(<String, dynamic>{
      'type': 'CHEQUE_CREATED',
      'chequeId': id,
    });

    expect(target?.kind, FcmPushTargetKind.cheque);
    expect(target?.id, id);
  });

  test('parses CASH_PAYMENT_CREATED target', () {
    final target = FcmPushTarget.fromData(<String, dynamic>{
      'type': 'CASH_PAYMENT_CREATED',
      'cashPaymentId': id,
    });

    expect(target?.kind, FcmPushTargetKind.cashPayment);
    expect(target?.id, id);
  });

  test('rejects wrong id key and invalid UUID', () {
    expect(
      FcmPushTarget.fromData(<String, dynamic>{
        'type': 'CHEQUE_CREATED',
        'orderId': id,
      }),
      isNull,
    );

    expect(
      FcmPushTarget.fromData(<String, dynamic>{
        'type': 'CASH_PAYMENT_CREATED',
        'cashPaymentId': 'bad-id',
      }),
      isNull,
    );
  });
}
