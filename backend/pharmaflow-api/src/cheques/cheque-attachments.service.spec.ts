import { ChequeAttachmentsService } from './cheque-attachments.service';

describe('ChequeAttachmentsService', () => {
  const tx = {
    chequeAttachment: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
    },
  };

  const prisma = {
    cheque: {
      findFirst: jest.fn(),
    },
    chequeAttachment: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    $transaction: jest.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  };

  const auditLog = {
    record: jest.fn(),
  };

  const storage = {
    createUploadUrl: jest.fn(),
    verifyUploadedObject: jest.fn(),
    createDownloadUrl: jest.fn(),
  };

  let service: ChequeAttachmentsService;

  beforeEach(() => {
    jest.clearAllMocks();

    service = new ChequeAttachmentsService(
      prisma as never,
      auditLog as never,
      storage as never,
    );

    prisma.cheque.findFirst.mockResolvedValue({
      id: '11111111-1111-4111-8111-111111111111',
    });
  });

  it('prepares a deterministic attachment storage path', async () => {
    storage.createUploadUrl.mockResolvedValue({
      storageKey:
        'cheques/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.jpg',
      uploadUrl: 'https://example.test/upload',
      expiresInSeconds: 1800,
    });

    const result = await service.prepareUpload({
      id: '22222222-2222-4222-8222-222222222222',
      chequeId: '11111111-1111-4111-8111-111111111111',
      kind: 'STATEMENT',
      fileName: 'statement.jpg',
      mimeType: 'image/jpeg',
      originalFileSize: 500000,
      fileSize: 200000,
      sha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });

    expect(result.attachmentId).toBe('22222222-2222-4222-8222-222222222222');

    expect(storage.createUploadUrl).toHaveBeenCalledWith({
      chequeId: '11111111-1111-4111-8111-111111111111',
      attachmentId: '22222222-2222-4222-8222-222222222222',
      mimeType: 'image/jpeg',
    });
  });

  it('confirms an uploaded attachment and records CREATE audit', async () => {
    const attachmentId = '22222222-2222-4222-8222-222222222222';

    storage.verifyUploadedObject.mockResolvedValue(
      'cheques/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.jpg',
    );

    tx.chequeAttachment.findUnique.mockResolvedValue(null);

    tx.chequeAttachment.upsert.mockResolvedValue({
      id: attachmentId,
      chequeId: '11111111-1111-4111-8111-111111111111',
      kind: 'STATEMENT',
    });

    await service.confirmUpload({
      id: attachmentId,
      chequeId: '11111111-1111-4111-8111-111111111111',
      kind: 'STATEMENT',
      fileName: 'statement.jpg',
      mimeType: 'image/jpeg',
      originalFileSize: 500000,
      fileSize: 200000,
      sha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    });

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'CHEQUE_ATTACHMENT',
        entityId: attachmentId,
      }),
      tx,
    );
  });

  it('soft deletes an attachment and records DELETE audit', async () => {
    const attachmentId = '22222222-2222-4222-8222-222222222222';

    prisma.chequeAttachment.findFirst.mockResolvedValue({
      id: attachmentId,
      deletedAt: null,
    });

    tx.chequeAttachment.findUnique.mockResolvedValue({
      id: attachmentId,
      deletedAt: null,
    });

    tx.chequeAttachment.update.mockResolvedValue({
      id: attachmentId,
      deletedAt: new Date('2026-08-16T00:00:00.000Z'),
    });

    await service.remove(attachmentId);

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entityType: 'CHEQUE_ATTACHMENT',
        entityId: attachmentId,
      }),
      tx,
    );
  });
});
