import type { Prisma } from '@prisma/client';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../database/prisma/prisma.service';

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
  constructor(private readonly prisma: PrismaService) {}

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
        factorDocTypeName: true,
        factorPayablePrice: true,
        paymentDays: true,
        itemCount: true,
        isDeletedInArsen: true,
        isPaidInPharmaFlow: true,
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
      items: rows.map((row) => ({
        id: row.id,
        arsenFactorId: row.arsenFactorId,
        invoiceNumber: row.invoiceNumber,
        invoiceDate: row.invoiceDate,
        settlementDate: row.settlementDate,
        factorDocTypeName: row.factorDocTypeName,
        factorPayablePrice: this.decimalString(row.factorPayablePrice),
        paymentDays: row.paymentDays,
        itemCount: row.itemCount,
        isDeletedInArsen: row.isDeletedInArsen,
        isPaid: row.isPaidInPharmaFlow,
        company: row.company,
      })),
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
      },
    });

    if (invoice == null) {
      throw new NotFoundException('Invoice not found.');
    }

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
      isPaid: invoice.isPaidInPharmaFlow,

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

  async updatePaymentStatus(id: string, isPaid: boolean) {
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

    const updated = await this.prisma.arsenInvoice.update({
      where: {
        id: normalizedId,
      },
      data: {
        isPaidInPharmaFlow: isPaid,
      },
      select: {
        id: true,
        isPaidInPharmaFlow: true,
      },
    });

    return {
      id: updated.id,
      isPaid: updated.isPaidInPharmaFlow,
    };
  }

  private buildWhere(filters: InvoiceListFilters): Prisma.ArsenInvoiceWhereInput {
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
      throw new BadRequestException(
        'pageSize must be one of 25, 50, or 100.',
      );
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
}