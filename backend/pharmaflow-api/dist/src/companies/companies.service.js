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
exports.CompaniesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const audit_log_service_1 = require("../audit/audit-log.service");
const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let CompaniesService = class CompaniesService {
    prisma;
    auditLog;
    constructor(prisma, auditLog) {
        this.prisma = prisma;
        this.auditLog = auditLog;
    }
    async create(createCompanyDto) {
        const requestedId = createCompanyDto.id?.trim() || undefined;
        const data = {
            name: createCompanyDto.name,
            nationalId: createCompanyDto.nationalId,
            economicCode: createCompanyDto.economicCode,
            bankName: createCompanyDto.bankName,
            accountNumber: createCompanyDto.accountNumber,
            cardNumber: createCompanyDto.cardNumber,
            shebaNumber: createCompanyDto.shebaNumber,
            notes: createCompanyDto.notes,
            visitorName: createCompanyDto.visitorName,
            visitorPhone: createCompanyDto.visitorPhone,
            accountantName: createCompanyDto.accountantName,
            accountantPhone: createCompanyDto.accountantPhone,
            archivedAt: createCompanyDto.archivedAt,
        };
        if (requestedId == null) {
            return this.prisma.$transaction(async (tx) => {
                const created = await tx.company.create({
                    data,
                });
                await this.auditLog.record({
                    action: 'CREATE',
                    entityType: 'COMPANY',
                    entityId: created.id,
                    after: created,
                }, tx);
                return created;
            });
        }
        return this.prisma.$transaction(async (tx) => {
            const previous = await tx.company.findUnique({
                where: {
                    id: requestedId,
                },
            });
            const result = await tx.company.upsert({
                where: {
                    id: requestedId,
                },
                create: {
                    id: requestedId,
                    ...data,
                },
                update: data,
            });
            await this.auditLog.record({
                action: previous == null ? 'CREATE' : 'UPDATE',
                entityType: 'COMPANY',
                entityId: result.id,
                before: previous,
                after: result,
            }, tx);
            return result;
        });
    }
    async findAll() {
        return this.prisma.company.findMany({
            where: {
                deletedAt: null,
            },
            orderBy: {
                createdAt: 'desc',
            },
        });
    }
    async findChanges(query) {
        const updatedAfterText = query.updatedAfter?.trim() || undefined;
        const afterId = query.afterId?.trim() || undefined;
        if ((updatedAfterText == null) !== (afterId == null)) {
            throw new common_1.BadRequestException('updatedAfter and afterId must be provided together.');
        }
        let updatedAfter;
        if (updatedAfterText != null) {
            updatedAfter = new Date(updatedAfterText);
            if (Number.isNaN(updatedAfter.getTime())) {
                throw new common_1.BadRequestException('updatedAfter must be a valid ISO-8601 date.');
            }
            if (afterId == null || !UUID_PATTERN.test(afterId)) {
                throw new common_1.BadRequestException('afterId must be a valid UUID.');
            }
        }
        const limit = this.parseChangesLimit(query.limit);
        const where = updatedAfter != null && afterId != null
            ? {
                OR: [
                    {
                        updatedAt: {
                            gt: updatedAfter,
                        },
                    },
                    {
                        updatedAt: updatedAfter,
                        id: {
                            gt: afterId,
                        },
                    },
                ],
            }
            : undefined;
        const rows = await this.prisma.company.findMany({
            where,
            orderBy: [
                {
                    updatedAt: 'asc',
                },
                {
                    id: 'asc',
                },
            ],
            take: limit + 1,
        });
        const hasMore = rows.length > limit;
        const items = hasMore ? rows.slice(0, limit) : rows;
        const lastItem = items.length > 0 ? items[items.length - 1] : null;
        const nextCursor = lastItem != null
            ? {
                updatedAt: lastItem.updatedAt.toISOString(),
                id: lastItem.id,
            }
            : updatedAfter != null && afterId != null
                ? {
                    updatedAt: updatedAfter.toISOString(),
                    id: afterId,
                }
                : null;
        return {
            items,
            hasMore,
            nextCursor,
        };
    }
    async findOne(id) {
        return this.prisma.company.findFirst({
            where: {
                id,
                deletedAt: null,
            },
        });
    }
    async update(id, updateCompanyDto) {
        return this.prisma.$transaction(async (tx) => {
            const previous = await tx.company.findUnique({
                where: {
                    id,
                },
            });
            const updated = await tx.company.update({
                where: {
                    id,
                },
                data: updateCompanyDto,
            });
            await this.auditLog.record({
                action: 'UPDATE',
                entityType: 'COMPANY',
                entityId: updated.id,
                before: previous,
                after: updated,
            }, tx);
            return updated;
        });
    }
    async remove(id) {
        return this.prisma.$transaction(async (tx) => {
            const previous = await tx.company.findUnique({
                where: {
                    id,
                },
            });
            const deleted = await tx.company.update({
                where: {
                    id,
                },
                data: {
                    deletedAt: new Date(),
                },
            });
            await this.auditLog.record({
                action: 'DELETE',
                entityType: 'COMPANY',
                entityId: deleted.id,
                before: previous,
                after: deleted,
            }, tx);
            return deleted;
        });
    }
    parseChangesLimit(rawLimit) {
        if (rawLimit == null || rawLimit.trim().length === 0) {
            return DEFAULT_CHANGES_LIMIT;
        }
        const parsed = Number(rawLimit);
        if (!Number.isInteger(parsed) || parsed <= 0) {
            throw new common_1.BadRequestException('limit must be a positive integer.');
        }
        return Math.min(parsed, MAX_CHANGES_LIMIT);
    }
};
exports.CompaniesService = CompaniesService;
exports.CompaniesService = CompaniesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_log_service_1.AuditLogService])
], CompaniesService);
//# sourceMappingURL=companies.service.js.map