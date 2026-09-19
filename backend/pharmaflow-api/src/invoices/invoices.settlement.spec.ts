import { Prisma } from '@prisma/client';

import { InvoicesService } from './invoices.service';

describe('InvoicesService settlement', () => {
  it('creates cheque, cash and cash-discount allocations atomically', async () => {
    const invoiceA = '11111111-1111-4111-8111-111111111111';
    const invoiceB = '22222222-2222-4222-8222-222222222222';
    const companyId = '33333333-3333-4333-8333-333333333333';
    const chequeBank = '44444444-4444-4444-8444-444444444444';
    const cashBank = '55555555-5555-4555-8555-555555555555';
    const rows = [
      {
        id: invoiceA,
        invoiceNumber: 'A',
        invoiceDate: '1405/06/01',
        factorDocType: 1,
        factorPayablePrice: new Prisma.Decimal(200),
        isDeletedInArsen: false,
        company: { id: companyId, name: 'شرکت تست' },
        chequeAllocations: [],
        cashPaymentAllocations: [],
        discountAllocations: [],
      },
      {
        id: invoiceB,
        invoiceNumber: 'B',
        invoiceDate: '1405/06/02',
        factorDocType: 1,
        factorPayablePrice: new Prisma.Decimal(300),
        isDeletedInArsen: false,
        company: { id: companyId, name: 'شرکت تست' },
        chequeAllocations: [],
        cashPaymentAllocations: [],
        discountAllocations: [],
      },
    ];
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      arsenInvoice: { findMany: jest.fn().mockResolvedValue(rows) },
      bankAccount: { count: jest.fn().mockResolvedValue(2) },
      cheque: { create: jest.fn().mockResolvedValue({ id: 'cheque-1' }) },
      cashPayment: {
        create: jest.fn().mockResolvedValue({ id: 'cash-1' }),
      },
      chequeInvoiceAllocation: { createMany: jest.fn().mockResolvedValue({}) },
      cashPaymentInvoiceAllocation: {
        createMany: jest.fn().mockResolvedValue({}),
      },
      invoiceDiscountAllocation: {
        createMany: jest.fn().mockResolvedValue({}),
      },
      pushOutbox: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      $transaction: jest.fn((callback: (database: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue(undefined) };
    const service = new InvoicesService(prisma as never, auditLog as never);

    await expect(
      service.createSettlement({
        invoiceIds: [invoiceA, invoiceB],
        cheque: {
          amount: 250,
          bankAccountId: chequeBank,
          chequeNumber: '123',
          chequeDate: '2026-09-17T00:00:00.000Z',
          dueDate: '2026-10-17T00:00:00.000Z',
        },
        cash: {
          amount: 100,
          bankAccountId: cashBank,
          paymentDate: '2026-09-17T00:00:00.000Z',
          paymentMethod: 'BANK_DEPOSIT',
        },
        discountAmount: 50,
        discountDescription: 'تخفیف نقدی',
      }),
    ).resolves.toEqual(
      expect.objectContaining({
        chequeId: 'cheque-1',
        cashPaymentId: 'cash-1',
        settledAmount: '400',
        remainingAmount: '100',
      }),
    );

    expect(tx.chequeInvoiceAllocation.createMany).toHaveBeenCalledWith({
      data: [
        expect.objectContaining({
          invoiceId: invoiceA,
          amount: new Prisma.Decimal(200),
        }),
        expect.objectContaining({
          invoiceId: invoiceB,
          amount: new Prisma.Decimal(50),
        }),
      ],
    });
    expect(tx.cashPaymentInvoiceAllocation.createMany).toHaveBeenCalled();
    expect(tx.invoiceDiscountAllocation.createMany).toHaveBeenCalled();
    expect(auditLog.record).toHaveBeenCalled();
  });
});
