import { notificationModeForEvent } from './push-worker.service';

describe('push notification preferences', () => {
  const base = {
    notificationsEnabled: true,
    orderNotificationMode: 'AUDIBLE',
    chequeNotificationMode: 'SILENT',
    cashPaymentNotificationMode: 'OFF',
  };

  it('honors the master notification switch', () => {
    expect(
      notificationModeForEvent(
        {
          ...base,
          notificationsEnabled: false,
        },
        'ORDER_CREATED',
      ),
    ).toBe('OFF');
  });

  it('returns the configured per-event mode', () => {
    expect(notificationModeForEvent(base, 'ORDER_CREATED')).toBe('AUDIBLE');
    expect(notificationModeForEvent(base, 'CHEQUE_CREATED')).toBe('SILENT');
    expect(notificationModeForEvent(base, 'CASH_PAYMENT_CREATED')).toBe('OFF');
  });

  it('drops unsupported or invalid modes', () => {
    expect(notificationModeForEvent(base, 'UNKNOWN')).toBe('OFF');
    expect(
      notificationModeForEvent(
        {
          ...base,
          orderNotificationMode: 'INVALID',
        },
        'ORDER_CREATED',
      ),
    ).toBe('OFF');
  });
});
