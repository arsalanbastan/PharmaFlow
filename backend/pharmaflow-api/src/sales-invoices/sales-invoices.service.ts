import { Prisma } from '@prisma/client';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateSalesInvoiceDto } from './dto/create-sales-invoice.dto';
import { UpdateSalesInvoiceProfileDto } from './dto/update-sales-invoice-profile.dto';

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PAGE_SIZES = new Set([25, 50, 100]);

type SalesInvoiceFilters = {
  q?: string;
  page?: string;
  pageSize?: string;
};

@Injectable()
export class SalesInvoicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  profile() {
    return this.prisma.salesInvoiceProfile.upsert({
      where: { id: 'default' },
      create: { id: 'default', sellerName: 'داروخانه دکتر خسروانی' },
      update: {},
    });
  }

  updateProfile(dto: UpdateSalesInvoiceProfileDto) {
    const sellerName = dto.sellerName.trim();
    if (sellerName.length === 0) {
      throw new BadRequestException('sellerName is required.');
    }

    const data = {
      sellerName,
      legalName: this.optional(dto.legalName),
      nationalId: this.optional(dto.nationalId),
      economicCode: this.optional(dto.economicCode),
      phone: this.optional(dto.phone),
      address: this.optional(dto.address),
      logoData: this.optional(dto.logoData),
    };

    return this.prisma.salesInvoiceProfile.upsert({
      where: { id: 'default' },
      create: { id: 'default', ...data },
      update: data,
    });
  }

  async findAll(filters: SalesInvoiceFilters = {}) {
    const page = this.positiveInteger(filters.page, 'page') ?? 1;
    const pageSize = this.pageSize(filters.pageSize);
    const q = filters.q?.trim();
    const where: Prisma.SalesInvoiceWhereInput = q
      ? {
          OR: [
            { invoiceNumber: { contains: q, mode: 'insensitive' } },
            { buyerName: { contains: q, mode: 'insensitive' } },
            { buyerPhone: { contains: q, mode: 'insensitive' } },
            { buyerNationalId: { contains: q, mode: 'insensitive' } },
          ],
        }
      : {};
    const totalCount = await this.prisma.salesInvoice.count({ where });
    const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
    const boundedPage = Math.min(page, totalPages);
    const rows = await this.prisma.salesInvoice.findMany({
      where,
      select: {
        id: true,
        sequence: true,
        invoiceNumber: true,
        issueDate: true,
        buyerName: true,
        buyerPhone: true,
        subtotal: true,
        discount: true,
        payableAmount: true,
        status: true,
        createdAt: true,
        _count: { select: { items: true } },
      },
      orderBy: [{ issueDate: 'desc' }, { sequence: 'desc' }],
      skip: (boundedPage - 1) * pageSize,
      take: pageSize,
    });

    return {
      items: rows.map((row) => ({
        id: row.id,
        sequence: row.sequence.toString(),
        invoiceNumber: row.invoiceNumber,
        issueDate: row.issueDate,
        buyerName: row.buyerName,
        buyerPhone: row.buyerPhone,
        subtotal: row.subtotal.toString(),
        discount: row.discount.toString(),
        payableAmount: row.payableAmount.toString(),
        status: row.status,
        itemCount: row._count.items,
        createdAt: row.createdAt,
      })),
      page: boundedPage,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  async findOne(id: string) {
    const normalized = id.trim();
    if (!UUID_PATTERN.test(normalized)) {
      throw new BadRequestException('Invalid sales invoice id.');
    }

    const invoice = await this.prisma.salesInvoice.findUnique({
      where: { id: normalized },
      include: { items: { orderBy: { createdAt: 'asc' } } },
    });
    if (invoice == null) {
      throw new NotFoundException('Sales invoice not found.');
    }

    return this.serializeInvoice(invoice);
  }

  async create(dto: CreateSalesInvoiceDto) {
    const buyerName = dto.buyerName.trim();
    if (buyerName.length === 0) {
      throw new BadRequestException('buyerName is required.');
    }

    const catalogIds = dto.items.map((item) => item.catalogItemId);
    if (new Set(catalogIds).size !== catalogIds.length) {
      throw new BadRequestException(
        'Duplicate catalog items are not allowed in one invoice.',
      );
    }

    const [profile, catalogItems] = await Promise.all([
      this.profile(),
      this.prisma.arsenCatalogItem.findMany({
        where: { id: { in: catalogIds }, isActive: true },
      }),
    ]);
    if (catalogItems.length !== catalogIds.length) {
      throw new BadRequestException(
        'One or more selected catalog items are unavailable.',
      );
    }

    const byId = new Map(catalogItems.map((item) => [item.id, item]));
    let subtotal = new Prisma.Decimal(0);
    const items = dto.items.map((requested) => {
      const catalog = byId.get(requested.catalogItemId)!;
      const quantity = new Prisma.Decimal(requested.quantity);
      const unitPrice = new Prisma.Decimal(requested.unitPrice);
      const lineDiscount = new Prisma.Decimal(requested.lineDiscount ?? 0);
      const gross = quantity.mul(unitPrice);
      if (lineDiscount.gt(gross)) {
        throw new BadRequestException(
          'An item discount cannot exceed its gross amount.',
        );
      }
      const lineTotal = gross.minus(lineDiscount);
      subtotal = subtotal.plus(lineTotal);
      const itemName =
        catalog.persianName?.trim() ||
        catalog.genericName?.trim() ||
        catalog.persianBrandName?.trim() ||
        `Arsen #${catalog.arsenDrugId.toString()}`;

      return {
        catalogItemId: catalog.id,
        arsenDrugId: catalog.arsenDrugId,
        itemName,
        unit: catalog.unit,
        quantity,
        unitPrice,
        lineDiscount,
        lineTotal,
      };
    });

    const discount = new Prisma.Decimal(dto.discount ?? 0);
    if (discount.gt(subtotal)) {
      throw new BadRequestException(
        'Invoice discount cannot exceed the subtotal.',
      );
    }
    const payableAmount = subtotal.minus(discount);

    return this.prisma.$transaction(async (tx) => {
      const created = await tx.salesInvoice.create({
        data: {
          issueDate: new Date(dto.issueDate),
          buyerName,
          buyerNationalId: this.optional(dto.buyerNationalId),
          buyerPhone: this.optional(dto.buyerPhone),
          buyerAddress: this.optional(dto.buyerAddress),
          sellerName: profile.sellerName,
          sellerLegalName: profile.legalName,
          sellerNationalId: profile.nationalId,
          sellerEconomicCode: profile.economicCode,
          sellerPhone: profile.phone,
          sellerAddress: profile.address,
          sellerLogoData: profile.logoData,
          subtotal,
          discount,
          payableAmount,
          notes: this.optional(dto.notes),
          items: { create: items },
        },
        include: { items: { orderBy: { createdAt: 'asc' } } },
      });
      const invoiceNumber = `PF-${created.sequence.toString().padStart(8, '0')}`;
      const updated = await tx.salesInvoice.update({
        where: { id: created.id },
        data: { invoiceNumber },
        include: { items: { orderBy: { createdAt: 'asc' } } },
      });
      await this.auditLog.record(
        {
          action: 'CREATE_SALES_INVOICE',
          entityType: 'SALES_INVOICE',
          entityId: updated.id,
          after: {
            invoiceNumber,
            buyerName,
            payableAmount: payableAmount.toString(),
            itemCount: items.length,
          },
        },
        tx,
      );
      return this.serializeInvoice(updated);
    });
  }

  private serializeInvoice(invoice: {
    id: string;
    sequence: bigint;
    invoiceNumber: string | null;
    issueDate: Date;
    buyerName: string;
    buyerNationalId: string | null;
    buyerPhone: string | null;
    buyerAddress: string | null;
    sellerName: string;
    sellerLegalName: string | null;
    sellerNationalId: string | null;
    sellerEconomicCode: string | null;
    sellerPhone: string | null;
    sellerAddress: string | null;
    sellerLogoData: string | null;
    subtotal: Prisma.Decimal;
    discount: Prisma.Decimal;
    payableAmount: Prisma.Decimal;
    notes: string | null;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    items: Array<{
      id: string;
      catalogItemId: string | null;
      arsenDrugId: bigint | null;
      itemName: string;
      barcode: string | null;
      unit: string | null;
      quantity: Prisma.Decimal;
      unitPrice: Prisma.Decimal;
      lineDiscount: Prisma.Decimal;
      lineTotal: Prisma.Decimal;
    }>;
  }) {
    return {
      ...invoice,
      sequence: invoice.sequence.toString(),
      subtotal: invoice.subtotal.toString(),
      discount: invoice.discount.toString(),
      payableAmount: invoice.payableAmount.toString(),
      items: invoice.items.map((item) => ({
        ...item,
        arsenDrugId: item.arsenDrugId?.toString() ?? null,
        quantity: item.quantity.toString(),
        unitPrice: item.unitPrice.toString(),
        lineDiscount: item.lineDiscount.toString(),
        lineTotal: item.lineTotal.toString(),
      })),
    };
  }

  private optional(value: string | undefined): string | null {
    const normalized = value?.trim();
    return normalized == null || normalized.length === 0 ? null : normalized;
  }

  private positiveInteger(raw: string | undefined, field: string) {
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

  private pageSize(raw: string | undefined) {
    const value = this.positiveInteger(raw, 'pageSize') ?? 25;
    if (!PAGE_SIZES.has(value)) {
      throw new BadRequestException('pageSize must be one of 25, 50, or 100.');
    }
    return value;
  }
}
