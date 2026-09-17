import {
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
