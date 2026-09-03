import { BadRequestException, NotFoundException } from '@nestjs/common';

import { InvoicesService } from './invoices.service';

describe('InvoicesService', () => {
  const prisma = {
    arsenInvoice: {
      count: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
  };

  let service: InvoicesService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new InvoicesService(prisma as never);
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
  });

  it('updates PharmaFlow payment state without touching Arsen source fields', async () => {
    const invoiceId = '11111111-1111-4111-8111-111111111111';

    prisma.arsenInvoice.findUnique.mockResolvedValue({
      id: invoiceId,
    });

    prisma.arsenInvoice.update.mockResolvedValue({
      id: invoiceId,
      isPaidInPharmaFlow: true,
    });

    await expect(
      service.updatePaymentStatus(invoiceId, true),
    ).resolves.toEqual({
      id: invoiceId,
      isPaid: true,
    });

    expect(prisma.arsenInvoice.update).toHaveBeenCalledWith({
      where: {
        id: invoiceId,
      },
      data: {
        isPaidInPharmaFlow: true,
      },
      select: {
        id: true,
        isPaidInPharmaFlow: true,
      },
    });
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