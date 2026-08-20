import { BadRequestException } from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { ChequesService } from './cheques.service';

describe('ChequesService sync behavior', () => {
  let create: jest.Mock;
  let upsert: jest.Mock;
  let findUnique: jest.Mock;
  let findMany: jest.Mock;
  let auditRecord: jest.Mock;

  let prismaMock: {
    cheque: {
      create: jest.Mock;
      upsert: jest.Mock;
      findUnique: jest.Mock;
      findMany: jest.Mock;
    };
    pushOutbox: {
      create: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  let service: ChequesService;

  beforeEach(() => {
    create = jest.fn();
    upsert = jest.fn();

    findUnique = jest.fn().mockResolvedValue(null);

    findMany = jest.fn();

    auditRecord = jest.fn().mockResolvedValue({
      id: 'audit-id',
    });

    prismaMock = {
      cheque: {
        create,
        upsert,
        findUnique,
        findMany,
      },
      pushOutbox: {
        create: jest.fn(),
      },

      $transaction: jest.fn((callback: (tx: typeof prismaMock) => unknown) =>
        callback(prismaMock),
      ),
    };

    const auditLog = {
      record: auditRecord,
    } as unknown as AuditLogService;

    service = new ChequesService(
      prismaMock as unknown as PrismaService,
      auditLog,
    );
  });

  it('uses the client UUID for idempotent Cheque CREATE', async () => {
    const id = '12345678-1234-4234-8234-123456789abc';

    const companyId = '22345678-1234-4234-8234-123456789abc';

    const bankAccountId = '32345678-1234-4234-8234-123456789abc';

    findMany.mockResolvedValue([]);

    upsert.mockResolvedValue({
      id,
      chequeNumber: '1001',
    });

    await service.create({
      id,
      chequeNumber: '1001',
      amount: 500000,
      chequeDate: '2026-08-13T10:00:00.000Z',
      dueDate: '2026-08-20T10:00:00.000Z',
      companyId,
      bankAccountId,
      status: 'Issued',
      isRegisteredInSayad: false,
      sayadId: undefined,
      description: 'offline cheque',
      archivedAt: undefined,
    });

    expect(create).not.toHaveBeenCalled();

    expect(findUnique).toHaveBeenCalledWith({
      where: {
        id,
      },
    });

    expect(upsert).toHaveBeenCalledTimes(1);

    expect(upsert).toHaveBeenCalledWith({
      where: {
        id,
      },

      create: expect.objectContaining({
        id,
        chequeNumber: '1001',
        amount: 500000,
        companyId,
        bankAccountId,
        status: 'Issued',
      }),

      update: expect.objectContaining({
        chequeNumber: '1001',
        amount: 500000,
        companyId,
        bankAccountId,
        status: 'Issued',
      }),
    });

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'CHEQUE',
        entityId: id,
      }),
      prismaMock,
    );
  });

  it('keeps backward-compatible server-generated CREATE when id is omitted', async () => {
    const companyId = '22345678-1234-4234-8234-123456789abc';

    const bankAccountId = '32345678-1234-4234-8234-123456789abc';

    findMany.mockResolvedValue([]);

    create.mockResolvedValue({
      id: 'server-generated',
      chequeNumber: '1002',
    });

    await service.create({
      chequeNumber: '1002',
      amount: 250000,
      chequeDate: '2026-08-13T10:00:00.000Z',
      dueDate: '2026-08-21T10:00:00.000Z',
      companyId,
      bankAccountId,
    });

    expect(create).toHaveBeenCalledTimes(1);

    expect(upsert).not.toHaveBeenCalled();

    expect(findUnique).not.toHaveBeenCalled();

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'CHEQUE',
        entityId: 'server-generated',
      }),
      prismaMock,
    );
  });

  it('classifies an idempotent retry as UPDATE when the UUID already exists', async () => {
    const id = '42345678-1234-4234-8234-123456789abc';

    const companyId = '52345678-1234-4234-8234-123456789abc';

    const bankAccountId = '62345678-1234-4234-8234-123456789abc';

    findMany.mockResolvedValue([]);

    findUnique.mockResolvedValue({
      id,
      chequeNumber: '2001',
      amount: 100000,
    });

    upsert.mockResolvedValue({
      id,
      chequeNumber: '2001',
      amount: 150000,
    });

    await service.create({
      id,
      chequeNumber: '2001',
      amount: 150000,
      chequeDate: '2026-08-13T10:00:00.000Z',
      companyId,
      bankAccountId,
    });

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entityType: 'CHEQUE',
        entityId: id,

        before: expect.objectContaining({
          id,
          amount: 100000,
        }),

        after: expect.objectContaining({
          id,
          amount: 150000,
        }),
      }),
      prismaMock,
    );
  });

  it('returns changes ordered by updatedAt then id and includes tombstones', async () => {
    const firstUpdatedAt = new Date('2026-08-13T10:00:00.000Z');

    const secondUpdatedAt = new Date('2026-08-13T11:00:00.000Z');

    findMany.mockResolvedValue([
      {
        id: '11111111-1111-4111-8111-111111111111',
        chequeNumber: '1001',
        updatedAt: firstUpdatedAt,
        deletedAt: null,
      },
      {
        id: '22222222-2222-4222-8222-222222222222',
        chequeNumber: '1002',
        updatedAt: secondUpdatedAt,
        deletedAt: secondUpdatedAt,
      },
    ]);

    const result = await service.findChanges({
      limit: '200',
    });

    expect(findMany).toHaveBeenCalledWith({
      where: undefined,
      orderBy: [
        {
          updatedAt: 'asc',
        },
        {
          id: 'asc',
        },
      ],
      take: 201,
    });

    expect(result.items).toHaveLength(2);

    expect(result.items[1].deletedAt).not.toBeNull();

    expect(result.hasMore).toBe(false);

    expect(result.nextCursor).toEqual({
      updatedAt: '2026-08-13T11:00:00.000Z',
      id: '22222222-2222-4222-8222-222222222222',
    });
  });

  it('rejects a half-specified changes cursor', async () => {
    await expect(
      service.findChanges({
        updatedAfter: '2026-08-13T10:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(findMany).not.toHaveBeenCalled();
  });
});
