import {
  buildCreatedMessage,
  buildOrderCreatedMessage,
} from './firebase-push-sender.service';

describe('created entity push events', () => {
  const token = 'registration-token-1234567890';
  const id = '22222222-2222-4222-8222-222222222222';

  it('preserves the existing audible ORDER_CREATED wire contract', () => {
    expect(buildOrderCreatedMessage(token, id)).toEqual(
      expect.objectContaining({
        data: {
          type: 'ORDER_CREATED',
          orderId: id,
        },
        android: expect.objectContaining({
          priority: 'high',
          collapseKey: `order-${id}`,
          notification: {
            tag: `order-${id}`,
          },
        }),
      }),
    );
  });

  it('builds CHEQUE_CREATED with only the target id on the wire', () => {
    expect(buildCreatedMessage('CHEQUE_CREATED', token, id)).toEqual(
      expect.objectContaining({
        notification: {
          title: 'چک جدید ثبت شد',
          body: 'یک چک جدید ثبت شد.',
        },
        data: {
          type: 'CHEQUE_CREATED',
          chequeId: id,
        },
      }),
    );
  });

  it('builds silent CASH_PAYMENT_CREATED on the silent channel', () => {
    expect(
      buildCreatedMessage('CASH_PAYMENT_CREATED', token, id, 'SILENT'),
    ).toEqual(
      expect.objectContaining({
        data: {
          type: 'CASH_PAYMENT_CREATED',
          cashPaymentId: id,
        },
        android: expect.objectContaining({
          collapseKey: `cash-payment-${id}`,
          notification: {
            tag: `cash-payment-${id}`,
            channelId: 'pharmaflow_silent',
          },
        }),
      }),
    );
  });
});
