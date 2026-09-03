import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { ArsenCatalogItemDto } from './dto/arsen-catalog-item.dto';
import { ArsenInvoiceDto } from './dto/arsen-invoice.dto';

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => canonicalize(item));
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => [key, canonicalize(item)]),
    );
  }

  return value;
}

function fingerprint(value: unknown): string {
  return createHash('sha256')
    .update(JSON.stringify(canonicalize(value)))
    .digest('hex');
}

function nullableText(value: string | null | undefined): string | null {
  const text = String(value ?? '').trim();
  return text || null;
}

function nullableDate(value: string | null | undefined): Date | null {
  return value ? new Date(value) : null;
}

@Injectable()
export class ArsenSyncService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async status() {
    const [mappingCount, invoiceCount, latestInvoice, itemCount, latestItem] =
      await Promise.all([
        this.prisma.arsenCompanyMapping.count(),
        this.prisma.arsenInvoice.count(),
        this.prisma.arsenInvoice.findFirst({
          orderBy: { ingestSequence: 'desc' },
          select: {
            arsenFactorId: true,
            invoiceNumber: true,
            invoiceDate: true,
            sourceSyncedAt: true,
          },
        }),
        this.prisma.arsenCatalogItem.count(),
        this.prisma.arsenCatalogItem.findFirst({
          orderBy: { ingestSequence: 'desc' },
          select: {
            arsenDrugId: true,
            category: true,
            persianName: true,
            sourceSyncedAt: true,
          },
        }),
      ]);

    return {
      status: 'ok',
      mappingCount,
      invoiceCount,
      latestInvoice,
      itemCount,
      latestItem: latestItem
        ? {
            ...latestItem,
            arsenDrugId: latestItem.arsenDrugId.toString(),
          }
        : null,
    };
  }

  async ingestCatalogItems(items: ArsenCatalogItemDto[]) {
    const arsenDrugIds = items.map((item) => item.arsenDrugId);

    if (new Set(arsenDrugIds).size !== arsenDrugIds.length) {
      throw new BadRequestException(
        'Arsen catalog batch contains duplicate arsenDrugId values.',
      );
    }

    const beforeRows = await this.prisma.arsenCatalogItem.findMany({
      where: {
        arsenDrugId: {
          in: arsenDrugIds.map((value) => BigInt(value)),
        },
      },
      select: {
        id: true,
        arsenDrugId: true,
        category: true,
        sourceFingerprint: true,
      },
    });

    const beforeByArsenDrugId = new Map(
      beforeRows.map((row) => [row.arsenDrugId.toString(), row]),
    );

    const prepared = items.map((item) => {
      const category = item.isDrug ? 'DRUG' : 'GOODS';
      const sourceFingerprint = fingerprint(item);
      const before = beforeByArsenDrugId.get(item.arsenDrugId) ?? null;

      return {
        item,
        category,
        sourceFingerprint,
        before,
        unchanged:
          before?.category === category &&
          before.sourceFingerprint === sourceFingerprint,
      };
    });

    const changed = prepared.filter((entry) => !entry.unchanged);
    const savedIds = new Map<string, string>();

    if (changed.length > 0) {
      await this.prisma.$transaction(async (tx) => {
        for (const entry of changed) {
          const { item, category, sourceFingerprint, before } = entry;
          const data = {
            category,
            persianName: nullableText(item.persianName),
            genericName: nullableText(item.genericName),
            persianBrandName: nullableText(item.persianBrandName),
            brandName: nullableText(item.brandName),
            unit: nullableText(item.unit),
            shapeName: nullableText(item.shapeName),
            packetQuantity: item.packetQuantity ?? null,
            salesPrice: item.salesPrice ?? null,
            lastPurchasePrice: item.lastPurchasePrice ?? null,
            isActive: item.isActive,
            description: nullableText(item.description),
            sourceFingerprint,
            sourceSyncedAt: new Date(),
          };

          const saved = await tx.arsenCatalogItem.upsert({
            where: { arsenDrugId: BigInt(item.arsenDrugId) },
            create: {
              arsenDrugId: BigInt(item.arsenDrugId),
              ...data,
            },
            update: data,
            select: { id: true },
          });

          savedIds.set(item.arsenDrugId, saved.id);

          await this.auditLog.record(
            {
              action: before
                ? 'ARSEN_CATALOG_ITEM_SYNC_UPDATE'
                : 'ARSEN_CATALOG_ITEM_SYNC_CREATE',
              entityType: 'ARSEN_CATALOG_ITEM',
              entityId: saved.id,
              before: before
                ? {
                    id: before.id,
                    arsenDrugId: before.arsenDrugId.toString(),
                    category: before.category,
                    sourceFingerprint: before.sourceFingerprint,
                  }
                : null,
              after: {
                arsenDrugId: item.arsenDrugId,
                category,
                persianName: item.persianName ?? null,
                genericName: item.genericName ?? null,
                persianBrandName: item.persianBrandName ?? null,
                brandName: item.brandName ?? null,
                unit: item.unit ?? null,
                shapeName: item.shapeName ?? null,
                packetQuantity: item.packetQuantity ?? null,
                salesPrice: item.salesPrice ?? null,
                lastPurchasePrice: item.lastPurchasePrice ?? null,
                isActive: item.isActive,
                description: item.description ?? null,
                sourceFingerprint,
              },
            },
            tx,
          );
        }
      });
    }

    const results = prepared.map((entry) => ({
      arsenDrugId: entry.item.arsenDrugId,
      status: entry.unchanged
        ? ('UNCHANGED' as const)
        : entry.before
          ? ('UPDATED' as const)
          : ('CREATED' as const),
      itemId: entry.unchanged
        ? entry.before!.id
        : savedIds.get(entry.item.arsenDrugId)!,
    }));

    return {
      processed: results.length,
      created: results.filter((item) => item.status === 'CREATED').length,
      updated: results.filter((item) => item.status === 'UPDATED').length,
      unchanged: results.filter((item) => item.status === 'UNCHANGED').length,
      results,
    };
  }

  async ingest(invoices: ArsenInvoiceDto[]) {
    const results: Array<{
      arsenFactorId: number;
      status: 'CREATED' | 'UPDATED' | 'UNCHANGED';
      invoiceId: string;
    }> = [];

    for (const invoice of invoices) {
      results.push(await this.ingestOne(invoice));
    }

    return {
      processed: results.length,
      created: results.filter((item) => item.status === 'CREATED').length,
      updated: results.filter((item) => item.status === 'UPDATED').length,
      unchanged: results.filter((item) => item.status === 'UNCHANGED').length,
      results,
    };
  }

  private async ingestOne(invoice: ArsenInvoiceDto) {
    const detailIds = invoice.items.map((item) => item.arsenFactorDetailId);

    if (new Set(detailIds).size !== detailIds.length) {
      throw new BadRequestException(
        `Arsen factor ${invoice.arsenFactorId} contains duplicate detail IDs.`,
      );
    }

    const mapping = await this.prisma.arsenCompanyMapping.findUnique({
      where: { arsenBusinessPartnerId: invoice.arsenBusinessPartnerId },
      select: {
        companyId: true,
        company: { select: { deletedAt: true } },
      },
    });

    if (!mapping || mapping.company.deletedAt) {
      throw new BadRequestException(
        `Arsen BusinessPartnerID ${invoice.arsenBusinessPartnerId} is not mapped to an active PharmaFlow company.`,
      );
    }

    const sourceFingerprint = fingerprint(invoice);
    const before = await this.prisma.arsenInvoice.findUnique({
      where: { arsenFactorId: invoice.arsenFactorId },
      select: {
        id: true,
        companyId: true,
        sourceFingerprint: true,
        invoiceNumber: true,
        invoiceDate: true,
        settlementDate: true,
        description: true,
        factorPayablePrice: true,
        itemCount: true,
        isDeletedInArsen: true,
      },
    });

    if (
      before &&
      before.companyId === mapping.companyId &&
      before.sourceFingerprint === sourceFingerprint
    ) {
      return {
        arsenFactorId: invoice.arsenFactorId,
        status: 'UNCHANGED' as const,
        invoiceId: before.id,
      };
    }

    const saved = await this.prisma.$transaction(async (tx) => {
      const headerData = {
        invoiceNumber: nullableText(invoice.invoiceNumber),
        invoiceDate: nullableText(invoice.invoiceDate),
        docDate: nullableText(invoice.docDate),
        settlementDate: nullableText(invoice.settlementDate),
        description: nullableText(invoice.description),
        factorDocType: invoice.factorDocType,
        factorDocTypeName: nullableText(invoice.factorDocTypeName),
        factorType: invoice.factorType ?? null,
        factorTypeName: nullableText(invoice.factorTypeName),
        factorItemType: nullableText(invoice.factorItemType),
        arsenBusinessPartnerId: invoice.arsenBusinessPartnerId,
        arsenBusinessPartnerName: invoice.arsenBusinessPartnerName.trim(),
        companyId: mapping.companyId,
        factorTotalPrice: invoice.factorTotalPrice ?? null,
        factorDiscount: invoice.factorDiscount ?? null,
        factorTax: invoice.factorTax ?? null,
        factorPayablePrice: invoice.factorPayablePrice ?? null,
        barbariPrice: invoice.barbariPrice ?? null,
        paymentDays: invoice.paymentDays ?? null,
        isDeletedInArsen: invoice.isDeletedInArsen,
        isLockedInArsen: invoice.isLockedInArsen ?? null,
        arsenSaveDateTime: nullableDate(invoice.arsenSaveDateTime),
        itemCount: invoice.items.length,
        sourceFingerprint,
        sourceSyncedAt: new Date(),
      };

      const savedInvoice = await tx.arsenInvoice.upsert({
        where: { arsenFactorId: invoice.arsenFactorId },
        create: {
          arsenFactorId: invoice.arsenFactorId,
          ...headerData,
        },
        update: headerData,
        select: { id: true },
      });

      // A deleted source invoice may arrive without detail rows. Keep the last
      // known details so financial history remains inspectable.
      if (!invoice.isDeletedInArsen || invoice.items.length > 0) {
        await tx.arsenInvoiceItem.deleteMany({
          where: { invoiceId: savedInvoice.id },
        });

        if (invoice.items.length > 0) {
          await tx.arsenInvoiceItem.createMany({
            data: invoice.items.map((item) => ({
              invoiceId: savedInvoice.id,
              arsenFactorDetailId: BigInt(item.arsenFactorDetailId),
              arsenFactorDetailsId: item.arsenFactorDetailsId ?? null,
              arsenDrugId: item.arsenDrugId ? BigInt(item.arsenDrugId) : null,
              drugName: nullableText(item.drugName),
              barcode: nullableText(item.barcode),
              packetQuantity: item.packetQuantity ?? null,
              quantity: item.quantity ?? null,
              salePrice: item.salePrice ?? null,
              purchasePrice: item.purchasePrice ?? null,
              rowDiscount: item.rowDiscount ?? null,
              hasTax: item.hasTax ?? null,
              expireDate: nullableText(item.expireDate),
              expireDateGregorian: nullableDate(item.expireDateGregorian),
              batchNumber: nullableText(item.batchNumber),
            })),
          });
        }
      }

      await this.auditLog.record(
        {
          action: before ? 'ARSEN_INVOICE_SYNC_UPDATE' : 'ARSEN_INVOICE_SYNC_CREATE',
          entityType: 'ARSEN_INVOICE',
          entityId: savedInvoice.id,
          before,
          after: {
            arsenFactorId: invoice.arsenFactorId,
            companyId: mapping.companyId,
            invoiceNumber: invoice.invoiceNumber ?? null,
            invoiceDate: invoice.invoiceDate ?? null,
            settlementDate: invoice.settlementDate ?? null,
            description: invoice.description ?? null,
            factorDocType: invoice.factorDocType,
            factorPayablePrice: invoice.factorPayablePrice ?? null,
            itemCount: invoice.items.length,
            isDeletedInArsen: invoice.isDeletedInArsen,
            sourceFingerprint,
          },
        },
        tx,
      );

      return savedInvoice;
    });

    return {
      arsenFactorId: invoice.arsenFactorId,
      status: before ? ('UPDATED' as const) : ('CREATED' as const),
      invoiceId: saved.id,
    };
  }
}
