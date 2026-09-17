import { Prisma } from '@prisma/client';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import {
  enqueueCashPaymentCreatedPush,
  enqueueChequeCreatedPush,
} from '../push/push-outbox.service';
import { CreateInvoiceSettlementDto } from './dto/create-invoice-settlement.dto';

type InvoiceListFilters = {
  q?: string;
  companyId?: string;
  dateFrom?: string;
  dateTo?: string;
  page?: string;
  pageSize?: string;
};

const DEFAULT_PAGE_SIZE = 50;
const ALLOWED_PAGE_SIZES = new Set([25, 50, 100]);
const JALALI_DATE_PATTERN = /^\d{4}\/\d{2}\/\d{2}$/;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class InvoicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async findAll(filters: InvoiceListFilters = {}) {
    const where = this.buildWhere(filters);
    const requestedPage = this.readPositiveInteger(filters.page, 'page') ?? 1;
    const pageSize = this.readPageSize(filters.pageSize);

    const totalCount = await this.prisma.arsenInvoice.count({ where });
    const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
    const page = Math.min(requestedPage, totalPages);
    const skip = (page - 1) * pageSize;

    const rows = await this.prisma.arsenInvoice.findMany({
      where,
      select: {
        id: true,
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
        chequeAllocations: {
          where: { cheque: { deletedAt: null } },
          select: { amount: true },
        },
        cashPaymentAllocations: {
          where: { cashPayment: { deletedAt: null } },
          select: { amount: true },
        },
        discountAllocations: {
          select: { amount: true },
        },
        company: {
          select: {
            id: true,
            name: true,
          },
        },
      },
      orderBy: {
        ingestSequence: 'desc',
      },
      skip,
      take: pageSize,
    });

    return {
      items: rows.map((row) => {
        const payment = this.paymentSummary(row);

        return {
          id: row.id,
          arsenFactorId: row.arsenFactorId,
          invoiceNumber: row.invoiceNumber,
          invoiceDate: row.invoiceDate,
          settlementDate: row.settlementDate,
          factorDocType: row.factorDocType,
          factorDocTypeName: row.factorDocTypeName,
          factorPayablePrice: this.decimalString(row.factorPayablePrice),
          paymentDays: row.paymentDays,
          itemCount: row.itemCount,
          isDeletedInArsen: row.isDeletedInArsen,
          ...payment,
          company: row.company,
        };
      }),
      page,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  async findOne(id: string) {
    const normalizedId = id.trim();

    if (!UUID_PATTERN.test(normalizedId)) {
      throw new BadRequestException('Invalid invoice id.');
    }

    const invoice = await this.prisma.arsenInvoice.findUnique({
      where: {
        id: normalizedId,
      },
      include: {
        company: {
          select: {
            id: true,
            name: true,
          },
        },
        items: {
          orderBy: [
            {
              arsenFactorDetailsId: 'asc',
            },
            {
              arsenFactorDetailId: 'asc',
            },
          ],
        },
        chequeAllocations: {
          where: { cheque: { deletedAt: null } },
          select: { amount: true },
        },
        cashPaymentAllocations: {
          where: { cashPayment: { deletedAt: null } },
          select: { amount: true },
        },
        discountAllocations: {
          select: { amount: true },
        },
      },
    });

    if (invoice == null) {
      throw new NotFoundException('Invoice not found.');
    }

    const payment = this.paymentSummary(invoice);

    return {
      id: invoice.id,
      arsenFactorId: invoice.arsenFactorId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      docDate: invoice.docDate,
      settlementDate: invoice.settlementDate,
      description: invoice.description,

      factorDocType: invoice.factorDocType,
      factorDocTypeName: invoice.factorDocTypeName,
      factorType: invoice.factorType,
      factorTypeName: invoice.factorTypeName,
      factorItemType: invoice.factorItemType,

      arsenBusinessPartnerId: invoice.arsenBusinessPartnerId,
      arsenBusinessPartnerName: invoice.arsenBusinessPartnerName,

      factorTotalPrice: this.decimalString(invoice.factorTotalPrice),
      factorDiscount: this.decimalString(invoice.factorDiscount),
      factorTax: this.decimalString(invoice.factorTax),
      factorPayablePrice: this.decimalString(invoice.factorPayablePrice),
      barbariPrice: this.decimalString(invoice.barbariPrice),
      paymentDays: invoice.paymentDays,

      itemCount: invoice.itemCount,
      isDeletedInArsen: invoice.isDeletedInArsen,
      isLockedInArsen: invoice.isLockedInArsen,
      ...payment,

      company: invoice.company,

      items: invoice.items.map((item) => ({
        id: item.id,
        arsenFactorDetailId: item.arsenFactorDetailId.toString(),
        arsenFactorDetailsId: item.arsenFactorDetailsId,
        arsenDrugId: item.arsenDrugId?.toString() ?? null,
        drugName: item.drugName,
        barcode: item.barcode,
        packetQuantity: item.packetQuantity,
        quantity: item.quantity,
        salePrice: this.decimalString(item.salePrice),
        purchasePrice: this.decimalString(item.purchasePrice),
        rowDiscount: this.decimalString(item.rowDiscount),
        hasTax: item.hasTax,
        expireDate: item.expireDate,
        batchNumber: item.batchNumber,
      })),
    };
  }

  async updatePaymentStatus(id: string, _isPaid: boolean) {
    const normalizedId = id.trim();

    if (!UUID_PATTERN.test(normalizedId)) {
      throw new BadRequestException('Invalid invoice id.');
    }

    const existing = await this.prisma.arsenInvoice.findUnique({
      where: {
        id: normalizedId,
      },
      select: {
        id: true,
      },
    });

    if (existing == null) {
      throw new NotFoundException('Invoice not found.');
    }

    throw new BadRequestException(
      'Invoice payment status is calculated from payment allocations. Use the settlement endpoint.',
    );
  }

  async prepareSettlement(invoiceIdsText: string) {
    const invoiceIds = this.readInvoiceIds(invoiceIdsText);
    const [rows, bankAccounts] = await Promise.all([
      this.prisma.arsenInvoice.findMany({
        where: { id: { in: invoiceIds } },
        select: this.settlementInvoiceSelect(),
      }),
      this.prisma.bankAccount.findMany({
        where: { deletedAt: null },
        select: {
          id: true,
          bankName: true,
          accountTitle: true,
          accountNumber: true,
        },
        orderBy: [{ bankName: 'asc' }, { accountTitle: 'asc' }],
      }),
    ]);
    const invoices = this.validateSettlementInvoices(invoiceIds, rows);

    return {
      company: invoices[0].company,
      invoices: invoices.map((invoice) => ({
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.invoiceDate,
        factorPayablePrice: this.decimalString(invoice.factorPayablePrice),
        ...this.paymentSummary(invoice),
      })),
      totalRemainingAmount: invoices
        .reduce(
          (sum, invoice) =>
            sum.plus(this.paymentSummary(invoice).remainingAmount),
          new Prisma.Decimal(0),
        )
        .toString(),
      bankAccounts,
    };
  }

  async createSettlement(dto: CreateInvoiceSettlementDto) {
    const invoiceIds = this.uniqueInvoiceIds(dto.invoiceIds);
    const chequeAmount = new Prisma.Decimal(dto.cheque?.amount ?? 0);
    const cashAmount = new Prisma.Decimal(dto.cash?.amount ?? 0);
    const discountAmount = new Prisma.Decimal(dto.discountAmount ?? 0);
    const requestedTotal = chequeAmount.plus(cashAmount).plus(discountAmount);

    if (requestedTotal.lte(0)) {
      throw new BadRequestException(
        'At least one cheque, cash payment, or cash discount is required.',
      );
    }

    return this.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw`SELECT "id" FROM "arsen_invoices" WHERE "id"::text IN (${Prisma.join(invoiceIds)}) FOR UPDATE`;

        const rows = await tx.arsenInvoice.findMany({
          where: { id: { in: invoiceIds } },
          select: this.settlementInvoiceSelect(),
        });
        const invoices = this.validateSettlementInvoices(invoiceIds, rows);
        const remainingByInvoice = new Map<string, Prisma.Decimal>();

        for (const invoice of invoices) {
          remainingByInvoice.set(
            invoice.id,
            new Prisma.Decimal(this.paymentSummary(invoice).remainingAmount),
          );
        }

        const totalRemaining = [...remainingByInvoice.values()].reduce(
          (sum, amount) => sum.plus(amount),
          new Prisma.Decimal(0),
        );

        if (requestedTotal.gt(totalRemaining)) {
          throw new BadRequestException(
            'Settlement total cannot exceed the selected invoices remaining amount.',
          );
        }

        await this.validateSettlementBankAccounts(tx, dto);

        let chequeId: string | null = null;
        let cashPaymentId: string | null = null;

        if (dto.cheque != null) {
          const payment = await tx.cheque.create({
            data: {
              chequeNumber: dto.cheque.chequeNumber.trim(),
              amount: chequeAmount,
              chequeDate: new Date(dto.cheque.chequeDate),
              dueDate:
                dto.cheque.dueDate == null
                  ? null
                  : new Date(dto.cheque.dueDate),
              companyId: invoices[0].company.id,
              bankAccountId: dto.cheque.bankAccountId,
              status: 'ISSUED',
              isRegisteredInSayad: false,
              description:
                dto.cheque.description?.trim() || dto.notes?.trim() || null,
            },
          });
          chequeId = payment.id;
          const allocations = this.allocateAmount(
            chequeAmount,
            invoices,
            remainingByInvoice,
          );
          await tx.chequeInvoiceAllocation.createMany({
            data: allocations.map((allocation) => ({
              invoiceId: allocation.invoiceId,
              chequeId: payment.id,
              amount: allocation.amount,
            })),
          });
          await enqueueChequeCreatedPush(payment.id, tx);
        }

        if (dto.cash != null) {
          const payment = await tx.cashPayment.create({
            data: {
              amount: cashAmount,
              paymentDate: new Date(dto.cash.paymentDate),
              companyId: invoices[0].company.id,
              bankAccountId: dto.cash.bankAccountId,
              paymentMethod: dto.cash.paymentMethod,
              trackingNumber: dto.cash.trackingNumber?.trim() || null,
              description:
                dto.cash.description?.trim() || dto.notes?.trim() || null,
              notes: dto.notes?.trim() || null,
            },
          });
          cashPaymentId = payment.id;
          const allocations = this.allocateAmount(
            cashAmount,
            invoices,
            remainingByInvoice,
          );
          await tx.cashPaymentInvoiceAllocation.createMany({
            data: allocations.map((allocation) => ({
              invoiceId: allocation.invoiceId,
              cashPaymentId: payment.id,
              amount: allocation.amount,
            })),
          });
          await enqueueCashPaymentCreatedPush(payment.id, tx);
        }

        if (discountAmount.gt(0)) {
          const allocations = this.allocateAmount(
            discountAmount,
            invoices,
            remainingByInvoice,
          );
          await tx.invoiceDiscountAllocation.createMany({
            data: allocations.map((allocation) => ({
              invoiceId: allocation.invoiceId,
              amount: allocation.amount,
              description:
                dto.discountDescription?.trim() || 'تخفیف پرداخت نقدی',
            })),
          });
        }

        const result = {
          invoiceIds,
          company: invoices[0].company,
          chequeId,
          cashPaymentId,
          chequeAmount: chequeAmount.toString(),
          cashAmount: cashAmount.toString(),
          discountAmount: discountAmount.toString(),
          settledAmount: requestedTotal.toString(),
          remainingAmount: [...remainingByInvoice.values()]
            .reduce((sum, amount) => sum.plus(amount), new Prisma.Decimal(0))
            .toString(),
        };

        await this.auditLog.record(
          {
            action: 'CREATE_INVOICE_SETTLEMENT',
            entityType: 'ARSEN_INVOICE_SETTLEMENT',
            entityId: chequeId ?? cashPaymentId ?? invoiceIds[0],
            after: result,
          },
          tx,
        );

        return result;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
  }

  private buildWhere(
    filters: InvoiceListFilters,
  ): Prisma.ArsenInvoiceWhereInput {
    const where: Prisma.ArsenInvoiceWhereInput = {};

    const q = filters.q?.trim();

    if (q != null && q.length > 0) {
      const conditions: Prisma.ArsenInvoiceWhereInput[] = [
        {
          invoiceNumber: {
            contains: q,
            mode: 'insensitive',
          },
        },
        {
          arsenBusinessPartnerName: {
            contains: q,
            mode: 'insensitive',
          },
        },
        {
          company: {
            name: {
              contains: q,
              mode: 'insensitive',
            },
          },
        },
      ];

      const numericFactorId = Number(q);

      if (
        Number.isInteger(numericFactorId) &&
        numericFactorId >= 0 &&
        numericFactorId <= 2147483647
      ) {
        conditions.push({
          arsenFactorId: numericFactorId,
        });
      }

      where.OR = conditions;
    }

    const companyId = filters.companyId?.trim();

    if (companyId != null && companyId.length > 0) {
      if (!UUID_PATTERN.test(companyId)) {
        throw new BadRequestException('Invalid companyId.');
      }

      where.companyId = companyId;
    }

    const dateFrom = this.readJalaliDate(filters.dateFrom, 'dateFrom');
    const dateTo = this.readJalaliDate(filters.dateTo, 'dateTo');

    if (dateFrom != null && dateTo != null && dateFrom > dateTo) {
      throw new BadRequestException('dateFrom cannot be after dateTo.');
    }

    if (dateFrom != null || dateTo != null) {
      where.invoiceDate = {
        ...(dateFrom == null ? {} : { gte: dateFrom }),
        ...(dateTo == null ? {} : { lte: dateTo }),
      };
    }

    return where;
  }

  private readPositiveInteger(
    raw: string | undefined,
    field: string,
  ): number | null {
    const normalized = raw?.trim();

    if (normalized == null || normalized.length === 0) {
      return null;
    }

    if (!/^\d+$/.test(normalized)) {
      throw new BadRequestException(`${field} must be a positive integer.`);
    }

    const value = Number(normalized);

    if (!Number.isSafeInteger(value) || value < 1) {
      throw new BadRequestException(`${field} must be a positive integer.`);
    }

    return value;
  }

  private readPageSize(raw: string | undefined): number {
    const value = this.readPositiveInteger(raw, 'pageSize');

    if (value == null) {
      return DEFAULT_PAGE_SIZE;
    }

    if (!ALLOWED_PAGE_SIZES.has(value)) {
      throw new BadRequestException('pageSize must be one of 25, 50, or 100.');
    }

    return value;
  }

  private readJalaliDate(
    raw: string | undefined,
    field: string,
  ): string | null {
    const normalized = raw?.trim();

    if (normalized == null || normalized.length === 0) {
      return null;
    }

    if (!JALALI_DATE_PATTERN.test(normalized)) {
      throw new BadRequestException(`${field} must use YYYY/MM/DD.`);
    }

    return normalized;
  }

  private decimalString(value: { toString(): string } | null): string | null {
    return value == null ? null : value.toString();
  }

  private paymentSummary(invoice: {
    factorPayablePrice: Prisma.Decimal | null;
    chequeAllocations: Array<{ amount: Prisma.Decimal }>;
    cashPaymentAllocations: Array<{ amount: Prisma.Decimal }>;
    discountAllocations: Array<{ amount: Prisma.Decimal }>;
  }) {
    const payable = new Prisma.Decimal(invoice.factorPayablePrice ?? 0);
    const paid = [
      ...invoice.chequeAllocations,
      ...invoice.cashPaymentAllocations,
    ].reduce(
      (sum, allocation) => sum.plus(new Prisma.Decimal(allocation.amount)),
      new Prisma.Decimal(0),
    );
    const discount = invoice.discountAllocations.reduce(
      (sum, allocation) => sum.plus(new Prisma.Decimal(allocation.amount)),
      new Prisma.Decimal(0),
    );
    const settled = paid.plus(discount);
    const rawRemaining = payable.minus(settled);
    const remaining = rawRemaining.gt(0) ? rawRemaining : new Prisma.Decimal(0);
    const paymentStatus = settled.lte(0)
      ? 'UNPAID'
      : remaining.lte(0)
        ? 'PAID'
        : 'PARTIAL';

    return {
      paidAmount: paid.toString(),
      discountAmount: discount.toString(),
      settledAmount: settled.toString(),
      remainingAmount: remaining.toString(),
      paymentStatus,
      isPaid: paymentStatus === 'PAID',
    };
  }

  private readInvoiceIds(raw: string): string[] {
    return this.uniqueInvoiceIds(raw.split(','));
  }

  private uniqueInvoiceIds(values: string[]): string[] {
    const normalized = values.map((value) => value.trim()).filter(Boolean);

    if (normalized.length === 0) {
      throw new BadRequestException('At least one invoice id is required.');
    }

    if (normalized.some((id) => !UUID_PATTERN.test(id))) {
      throw new BadRequestException('One or more invoice ids are invalid.');
    }

    const unique = [...new Set(normalized)];
    if (unique.length !== normalized.length) {
      throw new BadRequestException('Duplicate invoice ids are not allowed.');
    }

    return unique;
  }

  private settlementInvoiceSelect() {
    return {
      id: true,
      invoiceNumber: true,
      invoiceDate: true,
      factorDocType: true,
      factorPayablePrice: true,
      isDeletedInArsen: true,
      company: { select: { id: true, name: true } },
      chequeAllocations: {
        where: { cheque: { deletedAt: null } },
        select: { amount: true },
      },
      cashPaymentAllocations: {
        where: { cashPayment: { deletedAt: null } },
        select: { amount: true },
      },
      discountAllocations: { select: { amount: true } },
    } satisfies Prisma.ArsenInvoiceSelect;
  }

  private validateSettlementInvoices<
    T extends {
      id: string;
      factorDocType: number;
      factorPayablePrice: Prisma.Decimal | null;
      isDeletedInArsen: boolean;
      company: { id: string; name: string };
      chequeAllocations: Array<{ amount: Prisma.Decimal }>;
      cashPaymentAllocations: Array<{ amount: Prisma.Decimal }>;
      discountAllocations: Array<{ amount: Prisma.Decimal }>;
    },
  >(invoiceIds: string[], rows: T[]): T[] {
    if (rows.length !== invoiceIds.length) {
      throw new NotFoundException('One or more invoices were not found.');
    }

    const byId = new Map(rows.map((row) => [row.id, row]));
    const invoices = invoiceIds.map((id) => byId.get(id)!);
    const companyId = invoices[0].company.id;

    if (invoices.some((invoice) => invoice.company.id !== companyId)) {
      throw new BadRequestException(
        'All selected invoices must belong to one company.',
      );
    }

    if (
      invoices.some(
        (invoice) => invoice.factorDocType !== 1 || invoice.isDeletedInArsen,
      )
    ) {
      throw new BadRequestException(
        'Only active purchase invoices can be settled.',
      );
    }

    if (
      invoices.some((invoice) =>
        new Prisma.Decimal(this.paymentSummary(invoice).remainingAmount).lte(0),
      )
    ) {
      throw new ConflictException(
        'One or more selected invoices are already fully settled.',
      );
    }

    return invoices;
  }

  private async validateSettlementBankAccounts(
    tx: Prisma.TransactionClient,
    dto: CreateInvoiceSettlementDto,
  ) {
    const requested = [
      dto.cheque?.bankAccountId,
      dto.cash?.bankAccountId,
    ].filter((value): value is string => value != null);
    const unique = [...new Set(requested)];
    const count = await tx.bankAccount.count({
      where: { id: { in: unique }, deletedAt: null },
    });

    if (count !== unique.length) {
      throw new BadRequestException('One or more bank accounts are invalid.');
    }
  }

  private allocateAmount<T extends { id: string }>(
    total: Prisma.Decimal,
    invoices: T[],
    remainingByInvoice: Map<string, Prisma.Decimal>,
  ) {
    let unallocated = total;
    const result: Array<{ invoiceId: string; amount: Prisma.Decimal }> = [];

    for (const invoice of invoices) {
      if (unallocated.lte(0)) {
        break;
      }

      const remaining = remainingByInvoice.get(invoice.id);
      if (remaining == null || remaining.lte(0)) {
        continue;
      }

      const amount = remaining.lt(unallocated) ? remaining : unallocated;
      result.push({ invoiceId: invoice.id, amount });
      remainingByInvoice.set(invoice.id, remaining.minus(amount));
      unallocated = unallocated.minus(amount);
    }

    if (unallocated.gt(0)) {
      throw new ConflictException(
        'Invoice balances changed while the settlement was being created.',
      );
    }

    return result;
  }
}
