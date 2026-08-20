import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CompaniesService } from './companies.service';
import { CreateCompanyDto } from './dto/create-company.dto';

describe('CompaniesService CREATE idempotency', () => {
  let companyCreate: jest.Mock;
  let companyFindUnique: jest.Mock;
  let companyUpsert: jest.Mock;
  let auditRecord: jest.Mock;

  let prismaMock: {
    company: {
      create: jest.Mock;
      findUnique: jest.Mock;
      upsert: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  let service: CompaniesService;

  beforeEach(() => {
    companyCreate = jest.fn();
    companyFindUnique = jest.fn().mockResolvedValue(null);
    companyUpsert = jest.fn();

    auditRecord = jest.fn().mockResolvedValue({
      id: 'audit-id',
    });

    prismaMock = {
      company: {
        create: companyCreate,
        findUnique: companyFindUnique,
        upsert: companyUpsert,
      },

      $transaction: jest.fn((callback: (tx: typeof prismaMock) => unknown) =>
        callback(prismaMock),
      ),
    };

    const auditLog = {
      record: auditRecord,
    } as unknown as AuditLogService;

    service = new CompaniesService(
      prismaMock as unknown as PrismaService,
      auditLog,
    );
  });

  it('keeps backward compatibility when client id is omitted', async () => {
    companyCreate.mockResolvedValue({
      id: 'server-generated-id',
      name: 'Legacy Client',
    });

    const dto: CreateCompanyDto = {
      name: 'Legacy Client',
    };

    const result = await service.create(dto);

    expect(result).toEqual(
      expect.objectContaining({
        id: 'server-generated-id',
        name: 'Legacy Client',
      }),
    );

    expect(prismaMock.$transaction).toHaveBeenCalledTimes(1);

    expect(companyCreate).toHaveBeenCalledTimes(1);

    expect(companyFindUnique).not.toHaveBeenCalled();

    expect(companyUpsert).not.toHaveBeenCalled();

    expect(companyCreate).toHaveBeenCalledWith({
      data: expect.objectContaining({
        name: 'Legacy Client',
      }),
    });

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'COMPANY',
        entityId: 'server-generated-id',
        after: expect.objectContaining({
          id: 'server-generated-id',
          name: 'Legacy Client',
        }),
      }),
      prismaMock,
    );
  });

  it('uses client UUID as the authoritative Company id', async () => {
    const id = '12345678-1234-4234-8234-123456789abc';

    companyUpsert.mockResolvedValue({
      id,
      name: 'Offline Company',
    });

    const dto: CreateCompanyDto = {
      id,
      name: 'Offline Company',
      nationalId: null,
      archivedAt: null,
    };

    await service.create(dto);

    expect(companyCreate).not.toHaveBeenCalled();

    expect(companyFindUnique).toHaveBeenCalledWith({
      where: {
        id,
      },
    });

    expect(companyUpsert).toHaveBeenCalledTimes(1);

    expect(companyUpsert).toHaveBeenCalledWith({
      where: {
        id,
      },

      create: expect.objectContaining({
        id,
        name: 'Offline Company',
        nationalId: null,
        archivedAt: null,
      }),

      update: expect.objectContaining({
        name: 'Offline Company',
        nationalId: null,
        archivedAt: null,
      }),
    });

    expect(auditRecord).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'COMPANY',
        entityId: id,
      }),
      prismaMock,
    );
  });

  it('retries the same UUID and applies the latest snapshot through upsert', async () => {
    const id = '22345678-1234-4234-8234-123456789abc';

    companyUpsert
      .mockResolvedValueOnce({
        id,
        name: 'First Snapshot',
      })
      .mockResolvedValueOnce({
        id,
        name: 'Latest Snapshot',
        notes: 'edited while offline',
      });

    companyFindUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({
      id,
      name: 'First Snapshot',
      notes: null,
    });

    await service.create({
      id,
      name: 'First Snapshot',
      notes: null,
      archivedAt: null,
    });

    await service.create({
      id,
      name: 'Latest Snapshot',
      notes: 'edited while offline',
      archivedAt: '2026-08-13T08:00:00.000Z',
    });

    expect(companyUpsert).toHaveBeenCalledTimes(2);

    const firstCall = companyUpsert.mock.calls[0][0];

    const secondCall = companyUpsert.mock.calls[1][0];

    expect(firstCall.where.id).toBe(id);
    expect(secondCall.where.id).toBe(id);

    expect(secondCall.create).toEqual(
      expect.objectContaining({
        id,
        name: 'Latest Snapshot',
        notes: 'edited while offline',
        archivedAt: '2026-08-13T08:00:00.000Z',
      }),
    );

    expect(secondCall.update).toEqual(
      expect.objectContaining({
        name: 'Latest Snapshot',
        notes: 'edited while offline',
        archivedAt: '2026-08-13T08:00:00.000Z',
      }),
    );

    expect(auditRecord).toHaveBeenCalledTimes(2);

    expect(auditRecord.mock.calls[0][0]).toEqual(
      expect.objectContaining({
        action: 'CREATE',
        entityType: 'COMPANY',
        entityId: id,
      }),
    );

    expect(auditRecord.mock.calls[1][0]).toEqual(
      expect.objectContaining({
        action: 'UPDATE',
        entityType: 'COMPANY',
        entityId: id,

        before: expect.objectContaining({
          id,
          name: 'First Snapshot',
        }),

        after: expect.objectContaining({
          id,
          name: 'Latest Snapshot',
        }),
      }),
    );
  });
});
