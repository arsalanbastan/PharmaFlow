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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.HealthController = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
const SERVICE_NAME = 'pharmaflow-api';
const API_VERSION = '1.0.0';
let HealthController = class HealthController {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async check(response) {
        const serverTime = new Date().toISOString();
        const environment = process.env.NODE_ENV?.trim() || 'development';
        try {
            await this.prisma.$queryRaw `SELECT 1`;
            response.status(200);
            return {
                status: 'ok',
                service: SERVICE_NAME,
                version: API_VERSION,
                environment,
                database: {
                    status: 'connected',
                },
                serverTime,
                timestamp: serverTime,
            };
        }
        catch (error) {
            response.status(503);
            return {
                status: 'degraded',
                service: SERVICE_NAME,
                version: API_VERSION,
                environment,
                database: {
                    status: 'error',
                },
                serverTime,
                timestamp: serverTime,
            };
        }
    }
};
exports.HealthController = HealthController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Res)({ passthrough: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], HealthController.prototype, "check", null);
exports.HealthController = HealthController = __decorate([
    (0, common_1.Controller)('api/v1/health'),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], HealthController);
//# sourceMappingURL=health.controller.js.map