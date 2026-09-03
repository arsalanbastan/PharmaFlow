import { ConflictException } from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { AdminService } from './admin.service';

describe('AdminService full dashboard safety', () => {
  const auditLog = {
    record: jest.fn(),
  } as unknown as AuditLogService;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns counts for all dashboard domains including the Arsen catalog', async () => {
    const count = jest
      .fn()
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(3)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(5)
      .mockResolvedValueOnce(6)
      .mockResolvedValueOnce(7)
      .mockResolvedValueOnce(8)
      .mockResolvedValueOnce(9)
      .mockResolvedValueOnce(10);
    const prisma = {
      company: { count },
      bankAccount: { count },
      cheque: { count },
      cashPayment: { count },
      appUser: { count },
      orderRequest: { count },
      auditLog: { count },
      arsenCatalogItem: { count },
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await expect(service.dashboard()).resolves.toEqual({
      companies: 2,
      bankAccounts: 3,
      cheques: 4,
      cashPayments: 5,
      users: 6,
      orders: 7,
      pendingOrders: 8,
      auditLogs: 9,
      catalogItems: 10,
    });
  });

  it('blocks company hard-delete while financial dependencies exist', async () => {
    const tx = {
      company: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'company-id',
          _count: { cheques: 1, cashPayments: 2, arsenCompanyMappings: 0 },
        }),
        delete: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await expect(service.hardDeleteCompany('company-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(tx.company.delete).not.toHaveBeenCalled();
  });

  it('blocks company hard-delete while an Arsen mapping exists', async () => {
    const tx = {
      company: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'company-id',
          _count: {
            cheques: 0,
            cashPayments: 0,
            arsenCompanyMappings: 1,
          },
        }),
        delete: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await expect(service.hardDeleteCompany('company-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(tx.company.delete).not.toHaveBeenCalled();
  });

  it('hard-deletes a cheque and related push event in one transaction', async () => {
    const tx = {
      cheque: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'cheque-id',
          attachments: [{ id: 'attachment-id' }],
        }),
        delete: jest.fn().mockResolvedValue({ id: 'cheque-id' }),
      },
      pushOutbox: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await service.hardDeleteCheque('cheque-id');

    expect(tx.pushOutbox.deleteMany).toHaveBeenCalledWith({
      where: { aggregateId: 'cheque-id' },
    });
    expect(tx.cheque.delete).toHaveBeenCalledWith({
      where: { id: 'cheque-id' },
    });
    expect(auditLog.record).toHaveBeenCalled();
  });

  it('never hard-deletes the final active manager', async () => {
    const tx = {
      appUser: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'manager-id',
          role: 'MANAGER',
          isActive: true,
          _count: { sessions: 1, pushDevices: 1 },
        }),
        count: jest.fn().mockResolvedValue(1),
        delete: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await expect(service.hardDeleteUser('manager-id')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(tx.appUser.delete).not.toHaveBeenCalled();
  });

  it('normalizes order text during a full admin edit', async () => {
    const tx = {
      orderRequest: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'order-id',
          orderedAt: null,
          receivedAt: null,
          canceledAt: null,
          deletedAt: null,
        }),
        update: jest.fn().mockImplementation(({ data }) => ({
          id: 'order-id',
          ...data,
        })),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback) => callback(tx)),
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await service.updateOrder('order-id', {
      category: 'DRUG',
      itemText: '  Ø¢Ø³Ù¾Ø±ÛŒÙ†  ',
      status: 'PENDING',
      requestedByName: 'Ú©Ø§Ø±Ø¨Ø± ØªØ³Øª',
    });

    expect(tx.orderRequest.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          itemText: 'Ø¢Ø³Ù¾Ø±ÛŒÙ†',
          normalizedItemText: expect.any(String),
          status: 'PENDING',
        }),
      }),
    );
  });
});
