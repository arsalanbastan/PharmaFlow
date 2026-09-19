"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const swagger_1 = require("@nestjs/swagger");
const app_module_1 = require("./app.module");
const common_1 = require("@nestjs/common");
const prisma_exception_filter_1 = require("./common/filters/prisma-exception.filter");
const express_1 = __importDefault(require("express"));
const node_crypto_1 = require("node:crypto");
const audit_context_service_1 = require("./audit/audit-context.service");
const audit_actor_header_1 = require("./audit/audit-actor-header");
const staff_web_assets_1 = require("./staff-web/staff-web-assets");
const admin_view_1 = require("./admin/admin-view");
const DEFAULT_PORT = 3000;
function secureTextEquals(expected, actual) {
    const expectedBuffer = Buffer.from(expected, 'utf8');
    const actualBuffer = Buffer.from(actual, 'utf8');
    if (expectedBuffer.length !== actualBuffer.length) {
        return false;
    }
    return (0, node_crypto_1.timingSafeEqual)(expectedBuffer, actualBuffer);
}
function adminBasicAuth(request, response, next) {
    response.setHeader('X-PharmaFlow-Admin-Release', admin_view_1.ADMIN_DASHBOARD_RELEASE);
    response.setHeader('Cache-Control', 'no-store, max-age=0');
    const expectedUsername = process.env.ADMIN_USERNAME?.trim();
    const expectedPassword = process.env.ADMIN_PASSWORD ?? '';
    if (!expectedUsername || !expectedPassword) {
        response
            .status(503)
            .type('text/plain')
            .send('PharmaFlow Admin is not configured.');
        return;
    }
    const authorization = request.headers.authorization ?? '';
    if (!authorization.startsWith('Basic ')) {
        response.setHeader('WWW-Authenticate', 'Basic realm="PharmaFlow Admin", charset="UTF-8"');
        response.status(401).send('Authentication required.');
        return;
    }
    let decoded = '';
    try {
        decoded = Buffer.from(authorization.slice('Basic '.length), 'base64').toString('utf8');
    }
    catch {
        decoded = '';
    }
    const separator = decoded.indexOf(':');
    const username = separator >= 0 ? decoded.slice(0, separator) : '';
    const password = separator >= 0 ? decoded.slice(separator + 1) : '';
    const validUsername = secureTextEquals(expectedUsername, username);
    const validPassword = secureTextEquals(expectedPassword, password);
    if (!validUsername || !validPassword) {
        response.setHeader('WWW-Authenticate', 'Basic realm="PharmaFlow Admin", charset="UTF-8"');
        response.status(401).send('Invalid credentials.');
        return;
    }
    next();
}
function parsePort(value) {
    const parsedPort = Number.parseInt(value ?? '', 10);
    if (!Number.isInteger(parsedPort) || parsedPort <= 0 || parsedPort > 65535) {
        return DEFAULT_PORT;
    }
    return parsedPort;
}
function isSwaggerEnabled() {
    const nodeEnv = process.env.NODE_ENV?.trim().toLowerCase();
    if (nodeEnv !== 'production') {
        return true;
    }
    return process.env.ENABLE_SWAGGER?.trim().toLowerCase() === 'true';
}
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    const auditContextService = app.get(audit_context_service_1.AuditContextService);
    app.use('/admin', adminBasicAuth);
    app.use(express_1.default.json({ limit: '10mb' }));
    app.use(express_1.default.urlencoded({ limit: '10mb', extended: true }));
    (0, staff_web_assets_1.mountStaffWebAssets)(app);
    app.use((request, response, next) => {
        const readHeader = (name) => {
            const value = request.headers[name];
            if (Array.isArray(value)) {
                return value[0];
            }
            return typeof value === 'string' ? value : undefined;
        };
        const isAdminRequest = request.path === '/admin' || request.path.startsWith('/admin/');
        const isArsenSyncRequest = request.path.startsWith('/api/v1/integrations/arsen/');
        const source = isAdminRequest
            ? 'WEB_ADMIN'
            : isArsenSyncRequest
                ? 'ARSEN_BRIDGE'
                : request.path.startsWith('/api/v1/')
                    ? 'MOBILE_APP'
                    : 'SYSTEM';
        const actorDisplayName = isAdminRequest
            ? process.env.ADMIN_USERNAME?.trim() || undefined
            : (0, audit_actor_header_1.decodeActorDisplayNameHeader)(readHeader('x-pharmaflow-actor-name'));
        const deviceId = readHeader('x-pharmaflow-device-id')?.trim().slice(0, 200) || undefined;
        const requestId = (readHeader('x-request-id') ??
            readHeader('x-correlation-id') ??
            (0, node_crypto_1.randomUUID)())
            .trim()
            .slice(0, 200);
        const forwardedFor = readHeader('x-forwarded-for');
        const ipAddress = forwardedFor?.split(',')[0]?.trim().slice(0, 200) || request.ip;
        response.setHeader('X-Request-Id', requestId);
        auditContextService.run({
            source,
            actorDisplayName,
            actorUserId: undefined,
            actorVerified: isAdminRequest,
            deviceId,
            ipAddress,
            requestId,
        }, () => next());
    });
    app.use((request, response, next) => {
        response.on('finish', () => {
            const correlationId = request.headers['x-request-id'] ?? request.headers['x-correlation-id'];
            const correlationSuffix = correlationId
                ? ` correlationId=${String(correlationId)}`
                : '';
            const category = response.statusCode >= 500 ? 'server_error' : 'request_completed';
            console.log(`[HTTP] ${request.method} ${request.originalUrl} status=${response.statusCode} category=${category}${correlationSuffix}`);
        });
        next();
    });
    app.useGlobalFilters(new prisma_exception_filter_1.PrismaExceptionFilter());
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        exceptionFactory: (errors) => new common_1.BadRequestException(errors),
    }));
    const config = new swagger_1.DocumentBuilder()
        .setTitle('PharmaFlow API')
        .setDescription('PharmaFlow Pharmacy Management System API')
        .setVersion('1.0')
        .build();
    if (isSwaggerEnabled()) {
        const document = swagger_1.SwaggerModule.createDocument(app, config);
        swagger_1.SwaggerModule.setup('api/docs', app, document);
    }
    await app.listen(parsePort(process.env.PORT), '0.0.0.0');
}
bootstrap().catch((error) => {
    const message = error instanceof Error ? error.message : 'Unknown bootstrap error';
    console.error(`[Startup] Bootstrap failed: ${message}`);
    process.exitCode = 1;
});
//# sourceMappingURL=main.js.map