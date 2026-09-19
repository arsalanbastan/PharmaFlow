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
exports.AuditLogService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const audit_context_service_1 = require("./audit-context.service");
let AuditLogService = class AuditLogService {
    prisma;
    context;
    constructor(prisma, context) {
        this.prisma = prisma;
        this.context = context;
    }
    async record(input, database) {
        const requestContext = this.context.get();
        const db = database ?? this.prisma;
        const beforeData = this.sanitize(input.before);
        const afterData = this.sanitize(input.after);
        return db.auditLog.create({
            data: {
                source: requestContext?.source ?? 'SYSTEM',
                actorDisplayName: this.cleanText(requestContext?.actorDisplayName, 160),
                actorUserId: requestContext?.actorUserId ?? null,
                actorVerified: requestContext?.actorVerified ?? false,
                deviceId: this.cleanText(requestContext?.deviceId, 200),
                action: input.action,
                entityType: input.entityType,
                entityId: this.cleanText(input.entityId ?? undefined, 200),
                ...(beforeData !== undefined ? { beforeData } : {}),
                ...(afterData !== undefined ? { afterData } : {}),
                ipAddress: this.cleanText(requestContext?.ipAddress, 200),
                requestId: this.cleanText(requestContext?.requestId, 200),
            },
        });
    }
    async findRecent(query = '') {
        const rows = await this.prisma.auditLog.findMany({
            orderBy: {
                createdAt: 'desc',
            },
            take: 500,
        });
        const q = query.trim().toLowerCase();
        if (!q) {
            return rows;
        }
        return rows.filter((item) => [
            item.source,
            item.actorDisplayName,
            item.deviceId,
            item.action,
            item.entityType,
            item.entityId,
            item.ipAddress,
            item.requestId,
        ].some((value) => String(value ?? '')
            .toLowerCase()
            .includes(q)));
    }
    cleanText(value, maxLength) {
        const text = String(value ?? '').trim();
        if (!text) {
            return null;
        }
        return text.slice(0, maxLength);
    }
    sanitize(value) {
        if (value === undefined || value === null) {
            return undefined;
        }
        const json = JSON.stringify(value, (key, item) => {
            const normalizedKey = String(key).toLowerCase();
            if (normalizedKey.includes('password') ||
                normalizedKey.includes('token') ||
                normalizedKey.includes('secret')) {
                return '[REDACTED]';
            }
            if (key === 'imageData') {
                if (item == null || item === '') {
                    return null;
                }
                return {
                    present: true,
                    length: String(item).length,
                };
            }
            if (typeof item === 'bigint') {
                return item.toString();
            }
            return item;
        });
        if (!json) {
            return undefined;
        }
        return JSON.parse(json);
    }
};
exports.AuditLogService = AuditLogService;
exports.AuditLogService = AuditLogService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_context_service_1.AuditContextService])
], AuditLogService);
//# sourceMappingURL=audit-log.service.js.map