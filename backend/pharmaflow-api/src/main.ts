import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import express from 'express';
import type { NextFunction, Request, Response } from 'express';

const DEFAULT_PORT = 3000;

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
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ limit: '10mb', extended: true }));
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
  const message = error instanceof Error ? error.message : 'Unknown bootstrap error';

  console.error(`[Startup] Bootstrap failed: ${message}`);
  process.exitCode = 1;
});