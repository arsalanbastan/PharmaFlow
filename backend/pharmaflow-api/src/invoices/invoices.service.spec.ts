import { BadRequestException, NotFoundException } from '@nestjs/common';

import { InvoicesService } from './invoices.service';

describe('InvoicesService', () => {
  const prisma = {
    arsenInvoice: {
      count: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
    bankAccount: { findMany: jest.fn() },
  };
  const auditLog = { record: jest.fn() };

  let service: InvoicesService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new InvoicesService(prisma as never, auditLog as never);
  });

  it('returns newest invoices with pagination metadata', async () => {
    prisma.arsenInvoice.count.mockResolvedValue(1);

    prisma.arsenInvoice.findMany.mockResolvedValue([
      {
        id: '11111111-1111-4111-8111-111111111111',
        arsenFactorId: 1200,
        invoiceNumber: 'INV-1200',
        invoiceDate: '1405/06/10',
        settlementDate: '1405/08/14',
        factorDocTypeName: 'خرید',
        factorPayablePrice: '12500000',
        paymentDays: 65,
        itemCount: 4,
        isDeletedInArsen: false,
        chequeAllocations: [{ amount: '2500000' }],
        cashPaymentAllocations: [{ amount: '1000000' }],
        discountAllocations: [{ amount: '500000' }],
        company: {
          id: '22222222-2222-4222-8222-222222222222',
          name: 'شرکت تست',
        },
      },
    ]);

    const result = await service.findAll({
      q: 'INV-1200',
      page: '1',
      pageSize: '50',
    });

    expect(result).toEqual({
      items: [
        expect.objectContaining({
          arsenFactorId: 1200,
          invoiceNumber: 'INV-1200',
          factorPayablePrice: '12500000',
          itemCount: 4,
          paidAmount: '3500000',
          discountAmount: '500000',
          settledAmount: '4000000',
          remainingAmount: '8500000',
          paymentStatus: 'PARTIAL',
          isPaid: false,
        }),
      ],
      page: 1,
      pageSize: 50,
      totalCount: 1,
      totalPages: 1,
    });

    expect(prisma.arsenInvoice.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        orderBy: {
          ingestSequence: 'desc',
        },
        skip: 0,
        take: 50,
      }),
    );
  });

  it('preserves original Arsen due date in settlement preview without writes', async () => {
    const id = '11111111-1111-4111-8111-111111111111';
    prisma.arsenInvoice.findMany.mockResolvedValue([
      {
        id,
        invoiceNumber: 'INV-1200',
        invoiceDate: '1405/06/10',
        settlementDate: '1405/08/14',
        paymentDays: 65,
        factorDocType: 1,
        factorPayablePrice: '12500000',
        isDeletedInArsen: false,
        company: {
          id: '22222222-2222-4222-8222-222222222222',
          name: 'شرکت تست',
        },
        chequeAllocations: [],
        cashPaymentAllocations: [],
        discountAllocations: [],
      },
    ]);
    prisma.bankAccount.findMany.mockResolvedValue([]);
    const preview = await service.prepareSettlement(id);
    expect(preview.invoices[0]).toEqual(
      expect.objectContaining({
        settlementDate: '1405/08/14',
        paymentDays: 65,
        remainingAmount: '12500000',
      }),
    );
    expect(prisma.arsenInvoice.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({
          settlementDate: true,
          paymentDays: true,
        }),
      }),
    );
  });

  it('serializes BigInt item identifiers for JSON details', async () => {
    prisma.arsenInvoice.findUnique.mockResolvedValue({
      id: '11111111-1111-4111-8111-111111111111',
      arsenFactorId: 1200,
      invoiceNumber: 'INV-1200',
      invoiceDate: '1405/06/10',
      docDate: null,
      settlementDate: null,
      description: null,
      factorDocType: 1,
      factorDocTypeName: 'خرید',
      factorType: null,
      factorTypeName: null,
      factorItemType: null,
      arsenBusinessPartnerId: 10,
      arsenBusinessPartnerName: 'شرکت تست',
      factorTotalPrice: '100',
      factorDiscount: '5',
      factorTax: '9',
      factorPayablePrice: '104',
      barbariPrice: null,
      paymentDays: 65,
      itemCount: 1,
      isDeletedInArsen: false,
      isLockedInArsen: false,
      chequeAllocations: [{ amount: '60' }],
      cashPaymentAllocations: [{ amount: '44' }],
      discountAllocations: [],
      company: {
        id: '22222222-2222-4222-8222-222222222222',
        name: 'شرکت تست',
      },
      items: [
        {
          id: '33333333-3333-4333-8333-333333333333',
          arsenFactorDetailId: 9007199254740993n,
          arsenFactorDetailsId: 1,
          arsenDrugId: 123456789012345n,
          drugName: 'داروی تست',
          barcode: '123',
          packetQuantity: 10,
          quantity: 2,
          salePrice: '150',
          purchasePrice: '100',
          rowDiscount: '2',
          hasTax: 1,
          expireDate: '1406/12/29',
          batchNumber: 'B-1',
        },
      ],
    });

    const result = await service.findOne(
      '11111111-1111-4111-8111-111111111111',
    );

    expect(result.items[0]).toEqual(
      expect.objectContaining({
        arsenFactorDetailId: '9007199254740993',
        arsenDrugId: '123456789012345',
        drugName: 'داروی تست',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        paidAmount: '104',
        remainingAmount: '0',
        paymentStatus: 'PAID',
        isPaid: true,
      }),
    );
  });

  it('rejects direct payment toggles because status comes from allocations', async () => {
    const invoiceId = '11111111-1111-4111-8111-111111111111';

    prisma.arsenInvoice.findUnique.mockResolvedValue({
      id: invoiceId,
    });

    await expect(
      service.updatePaymentStatus(invoiceId, true),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects malformed invoice identifiers before querying Prisma', async () => {
    await expect(service.findOne('invalid')).rejects.toBeInstanceOf(
      BadRequestException,
    );

    expect(prisma.arsenInvoice.findUnique).not.toHaveBeenCalled();
  });

  it('returns 404 for a missing invoice', async () => {
    prisma.arsenInvoice.findUnique.mockResolvedValue(null);

    await expect(
      service.findOne('11111111-1111-4111-8111-111111111111'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
