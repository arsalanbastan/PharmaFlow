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
exports.SalesInvoicesService = void 0;
const client_1 = require("@prisma/client");
const common_1 = require("@nestjs/common");
const audit_log_service_1 = require("../audit/audit-log.service");
const prisma_service_1 = require("../database/prisma/prisma.service");
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PAGE_SIZES = new Set([25, 50, 100]);
let SalesInvoicesService = class SalesInvoicesService {
    prisma;
    auditLog;
    constructor(prisma, auditLog) {
        this.prisma = prisma;
        this.auditLog = auditLog;
    }
    profile() {
        return this.prisma.salesInvoiceProfile.upsert({
            where: { id: 'default' },
            create: { id: 'default', sellerName: 'داروخانه دکتر خسروانی' },
            update: {},
        });
    }
    updateProfile(dto) {
        const sellerName = dto.sellerName.trim();
        if (sellerName.length === 0) {
            throw new common_1.BadRequestException('sellerName is required.');
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
    async findAll(filters = {}) {
        const page = this.positiveInteger(filters.page, 'page') ?? 1;
        const pageSize = this.pageSize(filters.pageSize);
        const q = filters.q?.trim();
        const where = q
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
    async findOne(id) {
        const normalized = id.trim();
        if (!UUID_PATTERN.test(normalized)) {
            throw new common_1.BadRequestException('Invalid sales invoice id.');
        }
        const invoice = await this.prisma.salesInvoice.findUnique({
            where: { id: normalized },
            include: { items: { orderBy: { createdAt: 'asc' } } },
        });
        if (invoice == null) {
            throw new common_1.NotFoundException('Sales invoice not found.');
        }
        return this.serializeInvoice(invoice);
    }
    async create(dto) {
        const buyerName = dto.buyerName.trim();
        if (buyerName.length === 0) {
            throw new common_1.BadRequestException('buyerName is required.');
        }
        const catalogIds = dto.items.map((item) => item.catalogItemId);
        if (new Set(catalogIds).size !== catalogIds.length) {
            throw new common_1.BadRequestException('Duplicate catalog items are not allowed in one invoice.');
        }
        const [profile, catalogItems] = await Promise.all([
            this.profile(),
            this.prisma.arsenCatalogItem.findMany({
                where: { id: { in: catalogIds }, isActive: true },
            }),
        ]);
        if (catalogItems.length !== catalogIds.length) {
            throw new common_1.BadRequestException('One or more selected catalog items are unavailable.');
        }
        const byId = new Map(catalogItems.map((item) => [item.id, item]));
        let subtotal = new client_1.Prisma.Decimal(0);
        const items = dto.items.map((requested) => {
            const catalog = byId.get(requested.catalogItemId);
            const quantity = new client_1.Prisma.Decimal(requested.quantity);
            const unitPrice = new client_1.Prisma.Decimal(requested.unitPrice);
            const lineDiscount = new client_1.Prisma.Decimal(requested.lineDiscount ?? 0);
            const gross = quantity.mul(unitPrice);
            if (lineDiscount.gt(gross)) {
                throw new common_1.BadRequestException('An item discount cannot exceed its gross amount.');
            }
            const lineTotal = gross.minus(lineDiscount);
            subtotal = subtotal.plus(lineTotal);
            const itemName = catalog.persianName?.trim() ||
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
        const discount = new client_1.Prisma.Decimal(dto.discount ?? 0);
        if (discount.gt(subtotal)) {
            throw new common_1.BadRequestException('Invoice discount cannot exceed the subtotal.');
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
            await this.auditLog.record({
                action: 'CREATE_SALES_INVOICE',
                entityType: 'SALES_INVOICE',
                entityId: updated.id,
                after: {
                    invoiceNumber,
                    buyerName,
                    payableAmount: payableAmount.toString(),
                    itemCount: items.length,
                },
            }, tx);
            return this.serializeInvoice(updated);
        });
    }
    serializeInvoice(invoice) {
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
    optional(value) {
        const normalized = value?.trim();
        return normalized == null || normalized.length === 0 ? null : normalized;
    }
    positiveInteger(raw, field) {
        const normalized = raw?.trim();
        if (normalized == null || normalized.length === 0) {
            return null;
        }
        if (!/^\d+$/.test(normalized)) {
            throw new common_1.BadRequestException(`${field} must be a positive integer.`);
        }
        const value = Number(normalized);
        if (!Number.isSafeInteger(value) || value < 1) {
            throw new common_1.BadRequestException(`${field} must be a positive integer.`);
        }
        return value;
    }
    pageSize(raw) {
        const value = this.positiveInteger(raw, 'pageSize') ?? 25;
        if (!PAGE_SIZES.has(value)) {
            throw new common_1.BadRequestException('pageSize must be one of 25, 50, or 100.');
        }
        return value;
    }
};
exports.SalesInvoicesService = SalesInvoicesService;
exports.SalesInvoicesService = SalesInvoicesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_log_service_1.AuditLogService])
], SalesInvoicesService);
//# sourceMappingURL=sales-invoices.service.js.map