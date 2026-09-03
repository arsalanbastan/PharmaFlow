import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { AdminService } from './admin.service';

describe('AdminService Excel/PDF export queries', () => {
  const auditLog = { record: jest.fn() } as unknown as AuditLogService;

  it('exports all catalog rows matching the active filters without pagination', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      arsenCatalogItem: { findMany },
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    await service.catalogExport({
      category: 'DRUG',
      active: 'ACTIVE',
      sort: 'ARSEN_ID_ASC',
    });

    const query = findMany.mock.calls[0][0];
    expect(query.where).toEqual({
      AND: [{ category: 'DRUG' }, { isActive: true }],
    });
    expect(query.orderBy).toEqual([{ arsenDrugId: 'asc' }]);
    expect(query.take).toBeUndefined();
    expect(query.skip).toBeUndefined();
  });

  it('exports all invoices matching the list filters without pagination', async () => {
    const findMany = jest.fn().mockResolvedValue([]);
    const prisma = {
      arsenInvoice: { findMany },
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);
    const companyId = '11111111-1111-4111-8111-111111111111';

    await service.invoicesExport({
      invoiceNumber: '62',
      companyId,
      docType: '1',
      dateFrom: '1405/01/01',
      dateTo: '1405/12/29',
    });

    const query = findMany.mock.calls[0][0];
    expect(query.where).toEqual({
      invoiceNumber: { contains: '62' },
      companyId,
      factorDocType: 1,
      invoiceDate: { gte: '1405/01/01', lte: '1405/12/29' },
    });
    expect(query.take).toBeUndefined();
    expect(query.skip).toBeUndefined();
  });

  it('uses the same company search semantics for the Excel result set', async () => {
    const findMany = jest.fn().mockResolvedValue([
      { name: 'رازی', nationalId: null },
      { name: 'داروپخش', nationalId: null },
    ]);
    const prisma = {
      company: { findMany },
    } as unknown as PrismaService;
    const service = new AdminService(prisma, auditLog);

    const result = await service.companies('رازی');

    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('رازی');
  });
});
