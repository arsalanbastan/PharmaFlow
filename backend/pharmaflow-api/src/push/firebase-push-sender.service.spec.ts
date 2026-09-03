import {
  buildCreatedMessage,
  buildOrderCreatedMessage,
  classifyFirebaseMessagingError,
} from './firebase-push-sender.service';

describe('FirebasePushSenderService helpers', () => {
  it('builds an ORDER_CREATED wire payload without internal order details', () => {
    const message = buildOrderCreatedMessage(
      'registration-token-1234567890',
      '22222222-2222-4222-8222-222222222222',
    );

    expect(message).toEqual(
      expect.objectContaining({
        token: 'registration-token-1234567890',
        notification: {
          title: 'سفارش جدید',
          body: 'یک سفارش جدید ثبت شد.',
        },
        data: {
          type: 'ORDER_CREATED',
          orderId: '22222222-2222-4222-8222-222222222222',
        },
      }),
    );

    expect(message.data).not.toHaveProperty('itemText');
    expect(message.data).not.toHaveProperty('requestedByName');
  });

  it('builds one stable aggregated notification per event type', () => {
    const message = buildCreatedMessage(
      'ORDER_CREATED',
      'registration-token-1234567890',
      '22222222-2222-4222-8222-222222222222',
      'AUDIBLE',
      {
        deliveryId: '33333333-3333-4333-8333-333333333333',
        count: 3,
      },
    );

    expect(message.notification).toEqual({
      title: 'سفارش جدید',
      body: 'شما 3 سفارش جدید دارید',
    });

    expect(message.data).toEqual({
      type: 'ORDER_CREATED',
      orderId: '22222222-2222-4222-8222-222222222222',
      notificationDeliveryId:
        '33333333-3333-4333-8333-333333333333',
      notificationCount: '3',
    });

    expect(message.android?.collapseKey).toBe('order');
    expect(message.android?.notification?.tag).toBe('order');
  });

  it('classifies an unregistered token as a permanent device failure', () => {
    expect(
      classifyFirebaseMessagingError({
        code: 'messaging/registration-token-not-registered',
      }),
    ).toEqual({
      kind: 'invalid-token',
      code: 'messaging/registration-token-not-registered',
    });
  });

  it('keeps service/network failures retryable', () => {
    expect(
      classifyFirebaseMessagingError({
        code: 'messaging/server-unavailable',
      }),
    ).toEqual({
      kind: 'retry',
      code: 'messaging/server-unavailable',
    });
  });
});
