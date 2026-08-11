import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import express from 'express';
import type { NextFunction, Request, Response } from 'express';
import { UpdateChequeDto } from './cheques/dto/update-cheque.dto';

const CHEQUE_PATCH_ROUTE_REGEX = /^\/api\/v1\/cheques\/[^/]+$/;

function isChequePatchRequest(request: Request): boolean {
  return (
    request.method === 'PATCH' &&
    CHEQUE_PATCH_ROUTE_REGEX.test(request.originalUrl)
  );
}

function extractChequePatchId(request: Request): string | null {
  const match = request.originalUrl.match(CHEQUE_PATCH_ROUTE_REGEX);

  if (!match) {
    return null;
  }

  return request.originalUrl.split('/').at(-1) ?? null;
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ limit: '10mb', extended: true }));
  app.use((request: Request, response: Response, next: NextFunction) => {
    if (isChequePatchRequest(request)) {
      const chequeId = extractChequePatchId(request);

      console.log(
        JSON.stringify({
          requestReceived: 'yes',
          responseStatus: null,
          exception: null,
          file: 'src/main.ts',
          method: 'chequePatchInstrumentationMiddleware',
          line: 39,
          incomingUrl: request.originalUrl,
          pathParameter: chequeId,
          requestBody: request.body,
        }),
      );

      response.on('finish', () => {
        console.log(
          JSON.stringify({
            requestReceived: 'yes',
            responseStatus: response.statusCode,
            exception: null,
            file: 'src/main.ts',
            method: 'chequePatchInstrumentationMiddleware.responseFinish',
            line: 58,
          }),
        );
      });
    }

    next();
  });
  app.use((request: Request, _response: Response, next: NextFunction) => {
    const contentLength = request.headers['content-length'] ?? 'unknown';

    console.log(
      `[HTTP] ${request.method} ${request.originalUrl} content-length=${contentLength}`,
    );

    next();
  });
app.useGlobalFilters(
  new PrismaExceptionFilter(),
);
app.useGlobalPipes(
  new ValidationPipe({
    whitelist: true,
    transform: true,
    exceptionFactory: (errors) => {
      const validationError = new BadRequestException(errors);

      const isChequeUpdateValidation = errors.some(
        (error) => error.target instanceof UpdateChequeDto,
      );

      if (!isChequeUpdateValidation) {
        return validationError;
      }

      console.error(
        JSON.stringify({
          requestReceived: 'yes',
          responseStatus: 400,
          exception: 'ValidationError[]',
          file: 'src/main.ts',
          method: 'validationExceptionFactory',
          line: 100,
          validationErrors: errors,
        }),
      );

      return validationError;
    },
  }),
);
  const config = new DocumentBuilder()
    .setTitle('PharmaFlow API')
    .setDescription('PharmaFlow Pharmacy Management System API')
    .setVersion('1.0')
    .build();

  const document = SwaggerModule.createDocument(
    app,
    config,
  );

  SwaggerModule.setup(
    'api/docs',
    app,
    document,
  );

  await app.listen(3000, '0.0.0.0');
}

bootstrap();