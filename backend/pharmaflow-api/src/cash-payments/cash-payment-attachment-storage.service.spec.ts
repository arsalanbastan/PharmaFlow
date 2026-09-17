import { BadRequestException } from '@nestjs/common';

import { CashPaymentAttachmentStorageService } from './cash-payment-attachment-storage.service';

describe('CashPaymentAttachmentStorageService', () => {
  let service: CashPaymentAttachmentStorageService;

  beforeEach(() => {
    service = new CashPaymentAttachmentStorageService();
  });

  it('builds the receipt JPEG storage key', () => {
    expect(
      service.buildStorageKey({
        cashPaymentId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '22222222-2222-4222-8222-222222222222',
        mimeType: 'image/jpeg',
      }),
    ).toBe(
      'cash-payments/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.jpg',
    );
  });

  it('builds the statement PDF storage key', () => {
    expect(
      service.buildStorageKey({
        cashPaymentId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '33333333-3333-4333-8333-333333333333',
        mimeType: 'application/pdf',
      }),
    ).toBe(
      'cash-payments/11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.pdf',
    );
  });

  it('rejects unsupported attachment types', () => {
    expect(() =>
      service.buildStorageKey({
        cashPaymentId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '22222222-2222-4222-8222-222222222222',
        mimeType: 'application/x-msdownload',
      }),
    ).toThrow(BadRequestException);
  });
});
