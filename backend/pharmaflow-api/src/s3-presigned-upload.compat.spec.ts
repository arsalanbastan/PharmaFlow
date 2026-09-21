import { CashPaymentAttachmentStorageService } from './cash-payments/cash-payment-attachment-storage.service';
import { ChequeAttachmentStorageService } from './cheques/cheque-attachment-storage.service';

describe('S3-compatible presigned attachment uploads', () => {
  const environmentKeys = [
    'DOCUMENT_STORAGE_S3_ENDPOINT',
    'DOCUMENT_STORAGE_S3_BUCKET',
    'DOCUMENT_STORAGE_S3_ACCESS_KEY',
    'DOCUMENT_STORAGE_S3_SECRET_KEY',
  ];

  const previousEnvironment = new Map<string, string | undefined>();

  beforeEach(() => {
    for (const key of environmentKeys) {
      previousEnvironment.set(key, process.env[key]);
    }

    process.env.DOCUMENT_STORAGE_S3_ENDPOINT =
      'https://s3.example.invalid';
    process.env.DOCUMENT_STORAGE_S3_BUCKET =
      'test-document-bucket';
    process.env.DOCUMENT_STORAGE_S3_ACCESS_KEY =
      'FAKE_TEST_ACCESS_KEY';
    process.env.DOCUMENT_STORAGE_S3_SECRET_KEY =
      'FAKE_TEST_SECRET_KEY';
  });

  afterEach(() => {
    for (const key of environmentKeys) {
      const previousValue = previousEnvironment.get(key);

      if (previousValue === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = previousValue;
      }
    }

    previousEnvironment.clear();
  });

  const cases = [
    {
      name: 'cash payment attachment',
      prepare: () =>
        new CashPaymentAttachmentStorageService().createUploadUrl({
          cashPaymentId: '11111111-1111-4111-8111-111111111111',
          attachmentId: '22222222-2222-4222-8222-222222222222',
          mimeType: 'image/jpeg',
        }),
    },
    {
      name: 'cheque attachment',
      prepare: () =>
        new ChequeAttachmentStorageService().createUploadUrl({
          chequeId: '11111111-1111-4111-8111-111111111111',
          attachmentId: '22222222-2222-4222-8222-222222222222',
          mimeType: 'image/jpeg',
        }),
    },
  ];

  it.each(cases)(
    'generates a checksum-free signed PUT URL for $name',
    async ({ prepare }) => {
      const result = await prepare();
      const url = new URL(result.uploadUrl);

      expect(url.searchParams.get('X-Amz-Signature')).toBeTruthy();

      const checksumParameters = [...url.searchParams.keys()].filter(
        (key) => key.toLowerCase().includes('checksum'),
      );

      expect(checksumParameters).toEqual([]);
    },
  );
});