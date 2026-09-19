"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ArsenSyncService = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const audit_log_service_1 = require("../audit/audit-log.service");
const prisma_service_1 = require("../database/prisma/prisma.service");
function canonicalize(value) {
    if (Array.isArray(value)) {
        return value.map((item) => canonicalize(item));
    }
    if (value && typeof value === 'object') {
        return Object.fromEntries(Object.entries(value)
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([key, item]) => [key, canonicalize(item)]));
    }
    return value;
}
function fingerprint(value) {
    return (0, node_crypto_1.createHash)('sha256')
        .update(JSON.stringify(canonicalize(value)))
        .digest('hex');
}
function nullableText(value) {
    const text = String(value ?? '').trim();
    return text || null;
}
function nullableDate(value) {
    return value ? new Date(value) : null;
}
let ArsenSyncService = class ArsenSyncService {
    prisma;
    auditLog;
    constructor(prisma, auditLog) {
        this.prisma = prisma;
        this.auditLog = auditLog;
    }
    async status() {
        const [mappingCount, invoiceCount, latestInvoice, itemCount, latestItem] = await Promise.all([
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
    async ingestCatalogItems(items) {
        const arsenDrugIds = items.map((item) => item.arsenDrugId);
        if (new Set(arsenDrugIds).size !== arsenDrugIds.length) {
            throw new common_1.BadRequestException('Arsen catalog batch contains duplicate arsenDrugId values.');
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
        const beforeByArsenDrugId = new Map(beforeRows.map((row) => [row.arsenDrugId.toString(), row]));
        const prepared = items.map((item) => {
            const category = item.isDrug ? 'DRUG' : 'GOODS';
            const sourceFingerprint = fingerprint(item);
            const before = beforeByArsenDrugId.get(item.arsenDrugId) ?? null;
            return {
                item,
                category,
                sourceFingerprint,
                before,
                unchanged: before?.category === category &&
                    before.sourceFingerprint === sourceFingerprint,
            };
        });
        const changed = prepared.filter((entry) => !entry.unchanged);
        const savedIds = new Map();
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
                    await this.auditLog.record({
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
                    }, tx);
                }
            });
        }
        const results = prepared.map((entry) => ({
            arsenDrugId: entry.item.arsenDrugId,
            status: entry.unchanged
                ? 'UNCHANGED'
                : entry.before
                    ? 'UPDATED'
                    : 'CREATED',
            itemId: entry.unchanged
                ? entry.before.id
                : savedIds.get(entry.item.arsenDrugId),
        }));
        return {
            processed: results.length,
            created: results.filter((item) => item.status === 'CREATED').length,
            updated: results.filter((item) => item.status === 'UPDATED').length,
            unchanged: results.filter((item) => item.status === 'UNCHANGED').length,
            results,
        };
    }
    async ingestCompanies(companies) {
        const partnerIds = companies.map((company) => company.arsenBusinessPartnerId);
        if (new Set(partnerIds).size !== partnerIds.length) {
            throw new common_1.BadRequestException('Arsen company batch contains duplicate arsenBusinessPartnerId values.');
        }
        const results = [];
        for (const source of companies) {
            const arsenName = source.arsenName.trim();
            if (!arsenName) {
                throw new common_1.BadRequestException(`Arsen BusinessPartnerID ${source.arsenBusinessPartnerId} has an empty name.`);
            }
            results.push(await this.prisma.$transaction(async (tx) => {
                const existingMapping = await tx.arsenCompanyMapping.findUnique({
                    where: {
                        arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                    },
                    select: {
                        id: true,
                        arsenName: true,
                        companyId: true,
                        company: {
                            select: {
                                deletedAt: true,
                            },
                        },
                    },
                });
                if (existingMapping) {
                    if (existingMapping.company.deletedAt) {
                        throw new common_1.BadRequestException(`Arsen BusinessPartnerID ${source.arsenBusinessPartnerId} is mapped to a deleted PharmaFlow company.`);
                    }
                    if (existingMapping.arsenName === arsenName) {
                        return {
                            arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                            status: 'UNCHANGED',
                            companyId: existingMapping.companyId,
                        };
                    }
                    await tx.arsenCompanyMapping.update({
                        where: { id: existingMapping.id },
                        data: { arsenName },
                    });
                    await this.auditLog.record({
                        action: 'ARSEN_COMPANY_SYNC_UPDATE',
                        entityType: 'ARSEN_COMPANY_MAPPING',
                        entityId: existingMapping.id,
                        before: {
                            arsenName: existingMapping.arsenName,
                            companyId: existingMapping.companyId,
                        },
                        after: {
                            arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                            arsenName,
                            companyId: existingMapping.companyId,
                        },
                    }, tx);
                    return {
                        arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                        status: 'UPDATED',
                        companyId: existingMapping.companyId,
                    };
                }
                const existingCompany = await tx.company.findUnique({
                    where: { name: arsenName },
                    select: {
                        id: true,
                        deletedAt: true,
                    },
                });
                if (existingCompany?.deletedAt) {
                    throw new common_1.BadRequestException(`Arsen company ${arsenName} matches a deleted PharmaFlow company.`);
                }
                const company = existingCompany ??
                    (await tx.company.create({
                        data: { name: arsenName },
                        select: { id: true, deletedAt: true },
                    }));
                const mapping = await tx.arsenCompanyMapping.create({
                    data: {
                        arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                        arsenName,
                        companyId: company.id,
                    },
                    select: { id: true },
                });
                await this.auditLog.record({
                    action: existingCompany
                        ? 'ARSEN_COMPANY_SYNC_MAP'
                        : 'ARSEN_COMPANY_SYNC_CREATE',
                    entityType: 'ARSEN_COMPANY_MAPPING',
                    entityId: mapping.id,
                    before: null,
                    after: {
                        arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                        arsenName,
                        companyId: company.id,
                        companyCreated: existingCompany == null,
                    },
                }, tx);
                return {
                    arsenBusinessPartnerId: source.arsenBusinessPartnerId,
                    status: existingCompany
                        ? 'MAPPED'
                        : 'CREATED',
                    companyId: company.id,
                };
            }));
        }
        return {
            processed: results.length,
            created: results.filter((item) => item.status === 'CREATED').length,
            mapped: results.filter((item) => item.status === 'MAPPED').length,
            updated: results.filter((item) => item.status === 'UPDATED').length,
            unchanged: results.filter((item) => item.status === 'UNCHANGED').length,
            results,
        };
    }
    async ingest(invoices) {
        const results = [];
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
    async ingestOne(invoice) {
        const detailIds = invoice.items.map((item) => item.arsenFactorDetailId);
        if (new Set(detailIds).size !== detailIds.length) {
            throw new common_1.BadRequestException(`Arsen factor ${invoice.arsenFactorId} contains duplicate detail IDs.`);
        }
        const mapping = await this.prisma.arsenCompanyMapping.findUnique({
            where: { arsenBusinessPartnerId: invoice.arsenBusinessPartnerId },
            select: {
                companyId: true,
                company: { select: { deletedAt: true } },
            },
        });
        if (!mapping || mapping.company.deletedAt) {
            throw new common_1.BadRequestException(`Arsen BusinessPartnerID ${invoice.arsenBusinessPartnerId} is not mapped to an active PharmaFlow company.`);
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
        if (before &&
            before.companyId === mapping.companyId &&
            before.sourceFingerprint === sourceFingerprint) {
            return {
                arsenFactorId: invoice.arsenFactorId,
                status: 'UNCHANGED',
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
            await this.auditLog.record({
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
            }, tx);
            return savedInvoice;
        });
        return {
            arsenFactorId: invoice.arsenFactorId,
            status: before ? 'UPDATED' : 'CREATED',
            invoiceId: saved.id,
        };
    }
};
exports.ArsenSyncService = ArsenSyncService;
exports.ArsenSyncService = ArsenSyncService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_log_service_1.AuditLogService])
], ArsenSyncService);
//# sourceMappingURL=arsen-sync.service.js.map