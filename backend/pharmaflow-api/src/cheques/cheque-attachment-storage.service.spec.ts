import { BadRequestException } from '@nestjs/common';

import { ChequeAttachmentStorageService } from './cheque-attachment-storage.service';

describe('ChequeAttachmentStorageService', () => {
  let service: ChequeAttachmentStorageService;

  beforeEach(() => {
    service = new ChequeAttachmentStorageService();
  });

  it('builds the statement JPEG storage key', () => {
    expect(
      service.buildStorageKey({
        chequeId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '22222222-2222-4222-8222-222222222222',
        mimeType: 'image/jpeg',
      }),
    ).toBe(
      'cheques/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.jpg',
    );
  });

  it('builds the statement PDF storage key', () => {
    expect(
      service.buildStorageKey({
        chequeId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '33333333-3333-4333-8333-333333333333',
        mimeType: 'application/pdf',
      }),
    ).toBe(
      'cheques/11111111-1111-4111-8111-111111111111/33333333-3333-4333-8333-333333333333.pdf',
    );
  });

  it('rejects unsupported attachment types', () => {
    expect(() =>
      service.buildStorageKey({
        chequeId: '11111111-1111-4111-8111-111111111111',
        attachmentId: '22222222-2222-4222-8222-222222222222',
        mimeType: 'application/x-msdownload',
      }),
    ).toThrow(BadRequestException);
  });
});
