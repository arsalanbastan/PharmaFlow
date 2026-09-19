import { Prisma } from '@prisma/client';

import { SalesInvoicesService } from './sales-invoices.service';

describe('SalesInvoicesService', () => {
  it('uses catalog snapshots and calculates invoice totals on the server', async () => {
    const catalogId = '11111111-1111-4111-8111-111111111111';
    const profile = {
      id: 'default',
      sellerName: 'داروخانه دکتر خسروانی',
      legalName: null,
      nationalId: null,
      economicCode: null,
      phone: '07700000000',
      address: 'کنگان',
      logoData: null,
    };
    const created = {
      id: '22222222-2222-4222-8222-222222222222',
      sequence: 12n,
      invoiceNumber: null,
      issueDate: new Date('2026-09-17T00:00:00.000Z'),
      buyerName: 'خریدار تست',
      buyerNationalId: null,
      buyerPhone: null,
      buyerAddress: null,
      sellerName: profile.sellerName,
      sellerLegalName: null,
      sellerNationalId: null,
      sellerEconomicCode: null,
      sellerPhone: profile.phone,
      sellerAddress: profile.address,
      sellerLogoData: null,
      subtotal: new Prisma.Decimal(190),
      discount: new Prisma.Decimal(20),
      payableAmount: new Prisma.Decimal(170),
      notes: null,
      status: 'ISSUED',
      createdAt: new Date(),
      updatedAt: new Date(),
      items: [
        {
          id: 'item-1',
          catalogItemId: catalogId,
          arsenDrugId: 10n,
          itemName: 'داروی تست',
          barcode: null,
          unit: 'عدد',
          quantity: new Prisma.Decimal(2),
          unitPrice: new Prisma.Decimal(100),
          lineDiscount: new Prisma.Decimal(10),
          lineTotal: new Prisma.Decimal(190),
        },
      ],
    };
    const updated = { ...created, invoiceNumber: 'PF-00000012' };
    const tx = {
      salesInvoice: {
        create: jest.fn().mockResolvedValue(created),
        update: jest.fn().mockResolvedValue(updated),
      },
    };
    const prisma = {
      salesInvoiceProfile: { upsert: jest.fn().mockResolvedValue(profile) },
      arsenCatalogItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: catalogId,
            arsenDrugId: 10n,
            persianName: 'داروی تست',
            genericName: null,
            persianBrandName: null,
            unit: 'عدد',
          },
        ]),
      },
      $transaction: jest.fn((callback: (database: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue(undefined) };
    const service = new SalesInvoicesService(
      prisma as never,
      auditLog as never,
    );

    const result = await service.create({
      issueDate: '2026-09-17T00:00:00.000Z',
      buyerName: 'خریدار تست',
      discount: 20,
      items: [
        {
          catalogItemId: catalogId,
          quantity: 2,
          unitPrice: 100,
          lineDiscount: 10,
        },
      ],
    });

    expect(tx.salesInvoice.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          subtotal: new Prisma.Decimal(190),
          discount: new Prisma.Decimal(20),
          payableAmount: new Prisma.Decimal(170),
        }),
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        invoiceNumber: 'PF-00000012',
        payableAmount: '170',
      }),
    );
  });
});
