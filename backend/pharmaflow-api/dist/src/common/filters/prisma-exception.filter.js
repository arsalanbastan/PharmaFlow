"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const CHEQUE_PATCH_ROUTE_REGEX = /^\/api\/v1\/cheques\/[^/]+$/;
let PrismaExceptionFilter = class PrismaExceptionFilter {
    catch(exception, host) {
        const ctx = host.switchToHttp();
        const response = ctx.getResponse();
        const request = ctx.getRequest();
        if (request.method === 'PATCH' &&
            CHEQUE_PATCH_ROUTE_REGEX.test(request.originalUrl)) {
            console.error(JSON.stringify({
                responseStatus: exception.code === 'P2002' ? 409 : 500,
                exception: exception.name,
                file: 'src/common/filters/prisma-exception.filter.ts',
                method: 'catch',
                prismaErrorCode: exception.code,
            }));
        }
        if (exception.code === 'P2002') {
            throw new common_1.ConflictException('اطلاعات تکراری است');
        }
        response.status(500).json({
            statusCode: 500,
            message: 'Database error',
        });
    }
};
exports.PrismaExceptionFilter = PrismaExceptionFilter;
exports.PrismaExceptionFilter = PrismaExceptionFilter = __decorate([
    (0, common_1.Catch)(client_1.Prisma.PrismaClientKnownRequestError)
], PrismaExceptionFilter);
//# sourceMappingURL=prisma-exception.filter.js.map