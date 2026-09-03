import { BadRequestException } from '@nestjs/common';

import { AdminService } from './admin.service';

describe('AdminService invoice pagination', () => {
  const invoiceCount = jest.fn();
  const invoiceFindMany = jest.fn();
  const companyFindMany = jest.fn();

  const prisma = {
    arsenInvoice: {
      count: invoiceCount,
      findMany: invoiceFindMany,
    },
    company: {
      findMany: companyFindMany,
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    invoiceFindMany.mockResolvedValue([]);
    companyFindMany.mockResolvedValue([]);
  });

  it('uses page/pageSize and returns the filtered total page count', async () => {
    invoiceCount.mockResolvedValue(8670);
    const service = new AdminService(prisma as never, {} as never);

    const result = await service.invoices({
      page: '3',
      pageSize: '100',
    });

    expect(invoiceCount).toHaveBeenCalledWith({ where: {} });
    expect(invoiceFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {},
        orderBy: { ingestSequence: 'desc' },
        skip: 200,
        take: 100,
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        page: 3,
        pageSize: 100,
        totalCount: 8670,
        totalPages: 87,
      }),
    );
  });

  it('clamps an out-of-range page to the last available page', async () => {
    invoiceCount.mockResolvedValue(120);
    const service = new AdminService(prisma as never, {} as never);

    const result = await service.invoices({
      page: '999',
      pageSize: '50',
    });

    expect(invoiceFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        skip: 100,
        take: 50,
      }),
    );
    expect(result.page).toBe(3);
    expect(result.totalPages).toBe(3);
  });

  it('rejects unsupported invoice page sizes before querying the database', async () => {
    const service = new AdminService(prisma as never, {} as never);

    await expect(
      service.invoices({
        page: '1',
        pageSize: '75',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(invoiceCount).not.toHaveBeenCalled();
    expect(invoiceFindMany).not.toHaveBeenCalled();
  });
});
