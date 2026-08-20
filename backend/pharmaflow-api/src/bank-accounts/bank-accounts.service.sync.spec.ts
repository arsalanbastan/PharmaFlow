import { BadRequestException } from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { BankAccountsService } from './bank-accounts.service';

describe('BankAccountsService sync behavior', () => {
  let create: jest.Mock;
  let upsert: jest.Mock;
  let findUnique: jest.Mock;
  let findMany: jest.Mock;
  let auditRecord: jest.Mock;

  let prismaMock: {
    bankAccount: {
      create: jest.Mock;
      upsert: jest.Mock;
      findUnique: jest.Mock;
      findMany: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  let service: BankAccountsService;

  beforeEach(() => {
    create = jest.fn();
    upsert = jest.fn();
    findUnique = jest.fn().mockResolvedValue(null);
    findMany = jest.fn();

    auditRecord = jest.fn().mockResolvedValue({
      id: 'audit-id',
    });

    prismaMock = {
      bankAccount: {
        create,
        upsert,
        findUnique,
        findMany,
      },

      $transaction: jest.fn((callback: (tx: typeof prismaMock) => unknown) =>
        callback(prismaMock),
      ),
    };

    const auditLog = {
      record: auditRecord,
    } as unknown as AuditLogService;

    service = new BankAccountsService(
      prismaMock as unknown as PrismaService,
      auditLog,
    );
  });

  it('uses the client UUID for idempotent BankAccount CREATE', async () => {
    const id = '12345678-1234-4234-8234-123456789abc';

    upsert.mockResolvedValue({
      id,
      bankName: 'Test Bank',
    });

    await service.create({
      id,
      bankName: 'Test Bank',
      accountTitle: 'Main',
      shebaNumber: 'IR123',
      notes: 'note',
    });

    expect(create).not.toHaveBeenCalled();

    expect(findUnique).toHaveBeenCalledWith({
      where: {
        id,
      },
    });

    expect(upsert).toHaveBeenCalledWith({
      where: {
        id,
      },

      create: expect.objectContaining({
        id,
        bankName: 'Test Bank',
        accountTitle: 'Main',
        shebaNumber: 'IR123',
        notes: 'note',
      }),

      update: expect.objectContaining({
        bankName: 'Test Bank',
        accountTitle: 'Main',
        shebaNumber: 'IR123',
        notes: 'note',
      }),
    });

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'BANK_ACCOUNT',
        entityId: id,
      }),
      prismaMock,
    );
  });

  it('keeps backward-compatible server-generated CREATE when id is omitted', async () => {
    create.mockResolvedValue({
      id: 'server-generated',
      bankName: 'Legacy Bank',
    });

    await service.create({
      bankName: 'Legacy Bank',
    });

    expect(create).toHaveBeenCalledTimes(1);
    expect(upsert).not.toHaveBeenCalled();
    expect(findUnique).not.toHaveBeenCalled();

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'BANK_ACCOUNT',
        entityId: 'server-generated',
      }),
      prismaMock,
    );
  });

  it('returns changes ordered by updatedAt then id and includes tombstones', async () => {
    const updatedAt = new Date('2026-08-13T10:00:00.000Z');

    findMany.mockResolvedValue([
      {
        id: '11111111-1111-4111-8111-111111111111',
        bankName: 'A',
        updatedAt,
        deletedAt: null,
      },
      {
        id: '22222222-2222-4222-8222-222222222222',
        bankName: 'B',
        updatedAt: new Date('2026-08-13T11:00:00.000Z'),
        deletedAt: new Date('2026-08-13T11:00:00.000Z'),
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
