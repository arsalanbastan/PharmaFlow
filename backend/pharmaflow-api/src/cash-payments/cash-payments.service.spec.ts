import { CashPaymentsService } from './cash-payments.service';

describe('CashPaymentsService', () => {
  const tx = {
    cashPayment: {
      create: jest.fn(),
      findUnique: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
    },
    pushOutbox: {
      create: jest.fn(),
    },
  };

  const prisma = {
    cashPayment: {
      findMany: jest.fn(),
      findFirst: jest.fn(),
    },
    $transaction: jest.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  };

  const auditLog = {
    record: jest.fn(),
  };

  let service: CashPaymentsService;

  beforeEach(() => {
    jest.clearAllMocks();

    service = new CashPaymentsService(prisma as never, auditLog as never);
  });

  it('creates an offline-first payment idempotently using the client UUID', async () => {
    const id = '11111111-1111-4111-8111-111111111111';

    tx.cashPayment.findUnique.mockResolvedValue(null);

    const result = {
      id,
      amount: 250000000,
      paymentMethod: 'BANK_DEPOSIT',
    };

    tx.cashPayment.upsert.mockResolvedValue(result);

    await expect(
      service.create({
        id,
        amount: 250000000,
        paymentDate: '2026-08-16T00:00:00.000Z',
        companyId: '22222222-2222-4222-8222-222222222222',
        bankAccountId: '33333333-3333-4333-8333-333333333333',
        paymentMethod: 'BANK_DEPOSIT',
        trackingNumber: '987654',
        description: 'تسویه صورتحساب',
      }),
    ).resolves.toEqual(result);

    expect(tx.cashPayment.upsert).toHaveBeenCalled();

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'CASH_PAYMENT',
        entityId: id,
      }),
      tx,
    );
  });

  it('updates payment method and records an audit UPDATE', async () => {
    const id = '11111111-1111-4111-8111-111111111111';

    const existing = {
      id,
      paymentMethod: 'BANK_DEPOSIT',
      deletedAt: null,
    };

    prisma.cashPayment.findFirst.mockResolvedValue(existing);

    tx.cashPayment.findUnique.mockResolvedValue(existing);

    const updated = {
      ...existing,
      paymentMethod: 'POS_PAYMENT',
    };

    tx.cashPayment.update.mockResolvedValue(updated);

    await service.update(id, {
      paymentMethod: 'POS_PAYMENT',
    });

    expect(tx.cashPayment.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id,
        },
        data: expect.objectContaining({
          paymentMethod: 'POS_PAYMENT',
        }),
      }),
    );

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entityType: 'CASH_PAYMENT',
        entityId: id,
      }),
      tx,
    );
  });

  it('soft deletes a payment and records an audit DELETE', async () => {
    const id = '11111111-1111-4111-8111-111111111111';

    const existing = {
      id,
      deletedAt: null,
    };

    prisma.cashPayment.findFirst.mockResolvedValue(existing);

    tx.cashPayment.findUnique.mockResolvedValue(existing);

    tx.cashPayment.update.mockResolvedValue({
      id,
      deletedAt: new Date(),
    });

    await service.remove(id);

    expect(tx.cashPayment.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id,
        },
        data: expect.objectContaining({
          deletedAt: expect.any(Date),
        }),
      }),
    );

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entityType: 'CASH_PAYMENT',
        entityId: id,
      }),
      tx,
    );
  });
});
