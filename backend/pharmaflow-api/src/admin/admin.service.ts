import type { Prisma } from '@prisma/client';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { hashPassword } from '../auth/auth-password';
import { PrismaService } from '../database/prisma/prisma.service';
import { normalizeOrderSearchText } from '../orders/order-similarity';

type FormBody = Record<string, string | undefined>;

type InvoiceListFilters = {
  invoiceNumber?: string;
  companyId?: string;
  docType?: string;
  dateFrom?: string;
  dateTo?: string;
  page?: string;
  pageSize?: string;
};

type CatalogListFilters = {
  q?: string;
  category?: string;
  active?: string;
  shape?: string;
  sort?: string;
  page?: string;
  pageSize?: string;
};

const CATALOG_CATEGORIES = ['DRUG', 'GOODS'] as const;
const CATALOG_ACTIVE_FILTERS = ['ACTIVE', 'INACTIVE'] as const;
const CATALOG_SORTS = [
  'SYNC_DESC',
  'SYNC_ASC',
  'NAME_ASC',
  'NAME_DESC',
  'ARSEN_ID_ASC',
  'ARSEN_ID_DESC',
  'SALES_ASC',
  'SALES_DESC',
  'PURCHASE_ASC',
  'PURCHASE_DESC',
] as const;

const DEFAULT_INVOICE_PAGE_SIZE = 50;
const INVOICE_PAGE_SIZES = [25, 50, 100, 200] as const;
const DEFAULT_CATALOG_PAGE_SIZE = 50;
const CATALOG_PAGE_SIZES = [25, 50, 100, 200] as const;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const JALALI_DATE_PATTERN = /^\d{4}\/\d{2}\/\d{2}$/;

const ORDER_STATUSES = [
  'PENDING',
  'ORDERED',
  'RECEIVED',
  'CANCELED',
  'DELETED',
] as const;

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async dashboard() {
    const [
      companies,
      bankAccounts,
      cheques,
      cashPayments,
      users,
      orders,
      pendingOrders,
      auditLogs,
      catalogItems,
    ] = await Promise.all([
      this.prisma.company.count({ where: { deletedAt: null } }),
      this.prisma.bankAccount.count({ where: { deletedAt: null } }),
      this.prisma.cheque.count({ where: { deletedAt: null } }),
      this.prisma.cashPayment.count({ where: { deletedAt: null } }),
      this.prisma.appUser.count(),
      this.prisma.orderRequest.count(),
      this.prisma.orderRequest.count({ where: { status: 'PENDING' } }),
      this.prisma.auditLog.count(),
      this.prisma.arsenCatalogItem.count(),
    ]);

    return {
      companies,
      bankAccounts,
      cheques,
      cashPayments,
      users,
      orders,
      pendingOrders,
      auditLogs,
      catalogItems,
    };
  }

  async catalog(filters: CatalogListFilters = {}) {
    const { where, orderBy, sort } = this.catalogQuery(filters);
    const requestedPage =
      this.positiveInteger(filters.page, 'catalog page') ?? 1;
    const pageSize = this.catalogPageSize(filters.pageSize);

    const [
      totalCount,
      totalItems,
      drugCount,
      goodsCount,
      activeCount,
      inactiveCount,
      shapeRows,
    ] = await Promise.all([
      this.prisma.arsenCatalogItem.count({ where }),
      this.prisma.arsenCatalogItem.count(),
      this.prisma.arsenCatalogItem.count({ where: { category: 'DRUG' } }),
      this.prisma.arsenCatalogItem.count({ where: { category: 'GOODS' } }),
      this.prisma.arsenCatalogItem.count({ where: { isActive: true } }),
      this.prisma.arsenCatalogItem.count({ where: { isActive: false } }),
      this.prisma.arsenCatalogItem.groupBy({
        by: ['shapeName'],
        where: { shapeName: { not: null } },
        orderBy: { shapeName: 'asc' },
      }),
    ]);

    const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
    const page = Math.min(requestedPage, totalPages);
    const skip = (page - 1) * pageSize;

    const items = await this.prisma.arsenCatalogItem.findMany({
      where,
      select: {
        id: true,
        ingestSequence: true,
        arsenDrugId: true,
        category: true,
        persianName: true,
        genericName: true,
        persianBrandName: true,
        brandName: true,
        unit: true,
        shapeName: true,
        packetQuantity: true,
        salesPrice: true,
        lastPurchasePrice: true,
        isActive: true,
        description: true,
        importedAt: true,
        sourceSyncedAt: true,
      },
      orderBy,
      skip,
      take: pageSize,
    });

    return {
      items,
      shapes: shapeRows
        .map((row) => row.shapeName)
        .filter((value): value is string => Boolean(value)),
      stats: {
        totalItems,
        drugCount,
        goodsCount,
        activeCount,
        inactiveCount,
      },
      page,
      pageSize,
      totalCount,
      totalPages,
      sort,
    };
  }

  async catalogExport(filters: CatalogListFilters = {}) {
    const { where, orderBy } = this.catalogQuery(filters);

    return this.prisma.arsenCatalogItem.findMany({
      where,
      select: {
        arsenDrugId: true,
        category: true,
        persianName: true,
        genericName: true,
        persianBrandName: true,
        brandName: true,
        unit: true,
        shapeName: true,
        packetQuantity: true,
        salesPrice: true,
        lastPurchasePrice: true,
        isActive: true,
        description: true,
        importedAt: true,
        sourceSyncedAt: true,
      },
      orderBy,
    });
  }

  async catalogItem(id: string) {
    const item = await this.prisma.arsenCatalogItem.findUnique({
      where: { id },
    });

    if (item == null) {
      throw new NotFoundException('Catalog item not found.');
    }

    return item;
  }

  async invoices(filters: InvoiceListFilters = {}) {
    const where = this.invoiceWhere(filters);
    const requestedPage =
      this.positiveInteger(filters.page, 'invoice page') ?? 1;
    const pageSize = this.invoicePageSize(filters.pageSize);

    const [totalCount, companies] = await Promise.all([
      this.prisma.arsenInvoice.count({ where }),
      this.prisma.company.findMany({
        where: { deletedAt: null },
        select: { id: true, name: true },
        orderBy: { name: 'asc' },
      }),
    ]);

    const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
    const page = Math.min(requestedPage, totalPages);
    const skip = (page - 1) * pageSize;

    const items = await this.prisma.arsenInvoice.findMany({
      where,
      select: {
        id: true,
        ingestSequence: true,
        arsenFactorId: true,
        invoiceNumber: true,
        invoiceDate: true,
        settlementDate: true,
        factorDocType: true,
        factorDocTypeName: true,
        factorPayablePrice: true,
        paymentDays: true,
        itemCount: true,
        isDeletedInArsen: true,
        importedAt: true,
        company: { select: { id: true, name: true } },
      },
      orderBy: { ingestSequence: 'desc' },
      skip,
      take: pageSize,
    });

    return {
      items,
      companies,
      page,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  async invoicesExport(filters: InvoiceListFilters = {}) {
    const where = this.invoiceWhere(filters);

    return this.prisma.arsenInvoice.findMany({
      where,
      select: {
        arsenFactorId: true,
        invoiceNumber: true,
        invoiceDate: true,
        settlementDate: true,
        description: true,
        factorDocType: true,
        factorDocTypeName: true,
        factorPayablePrice: true,
        paymentDays: true,
        itemCount: true,
        isDeletedInArsen: true,
        importedAt: true,
        sourceSyncedAt: true,
        company: { select: { name: true } },
      },
      orderBy: { ingestSequence: 'desc' },
    });
  }

  async invoice(id: string) {
    const item = await this.prisma.arsenInvoice.findUnique({
      where: { id },
      include: {
        company: { select: { id: true, name: true } },
        items: {
          orderBy: [
            { arsenFactorDetailsId: 'asc' },
            { arsenFactorDetailId: 'asc' },
          ],
        },
      },
    });

    if (item == null) {
      throw new NotFoundException('Invoice not found.');
    }

    return item;
  }

  async companies(query = '') {
    const rows = await this.prisma.company.findMany({
      include: {
        _count: {
          select: {
            cheques: true,
            cashPayments: true,
            orderRequests: true,
            arsenCompanyMappings: true,
            arsenInvoices: true,
          },
        },
      },
      orderBy: [{ deletedAt: 'asc' }, { updatedAt: 'desc' }],
    });

    return this.filter(rows, query, (item) => [
      item.name,
      item.nationalId,
      item.economicCode,
      item.bankName,
      item.accountNumber,
      item.cardNumber,
      item.shebaNumber,
      item.visitorName,
      item.visitorPhone,
      item.accountantName,
      item.accountantPhone,
    ]);
  }

  async company(id: string) {
    const item = await this.prisma.company.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            cheques: true,
            cashPayments: true,
            orderRequests: true,
            arsenCompanyMappings: true,
            arsenInvoices: true,
          },
        },
      },
    });

    if (item == null) {
      throw new NotFoundException('Company not found.');
    }

    return item;
  }

  async updateCompany(id: string, body: FormBody) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.company.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Company not found.');
      }

      const after = await tx.company.update({
        where: { id },
        data: {
          name: this.required(body.name),
          nationalId: this.nullable(body.nationalId),
          economicCode: this.nullable(body.economicCode),
          bankName: this.nullable(body.bankName),
          accountNumber: this.nullable(body.accountNumber),
          cardNumber: this.nullable(body.cardNumber),
          shebaNumber: this.nullable(body.shebaNumber),
          notes: this.nullable(body.notes),
          visitorName: this.nullable(body.visitorName),
          visitorPhone: this.nullable(body.visitorPhone),
          accountantName: this.nullable(body.accountantName),
          accountantPhone: this.nullable(body.accountantPhone),
          archivedAt: body.archived === '1' ? new Date() : null,
          deletedAt: body.softDeleted === '1' ? new Date() : null,
        },
      });

      await this.auditLog.record(
        {
          action: 'ADMIN_UPDATE',
          entityType: 'COMPANY',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteCompany(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.company.findUnique({
        where: { id },
        include: {
          _count: {
            select: {
              cheques: true,
              cashPayments: true,
              arsenCompanyMappings: true,
            arsenInvoices: true,
            },
          },
        },
      });

      if (before == null) {
        throw new NotFoundException('Company not found.');
      }

      if (
        before._count.cheques > 0 ||
        before._count.cashPayments > 0 ||
        before._count.arsenCompanyMappings > 0 ||
        before._count.arsenInvoices > 0
      ) {
        throw new ConflictException(
          `Company has ${before._count.cheques} cheque(s), ${before._count.cashPayments} cash payment(s), ${before._count.arsenCompanyMappings} Arsen mapping(s), and ${before._count.arsenInvoices} Arsen invoice(s). Hard-delete dependencies first.`,
        );
      }

      await tx.company.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'COMPANY',
          entityId: id,
          before,
          after: { hardDeleted: true },
        },
        tx,
      );
    });
  }

  async bankAccounts(query = '') {
    const rows = await this.prisma.bankAccount.findMany({
      include: {
        _count: { select: { cheques: true, cashPayments: true } },
      },
      orderBy: [{ deletedAt: 'asc' }, { updatedAt: 'desc' }],
    });

    return this.filter(rows, query, (item) => [
      item.bankName,
      item.accountTitle,
      item.accountHolder,
      item.accountNumber,
      item.cardNumber,
      item.shebaNumber,
      item.notes,
    ]);
  }

  async bankAccount(id: string) {
    const item = await this.prisma.bankAccount.findUnique({
      where: { id },
      include: {
        _count: { select: { cheques: true, cashPayments: true } },
      },
    });

    if (item == null) {
      throw new NotFoundException('Bank account not found.');
    }

    return item;
  }

  async updateBankAccount(id: string, body: FormBody) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.bankAccount.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Bank account not found.');
      }

      const after = await tx.bankAccount.update({
        where: { id },
        data: {
          bankName: this.required(body.bankName),
          accountTitle: this.nullable(body.accountTitle),
          accountHolder: this.nullable(body.accountHolder),
          accountNumber: this.nullable(body.accountNumber),
          cardNumber: this.nullable(body.cardNumber),
          shebaNumber: this.nullable(body.shebaNumber),
          notes: this.nullable(body.notes),
          archivedAt: body.archived === '1' ? new Date() : null,
          deletedAt: body.softDeleted === '1' ? new Date() : null,
        },
      });

      await this.auditLog.record(
        {
          action: 'ADMIN_UPDATE',
          entityType: 'BANK_ACCOUNT',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteBankAccount(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.bankAccount.findUnique({
        where: { id },
        include: {
          _count: { select: { cheques: true, cashPayments: true } },
        },
      });

      if (before == null) {
        throw new NotFoundException('Bank account not found.');
      }

      if (before._count.cheques > 0 || before._count.cashPayments > 0) {
        throw new ConflictException(
          `Bank account has ${before._count.cheques} cheque(s) and ${before._count.cashPayments} cash payment(s). Hard-delete them first.`,
        );
      }

      await tx.bankAccount.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'BANK_ACCOUNT',
          entityId: id,
          before,
          after: { hardDeleted: true },
        },
        tx,
      );
    });
  }

  async cheques(query = '') {
    const rows = await this.prisma.cheque.findMany({
      include: {
        company: { select: { id: true, name: true } },
        bankAccount: {
          select: { id: true, bankName: true, accountTitle: true },
        },
        _count: { select: { attachments: true } },
      },
      orderBy: [{ deletedAt: 'asc' }, { chequeDate: 'desc' }],
    });

    return this.filter(rows, query, (item) => [
      item.chequeNumber,
      item.company.name,
      item.bankAccount.accountTitle,
      item.bankAccount.bankName,
      item.amount,
      item.status,
      item.sayadStatus,
      item.sayadId,
      item.description,
    ]);
  }

  async cheque(id: string) {
    const [item, companies, bankAccounts] = await Promise.all([
      this.prisma.cheque.findUnique({
        where: { id },
        include: {
          company: { select: { id: true, name: true } },
          bankAccount: {
            select: { id: true, bankName: true, accountTitle: true },
          },
          attachments: {
            select: { id: true, fileName: true, storageKey: true },
          },
        },
      }),
      this.prisma.company.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.bankAccount.findMany({ orderBy: { bankName: 'asc' } }),
    ]);

    if (item == null) {
      throw new NotFoundException('Cheque not found.');
    }

    return { item, companies, bankAccounts };
  }

  async updateCheque(id: string, body: FormBody) {
    const amount = this.positiveAmount(body.amount, 'cheque amount');

    return this.prisma.$transaction(async (tx) => {
      const before = await tx.cheque.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Cheque not found.');
      }

      const after = await tx.cheque.update({
        where: { id },
        data: {
          chequeNumber: this.required(body.chequeNumber),
          amount,
          chequeDate: this.requiredDate(body.chequeDate, 'chequeDate'),
          dueDate: this.nullableDate(body.dueDate, 'dueDate'),
          companyId: this.required(body.companyId),
          bankAccountId: this.required(body.bankAccountId),
          status: this.nullable(body.status),
          sayadStatus: this.nullable(body.sayadStatus),
          isRegisteredInSayad: body.isRegisteredInSayad === '1',
          sayadId: this.nullable(body.sayadId),
          description: this.nullable(body.description),
          archivedAt: body.archived === '1' ? new Date() : null,
          deletedAt: body.softDeleted === '1' ? new Date() : null,
        },
      });

      await this.auditLog.record(
        {
          action: 'ADMIN_UPDATE',
          entityType: 'CHEQUE',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteCheque(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.cheque.findUnique({
        where: { id },
        include: { attachments: true },
      });

      if (before == null) {
        throw new NotFoundException('Cheque not found.');
      }

      await tx.pushOutbox.deleteMany({ where: { aggregateId: id } });
      await tx.cheque.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'CHEQUE',
          entityId: id,
          before,
          after: {
            hardDeleted: true,
            databaseAttachmentsDeleted: before.attachments.length,
          },
        },
        tx,
      );
    });
  }

  async cashPayments(query = '') {
    const rows = await this.prisma.cashPayment.findMany({
      include: {
        company: { select: { id: true, name: true } },
        bankAccount: {
          select: { id: true, bankName: true, accountTitle: true },
        },
        _count: { select: { attachments: true } },
      },
      orderBy: [{ deletedAt: 'asc' }, { paymentDate: 'desc' }],
    });

    return this.filter(rows, query, (item) => [
      item.company.name,
      item.bankAccount.accountTitle,
      item.bankAccount.bankName,
      item.amount,
      item.paymentMethod,
      item.trackingNumber,
      item.description,
      item.notes,
    ]);
  }

  async cashPayment(id: string) {
    const [item, companies, bankAccounts] = await Promise.all([
      this.prisma.cashPayment.findUnique({
        where: { id },
        include: {
          company: { select: { id: true, name: true } },
          bankAccount: {
            select: { id: true, bankName: true, accountTitle: true },
          },
          attachments: {
            select: { id: true, fileName: true, storageKey: true },
          },
        },
      }),
      this.prisma.company.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.bankAccount.findMany({ orderBy: { bankName: 'asc' } }),
    ]);

    if (item == null) {
      throw new NotFoundException('Cash payment not found.');
    }

    return { item, companies, bankAccounts };
  }

  async updateCashPayment(id: string, body: FormBody) {
    const amount = this.positiveAmount(body.amount, 'cash payment amount');
    const paymentMethod = this.oneOf(
      body.paymentMethod,
      ['BANK_DEPOSIT', 'POS_PAYMENT'],
      'paymentMethod',
    );

    return this.prisma.$transaction(async (tx) => {
      const before = await tx.cashPayment.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Cash payment not found.');
      }

      const after = await tx.cashPayment.update({
        where: { id },
        data: {
          amount,
          paymentDate: this.requiredDate(body.paymentDate, 'paymentDate'),
          companyId: this.required(body.companyId),
          bankAccountId: this.required(body.bankAccountId),
          paymentMethod,
          trackingNumber: this.nullable(body.trackingNumber),
          description: this.nullable(body.description),
          notes: this.nullable(body.notes),
          archivedAt: body.archived === '1' ? new Date() : null,
          deletedAt: body.softDeleted === '1' ? new Date() : null,
        },
      });

      await this.auditLog.record(
        {
          action: 'ADMIN_UPDATE',
          entityType: 'CASH_PAYMENT',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteCashPayment(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.cashPayment.findUnique({
        where: { id },
        include: { attachments: true },
      });

      if (before == null) {
        throw new NotFoundException('Cash payment not found.');
      }

      await tx.pushOutbox.deleteMany({ where: { aggregateId: id } });
      await tx.cashPayment.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'CASH_PAYMENT',
          entityId: id,
          before,
          after: {
            hardDeleted: true,
            databaseAttachmentsDeleted: before.attachments.length,
          },
        },
        tx,
      );
    });
  }

  async users(query = '') {
    const rows = await this.prisma.appUser.findMany({
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
        managerAppAccess: true,
        canCreateOrders: true,
        canCreateCheques: true,
        canCreateCashPayments: true,
        canViewFinancialReports: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { sessions: true, pushDevices: true } },
      },
      orderBy: [{ isActive: 'desc' }, { displayName: 'asc' }],
    });

    return this.filter(rows, query, (item) => [
      item.username,
      item.displayName,
      item.role,
    ]);
  }

  async user(id: string) {
    const item = await this.prisma.appUser.findUnique({
      where: { id },
      select: {
        id: true,
        username: true,
        displayName: true,
        role: true,
        isActive: true,
        managerAppAccess: true,
        canCreateOrders: true,
        canCreateCheques: true,
        canCreateCashPayments: true,
        canViewFinancialReports: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { sessions: true, pushDevices: true } },
      },
    });

    if (item == null) {
      throw new NotFoundException('User not found.');
    }

    return item;
  }

  async updateUser(id: string, body: FormBody) {
    const username = this.required(body.username)
      .normalize('NFKC')
      .toLowerCase();
    const displayName = this.required(body.displayName);
    const role = this.oneOf(body.role, ['MANAGER', 'STAFF'], 'role');
    const isActive = body.isActive === '1';
    const password = String(body.password ?? '').normalize('NFKC');

    return this.prisma.$transaction(async (tx) => {
      const before = await tx.appUser.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('User not found.');
      }

      if (
        before.role === 'MANAGER' &&
        before.isActive &&
        (role !== 'MANAGER' || !isActive)
      ) {
        const activeManagers = await tx.appUser.count({
          where: { role: 'MANAGER', isActive: true },
        });
        if (activeManagers <= 1) {
          throw new ConflictException(
            'The last active manager cannot be demoted or deactivated.',
          );
        }
      }

      const manager = role === 'MANAGER';
      const after = await tx.appUser.update({
        where: { id },
        data: {
          username,
          displayName,
          role,
          isActive,
          managerAppAccess: manager || body.managerAppAccess === '1',
          canCreateOrders: manager || body.canCreateOrders === '1',
          canCreateCheques: manager || body.canCreateCheques === '1',
          canCreateCashPayments:
            manager || body.canCreateCashPayments === '1',
          canViewFinancialReports:
            manager || body.canViewFinancialReports === '1',
          ...(password ? { passwordHash: hashPassword(password) } : {}),
        },
      });

      if (!isActive || password) {
        await tx.authSession.updateMany({
          where: { userId: id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      }

      await this.auditLog.record(
        {
          action: password ? 'ADMIN_UPDATE_AND_PASSWORD_RESET' : 'ADMIN_UPDATE',
          entityType: 'APP_USER',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteUser(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.appUser.findUnique({
        where: { id },
        include: {
          _count: { select: { sessions: true, pushDevices: true } },
        },
      });

      if (before == null) {
        throw new NotFoundException('User not found.');
      }

      if (before.role === 'MANAGER' && before.isActive) {
        const activeManagers = await tx.appUser.count({
          where: { role: 'MANAGER', isActive: true },
        });
        if (activeManagers <= 1) {
          throw new ConflictException(
            'The last active manager cannot be hard-deleted.',
          );
        }
      }

      await tx.appUser.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'APP_USER',
          entityId: id,
          before,
          after: { hardDeleted: true },
        },
        tx,
      );
    });
  }

  async orders(query = '', status = '') {
    const normalizedStatus = status.trim().toUpperCase();
    const rows = await this.prisma.orderRequest.findMany({
      where: ORDER_STATUSES.includes(
        normalizedStatus as (typeof ORDER_STATUSES)[number],
      )
        ? { status: normalizedStatus }
        : undefined,
      include: {
        assignedCompany: { select: { id: true, name: true } },
      },
      orderBy: [{ createdAt: 'desc' }],
    });

    return this.filter(rows, query, (item) => [
      item.itemText,
      item.category,
      item.status,
      item.suggestedCompanyText,
      item.assignedCompany?.name,
      item.requestedByName,
      item.orderedByName,
      item.receivedByName,
      item.notes,
    ]);
  }

  async order(id: string) {
    const [item, companies] = await Promise.all([
      this.prisma.orderRequest.findUnique({
        where: { id },
        include: {
          assignedCompany: { select: { id: true, name: true } },
        },
      }),
      this.prisma.company.findMany({
        where: { deletedAt: null },
        orderBy: { name: 'asc' },
      }),
    ]);

    if (item == null) {
      throw new NotFoundException('Order request not found.');
    }

    return { item, companies };
  }

  async updateOrder(id: string, body: FormBody) {
    const category = this.oneOf(body.category, ['DRUG', 'GOODS'], 'category');
    const itemText = this.required(body.itemText);
    const status = this.oneOf(body.status, [...ORDER_STATUSES], 'status');
    const requestedQuantity = this.nullableInteger(
      body.requestedQuantity,
      'requestedQuantity',
    );
    let orderedQuantity = this.nullableInteger(
      body.orderedQuantity,
      'orderedQuantity',
    );
    let assignedCompanyId = this.nullable(body.assignedCompanyId);

    return this.prisma.$transaction(async (tx) => {
      const before = await tx.orderRequest.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Order request not found.');
      }

      let orderedAt = this.nullableDate(body.orderedAt, 'orderedAt');
      let receivedAt = this.nullableDate(body.receivedAt, 'receivedAt');
      let canceledAt = this.nullableDate(body.canceledAt, 'canceledAt');
      let deletedAt = this.nullableDate(body.deletedAt, 'deletedAt');

      if (status === 'PENDING') {
        assignedCompanyId = null;
        orderedQuantity = null;
        orderedAt = null;
        receivedAt = null;
        canceledAt = null;
        deletedAt = null;
      } else if (status === 'ORDERED') {
        if (!assignedCompanyId) {
          throw new BadRequestException(
            'assignedCompanyId is required for an ORDERED request.',
          );
        }
        orderedAt ??= before.orderedAt ?? new Date();
        receivedAt = null;
        canceledAt = null;
        deletedAt = null;
      } else if (status === 'RECEIVED') {
        if (!assignedCompanyId) {
          throw new BadRequestException(
            'assignedCompanyId is required for a RECEIVED request.',
          );
        }
        orderedAt ??= before.orderedAt ?? new Date();
        receivedAt ??= before.receivedAt ?? new Date();
        canceledAt = null;
        deletedAt = null;
      } else if (status === 'CANCELED') {
        canceledAt ??= before.canceledAt ?? new Date();
        deletedAt = null;
      } else if (status === 'DELETED') {
        deletedAt ??= before.deletedAt ?? new Date();
      }

      const after = await tx.orderRequest.update({
        where: { id },
        data: {
          category,
          itemText,
          normalizedItemText: normalizeOrderSearchText(itemText),
          requestedQuantity,
          orderedQuantity,
          suggestedCompanyText: this.nullable(body.suggestedCompanyText),
          notes: this.nullable(body.notes),
          status,
          possibleDuplicate: body.possibleDuplicate === '1',
          assignedCompanyId,
          requestedByName: this.required(body.requestedByName),
          orderedByName: this.nullable(body.orderedByName),
          receivedByName: this.nullable(body.receivedByName),
          canceledByName: this.nullable(body.canceledByName),
          deletedByName: this.nullable(body.deletedByName),
          orderedAt,
          receivedAt,
          canceledAt,
          deletedAt,
        },
      });

      await this.auditLog.record(
        {
          action: 'ADMIN_UPDATE',
          entityType: 'ORDER_REQUEST',
          entityId: id,
          before,
          after,
        },
        tx,
      );

      return after;
    });
  }

  async hardDeleteOrder(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.orderRequest.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Order request not found.');
      }

      await tx.pushOutbox.deleteMany({ where: { aggregateId: id } });
      await tx.orderRequest.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'ORDER_REQUEST',
          entityId: id,
          before,
          after: { hardDeleted: true },
        },
        tx,
      );
    });
  }

  async auditLogs(query = '') {
    const rows = await this.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 500,
    });

    return this.filter(rows, query, (item) => [
      item.source,
      item.actorDisplayName,
      item.deviceId,
      item.action,
      item.entityType,
      item.entityId,
      item.ipAddress,
      item.requestId,
    ]);
  }

  async hardDeleteAuditLog(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.auditLog.findUnique({ where: { id } });

      if (before == null) {
        throw new NotFoundException('Audit log not found.');
      }

      await tx.auditLog.delete({ where: { id } });
      await this.auditLog.record(
        {
          action: 'ADMIN_HARD_DELETE',
          entityType: 'AUDIT_LOG',
          entityId: id,
          before,
          after: { hardDeleted: true },
        },
        tx,
      );
    });
  }

  private filter<T>(
    rows: T[],
    query: string,
    values: (row: T) => unknown[],
  ): T[] {
    const q = query.trim().toLowerCase();
    if (!q) {
      return rows;
    }

    return rows.filter((row) =>
      values(row).some((value) =>
        String(value ?? '')
          .toLowerCase()
          .includes(q),
      ),
    );
  }

  private jalaliDate(
    value: string | undefined,
    field: string,
  ): string | null {
    const text = String(value ?? '').trim();
    if (!text) {
      return null;
    }
    if (!JALALI_DATE_PATTERN.test(text)) {
      throw new BadRequestException(`${field} must use YYYY/MM/DD.`);
    }
    return text;
  }

  private positiveInteger(
    value: string | undefined,
    field: string,
  ): number | null {
    const text = String(value ?? '').trim();
    if (!text) {
      return null;
    }
    if (!/^\d+$/.test(text)) {
      throw new BadRequestException(`${field} is invalid.`);
    }
    const result = Number(text);
    if (!Number.isSafeInteger(result) || result <= 0) {
      throw new BadRequestException(`${field} is invalid.`);
    }
    return result;
  }

  private catalogQuery(filters: CatalogListFilters): {
    where: Prisma.ArsenCatalogItemWhereInput;
    orderBy: Prisma.ArsenCatalogItemOrderByWithRelationInput[];
    sort: string;
  } {
    const q = String(filters.q ?? '').trim();
    const categoryText = String(filters.category ?? '').trim().toUpperCase();
    const activeText = String(filters.active ?? '').trim().toUpperCase();
    const shape = String(filters.shape ?? '').trim();
    const sort = String(filters.sort ?? 'SYNC_DESC').trim().toUpperCase();

    if (
      categoryText &&
      !CATALOG_CATEGORIES.includes(
        categoryText as (typeof CATALOG_CATEGORIES)[number],
      )
    ) {
      throw new BadRequestException('catalog category is invalid.');
    }

    if (
      activeText &&
      !CATALOG_ACTIVE_FILTERS.includes(
        activeText as (typeof CATALOG_ACTIVE_FILTERS)[number],
      )
    ) {
      throw new BadRequestException('catalog active filter is invalid.');
    }

    if (!CATALOG_SORTS.includes(sort as (typeof CATALOG_SORTS)[number])) {
      throw new BadRequestException('catalog sort is invalid.');
    }

    const and: Prisma.ArsenCatalogItemWhereInput[] = [];

    if (categoryText) {
      and.push({ category: categoryText });
    }
    if (activeText) {
      and.push({ isActive: activeText === 'ACTIVE' });
    }
    if (shape) {
      and.push({ shapeName: shape });
    }

    if (q) {
      const variants = this.catalogSearchVariants(q);
      const textFields = [
        'persianName',
        'genericName',
        'persianBrandName',
        'brandName',
      ] as const;
      const or: Prisma.ArsenCatalogItemWhereInput[] = [];

      for (const variant of variants) {
        for (const field of textFields) {
          or.push({
            [field]: { contains: variant, mode: 'insensitive' },
          } as Prisma.ArsenCatalogItemWhereInput);
        }
      }

      if (/^\d+$/.test(q)) {
        try {
          const arsenDrugId = BigInt(q);
          if (arsenDrugId > 0n && arsenDrugId <= 9223372036854775807n) {
            or.push({ arsenDrugId });
          }
        } catch {
          // Invalid/oversized numeric searches simply have no ID match.
        }
      }

      and.push({ OR: or });
    }

    return {
      where: and.length > 0 ? { AND: and } : {},
      orderBy: this.catalogOrderBy(sort),
      sort,
    };
  }

  private invoiceWhere(
    filters: InvoiceListFilters,
  ): Prisma.ArsenInvoiceWhereInput {
    const where: Prisma.ArsenInvoiceWhereInput = {};
    const invoiceNumber = String(filters.invoiceNumber ?? '').trim();
    const companyId = String(filters.companyId ?? '').trim();
    const docTypeText = String(filters.docType ?? '').trim();
    const dateFrom = this.jalaliDate(filters.dateFrom, 'invoice date from');
    const dateTo = this.jalaliDate(filters.dateTo, 'invoice date to');

    if (dateFrom && dateTo && dateFrom > dateTo) {
      throw new BadRequestException('invoice date range is invalid.');
    }

    if (invoiceNumber) {
      where.invoiceNumber = { contains: invoiceNumber };
    }

    if (companyId) {
      if (!UUID_PATTERN.test(companyId)) {
        throw new BadRequestException('companyId is invalid.');
      }
      where.companyId = companyId;
    }

    if (docTypeText) {
      const docType = Number(docTypeText);
      if (docType !== 1 && docType !== 2) {
        throw new BadRequestException('invoice doc type is invalid.');
      }
      where.factorDocType = docType;
    }

    if (dateFrom || dateTo) {
      where.invoiceDate = {
        ...(dateFrom ? { gte: dateFrom } : {}),
        ...(dateTo ? { lte: dateTo } : {}),
      };
    }

    return where;
  }

  private catalogPageSize(value: string | undefined): number {
    const text = String(value ?? '').trim();
    if (!text) {
      return DEFAULT_CATALOG_PAGE_SIZE;
    }

    const result = Number(text);
    if (
      !Number.isInteger(result) ||
      !CATALOG_PAGE_SIZES.includes(
        result as (typeof CATALOG_PAGE_SIZES)[number],
      )
    ) {
      throw new BadRequestException('catalog page size is invalid.');
    }

    return result;
  }

  private catalogSearchVariants(value: string): string[] {
    const normalized = value
      .trim()
      .replace(/[يى]/g, 'ی')
      .replace(/ك/g, 'ک');
    const arabicVariant = normalized
      .replace(/ی/g, 'ي')
      .replace(/ک/g, 'ك');

    return [...new Set([value.trim(), normalized, arabicVariant])].filter(Boolean);
  }

  private catalogOrderBy(
    sort: string,
  ): Prisma.ArsenCatalogItemOrderByWithRelationInput[] {
    switch (sort) {
      case 'SYNC_ASC':
        return [{ sourceSyncedAt: 'asc' }, { arsenDrugId: 'asc' }];
      case 'NAME_ASC':
        return [{ persianName: 'asc' }, { arsenDrugId: 'asc' }];
      case 'NAME_DESC':
        return [{ persianName: 'desc' }, { arsenDrugId: 'desc' }];
      case 'ARSEN_ID_ASC':
        return [{ arsenDrugId: 'asc' }];
      case 'ARSEN_ID_DESC':
        return [{ arsenDrugId: 'desc' }];
      case 'SALES_ASC':
        return [{ salesPrice: 'asc' }, { arsenDrugId: 'asc' }];
      case 'SALES_DESC':
        return [{ salesPrice: 'desc' }, { arsenDrugId: 'desc' }];
      case 'PURCHASE_ASC':
        return [{ lastPurchasePrice: 'asc' }, { arsenDrugId: 'asc' }];
      case 'PURCHASE_DESC':
        return [{ lastPurchasePrice: 'desc' }, { arsenDrugId: 'desc' }];
      case 'SYNC_DESC':
      default:
        return [{ sourceSyncedAt: 'desc' }, { arsenDrugId: 'desc' }];
    }
  }

  private invoicePageSize(value: string | undefined): number {
    const text = String(value ?? '').trim();
    if (!text) {
      return DEFAULT_INVOICE_PAGE_SIZE;
    }

    const result = Number(text);
    if (
      !Number.isInteger(result) ||
      !INVOICE_PAGE_SIZES.includes(
        result as (typeof INVOICE_PAGE_SIZES)[number],
      )
    ) {
      throw new BadRequestException('invoice page size is invalid.');
    }

    return result;
  }

  private required(value: string | undefined): string {
    const text = String(value ?? '').trim();
    if (!text) {
      throw new BadRequestException('Required field is empty.');
    }
    return text;
  }

  private nullable(value: string | undefined): string | null {
    const text = String(value ?? '').trim();
    return text || null;
  }

  private oneOf(
    value: string | undefined,
    allowed: readonly string[],
    field: string,
  ): string {
    const text = String(value ?? '').trim().toUpperCase();
    if (!allowed.includes(text)) {
      throw new BadRequestException(`${field} is invalid.`);
    }
    return text;
  }

  private positiveAmount(value: string | undefined, field: string): number {
    const amount = Number(String(value ?? '').replace(/[^0-9.-]/g, ''));
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException(`${field} must be positive.`);
    }
    return amount;
  }

  private nullableInteger(
    value: string | undefined,
    field: string,
  ): number | null {
    const text = String(value ?? '').trim();
    if (!text) {
      return null;
    }
    const number = Number(text);
    if (!Number.isInteger(number) || number <= 0 || number > 1000000) {
      throw new BadRequestException(`${field} is invalid.`);
    }
    return number;
  }

  private requiredDate(value: string | undefined, field: string): Date {
    const result = this.nullableDate(value, field);
    if (result == null) {
      throw new BadRequestException(`${field} is required.`);
    }
    return result;
  }

  private nullableDate(
    value: string | undefined,
    field: string,
  ): Date | null {
    const text = String(value ?? '').trim();
    if (!text) {
      return null;
    }
    const date = new Date(text);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${field} is invalid.`);
    }
    return date;
  }
}
