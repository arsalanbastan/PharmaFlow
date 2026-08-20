import { BadRequestException } from '@nestjs/common';

import { OrderPhotoStorageService } from './order-photo-storage.service';

describe('OrderPhotoStorageService', () => {
  const service = new OrderPhotoStorageService();

  it('builds stable order photo key', () => {
    expect(
      service.buildStorageKey('11111111-1111-4111-8111-111111111111'),
    ).toBe('order-requests/11111111-1111-4111-8111-111111111111/request.jpg');
  });

  it('rejects photos over 200KB before requesting storage', async () => {
    await expect(
      service.createUploadUrl({
        orderId: '11111111-1111-4111-8111-111111111111',
        mimeType: 'image/jpeg',
        fileSize: 204801,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects non-JPEG order photos', async () => {
    await expect(
      service.createUploadUrl({
        orderId: '11111111-1111-4111-8111-111111111111',
        mimeType: 'image/png',
        fileSize: 1000,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
