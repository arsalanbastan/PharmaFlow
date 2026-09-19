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
var ChequesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChequesService = void 0;
const common_1 = require("@nestjs/common");
const audit_log_service_1 = require("../audit/audit-log.service");
const prisma_service_1 = require("../database/prisma/prisma.service");
const push_outbox_service_1 = require("../push/push-outbox.service");
const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
let ChequesService = ChequesService_1 = class ChequesService {
    prisma;
    auditLog;
    constructor(prisma, auditLog) {
        this.prisma = prisma;
        this.auditLog = auditLog;
    }
    logger = new common_1.Logger(ChequesService_1.name);
    async prepareDuplicateWarningContext(bankAccountId, chequeNumber, excludeId) {
        return this.prisma.cheque.findMany({
            where: {
                bankAccountId,
                chequeNumber,
                deletedAt: null,
                ...(excludeId
                    ? {
                        id: {
                            not: excludeId,
                        },
                    }
                    : {}),
            },
            orderBy: {
                createdAt: 'desc',
            },
            select: {
                id: true,
                chequeNumber: true,
                amount: true,
                chequeDate: true,
                companyId: true,
                bankAccountId: true,
            },
        });
    }
    async create(createChequeDto) {
        await this.prepareDuplicateWarningContext(createChequeDto.bankAccountId, createChequeDto.chequeNumber);
        const requestedId = createChequeDto.id?.trim() || undefined;
        const data = {
            chequeNumber: createChequeDto.chequeNumber,
            amount: createChequeDto.amount,
            chequeDate: new Date(createChequeDto.chequeDate),
            ...(createChequeDto.dueDate
                ? { dueDate: new Date(createChequeDto.dueDate) }
                : {}),
            companyId: createChequeDto.companyId,
            bankAccountId: createChequeDto.bankAccountId,
            sayadStatus: createChequeDto.sayadStatus,
            status: createChequeDto.status,
            isRegisteredInSayad: createChequeDto.isRegisteredInSayad,
            sayadId: createChequeDto.sayadId,
            imagePath: createChequeDto.imagePath,
            imageData: createChequeDto.imageData,
            description: createChequeDto.description,
            archivedAt: createChequeDto.archivedAt,
        };
        if (requestedId == null) {
            return this.prisma.$transaction(async (tx) => {
                const created = await tx.cheque.create({
                    data,
                });
                await this.auditLog.record({
                    action: 'CREATE',
                    entityType: 'CHEQUE',
                    entityId: created.id,
                    after: created,
                }, tx);
                await (0, push_outbox_service_1.enqueueChequeCreatedPush)(created.id, tx);
                return created;
            });
        }
        return this.prisma.$transaction(async (tx) => {
            const previous = await tx.cheque.findUnique({
                where: {
                    id: requestedId,
                },
            });
            const result = await tx.cheque.upsert({
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
                entityType: 'CHEQUE',
                entityId: result.id,
                before: previous,
                after: result,
            }, tx);
            if (previous == null) {
                await (0, push_outbox_service_1.enqueueChequeCreatedPush)(result.id, tx);
            }
            return result;
        });
    }
    async findAll() {
        return this.prisma.cheque.findMany({
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
        const rows = await this.prisma.cheque.findMany({
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
        return this.prisma.cheque.findFirst({
            where: {
                id,
                deletedAt: null,
            },
        });
    }
    async update(id, updateChequeDto) {
        const existingCheque = await this.prisma.cheque.findFirst({
            where: {
                id,
                deletedAt: null,
            },
        });
        if (existingCheque) {
            await this.prepareDuplicateWarningContext(updateChequeDto.bankAccountId ?? existingCheque.bankAccountId, updateChequeDto.chequeNumber ?? existingCheque.chequeNumber, id);
        }
        const prismaUpdateInput = {
            where: {
                id,
            },
            data: {
                ...updateChequeDto,
                ...(updateChequeDto.chequeDate
                    ? {
                        chequeDate: new Date(updateChequeDto.chequeDate),
                    }
                    : {}),
                ...(updateChequeDto.dueDate
                    ? {
                        dueDate: new Date(updateChequeDto.dueDate),
                    }
                    : {}),
            },
        };
        return this.prisma.$transaction(async (tx) => {
            const previous = await tx.cheque.findUnique({
                where: {
                    id,
                },
            });
            const updated = await tx.cheque.update(prismaUpdateInput);
            await this.auditLog.record({
                action: 'UPDATE',
                entityType: 'CHEQUE',
                entityId: updated.id,
                before: previous,
                after: updated,
            }, tx);
            return updated;
        });
    }
    async remove(uuid) {
        const existingCheque = await this.prisma.cheque.findFirst({
            where: {
                id: uuid,
                deletedAt: null,
            },
        });
        if (!existingCheque) {
            this.logger.warn(JSON.stringify({
                event: 'cheque.delete',
                chequeUuid: uuid,
                previousState: null,
                newState: null,
                timestamp: new Date().toISOString(),
                outcome: 'not_found',
            }));
            throw new common_1.NotFoundException('Cheque not found');
        }
        const now = new Date();
        const deletedCheque = await this.prisma.$transaction(async (tx) => {
            const deleted = await tx.cheque.update({
                where: {
                    id: uuid,
                },
                data: {
                    archivedAt: now,
                    deletedAt: now,
                },
            });
            await this.auditLog.record({
                action: 'DELETE',
                entityType: 'CHEQUE',
                entityId: deleted.id,
                before: existingCheque,
                after: deleted,
            }, tx);
            return deleted;
        });
        this.logger.log(JSON.stringify({
            event: 'cheque.delete',
            chequeUuid: uuid,
            previousState: {
                id: existingCheque.id,
                archivedAt: existingCheque.archivedAt,
                deletedAt: existingCheque.deletedAt,
                status: existingCheque.status,
                updatedAt: existingCheque.updatedAt,
            },
            newState: {
                id: deletedCheque.id,
                archivedAt: deletedCheque.archivedAt,
                deletedAt: deletedCheque.deletedAt,
                status: deletedCheque.status,
                updatedAt: deletedCheque.updatedAt,
            },
            timestamp: now.toISOString(),
            outcome: 'soft_deleted',
        }));
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
exports.ChequesService = ChequesService;
exports.ChequesService = ChequesService = ChequesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_log_service_1.AuditLogService])
], ChequesService);
//# sourceMappingURL=cheques.service.js.map