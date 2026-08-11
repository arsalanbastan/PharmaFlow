import {
  ArgumentsHost,
  Catch,
  ConflictException,
  ExceptionFilter,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Request } from 'express';

const CHEQUE_PATCH_ROUTE_REGEX = /^\/api\/v1\/cheques\/[^/]+$/;

@Catch(Prisma.PrismaClientKnownRequestError)
export class PrismaExceptionFilter
  implements ExceptionFilter
{
  catch(
    exception: Prisma.PrismaClientKnownRequestError,
    host: ArgumentsHost,
  ) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest<Request>();

    if (
      request.method === 'PATCH' &&
      CHEQUE_PATCH_ROUTE_REGEX.test(request.originalUrl)
    ) {
      console.error(
        JSON.stringify({
          requestReceived: 'yes',
          responseStatus: exception.code === 'P2002' ? 409 : 500,
          exception: exception.name,
          file: 'src/common/filters/prisma-exception.filter.ts',
          method: 'catch',
          line: 30,
          prismaErrorCode: exception.code,
          prismaErrorMessage: exception.message,
          stackTrace: exception.stack,
        }),
      );
    }

    if (exception.code === 'P2002') {
      throw new ConflictException(
        'اطلاعات تکراری است',
      );
    }

    response.status(500).json({
      statusCode: 500,
      message: 'Database error',
    });
  }
}