import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import express from 'express';
import type { NextFunction, Request, Response } from 'express';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import { AuditContextService } from './audit/audit-context.service';
import { decodeActorDisplayNameHeader } from './audit/audit-actor-header';
import { mountStaffWebAssets } from './staff-web/staff-web-assets';
import { ADMIN_DASHBOARD_RELEASE } from './admin/admin-view';

const DEFAULT_PORT = 3000;

function secureTextEquals(expected: string, actual: string): boolean {
  const expectedBuffer = Buffer.from(expected, 'utf8');
  const actualBuffer = Buffer.from(actual, 'utf8');

  if (expectedBuffer.length !== actualBuffer.length) {
    return false;
  }

  return timingSafeEqual(expectedBuffer, actualBuffer);
}

function adminBasicAuth(
  request: Request,
  response: Response,
  next: NextFunction,
): void {
  response.setHeader('X-PharmaFlow-Admin-Release', ADMIN_DASHBOARD_RELEASE);
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
    response.setHeader(
      'WWW-Authenticate',
      'Basic realm="PharmaFlow Admin", charset="UTF-8"',
    );

    response.status(401).send('Authentication required.');

    return;
  }

  let decoded = '';

  try {
    decoded = Buffer.from(
      authorization.slice('Basic '.length),
      'base64',
    ).toString('utf8');
  } catch {
    decoded = '';
  }

  const separator = decoded.indexOf(':');

  const username = separator >= 0 ? decoded.slice(0, separator) : '';

  const password = separator >= 0 ? decoded.slice(separator + 1) : '';

  const validUsername = secureTextEquals(expectedUsername, username);

  const validPassword = secureTextEquals(expectedPassword, password);

  if (!validUsername || !validPassword) {
    response.setHeader(
      'WWW-Authenticate',
      'Basic realm="PharmaFlow Admin", charset="UTF-8"',
    );

    response.status(401).send('Invalid credentials.');

    return;
  }

  next();
}

function parsePort(value: string | undefined): number {
  const parsedPort = Number.parseInt(value ?? '', 10);

  if (!Number.isInteger(parsedPort) || parsedPort <= 0 || parsedPort > 65535) {
    return DEFAULT_PORT;
  }

  return parsedPort;
}

function isSwaggerEnabled(): boolean {
  const nodeEnv = process.env.NODE_ENV?.trim().toLowerCase();

  if (nodeEnv !== 'production') {
    return true;
  }

  return process.env.ENABLE_SWAGGER?.trim().toLowerCase() === 'true';
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const auditContextService = app.get(AuditContextService);

  app.use('/admin', adminBasicAuth);
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ limit: '10mb', extended: true }));
  mountStaffWebAssets(app);

  app.use((request: Request, response: Response, next: NextFunction) => {
    const readHeader = (name: string): string | undefined => {
      const value = request.headers[name];

      if (Array.isArray(value)) {
        return value[0];
      }

      return typeof value === 'string' ? value : undefined;
    };

    const isAdminRequest =
      request.path === '/admin' || request.path.startsWith('/admin/');

    const isArsenSyncRequest = request.path.startsWith(
      '/api/v1/integrations/arsen/',
    );

    const source = isAdminRequest
      ? 'WEB_ADMIN'
      : isArsenSyncRequest
        ? 'ARSEN_BRIDGE'
        : request.path.startsWith('/api/v1/')
          ? 'MOBILE_APP'
          : 'SYSTEM';

    const actorDisplayName = isAdminRequest
      ? process.env.ADMIN_USERNAME?.trim() || undefined
      : decodeActorDisplayNameHeader(readHeader('x-pharmaflow-actor-name'));

    const deviceId =
      readHeader('x-pharmaflow-device-id')?.trim().slice(0, 200) || undefined;

    const requestId = (
      readHeader('x-request-id') ??
      readHeader('x-correlation-id') ??
      randomUUID()
    )
      .trim()
      .slice(0, 200);

    const forwardedFor = readHeader('x-forwarded-for');

    const ipAddress =
      forwardedFor?.split(',')[0]?.trim().slice(0, 200) || request.ip;

    response.setHeader('X-Request-Id', requestId);

    auditContextService.run(
      {
        source,
        actorDisplayName,
        actorUserId: undefined,
        actorVerified: isAdminRequest,
        deviceId,
        ipAddress,
        requestId,
      },
      () => next(),
    );
  });
  app.use((request: Request, response: Response, next: NextFunction) => {
    response.on('finish', () => {
      const correlationId =
        request.headers['x-request-id'] ?? request.headers['x-correlation-id'];
      const correlationSuffix = correlationId
        ? ` correlationId=${String(correlationId)}`
        : '';
      const category =
        response.statusCode >= 500 ? 'server_error' : 'request_completed';

      console.log(
        `[HTTP] ${request.method} ${request.originalUrl} status=${response.statusCode} category=${category}${correlationSuffix}`,
      );
    });

    next();
  });
  app.useGlobalFilters(new PrismaExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      exceptionFactory: (errors) => new BadRequestException(errors),
    }),
  );
  const config = new DocumentBuilder()
    .setTitle('PharmaFlow API')
    .setDescription('PharmaFlow Pharmacy Management System API')
    .setVersion('1.0')
    .build();

  if (isSwaggerEnabled()) {
    const document = SwaggerModule.createDocument(app, config);

    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(parsePort(process.env.PORT), '0.0.0.0');
}

bootstrap().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : 'Unknown bootstrap error';

  console.error(`[Startup] Bootstrap failed: ${message}`);
  process.exitCode = 1;
});
