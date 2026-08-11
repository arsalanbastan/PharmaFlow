import {
  Injectable,
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate, ValidationError } from 'class-validator';
import type { NextFunction, Request, Response } from 'express';
import { PrismaModule } from '../database/prisma/prisma.module';
import { SyncController } from './sync.controller';
import { SyncChequesDto } from './dto/sync-cheques.dto';
import { SyncService } from './sync.service';
import { sanitizeLogBody } from '../common/logging/sanitize-log-body';

type ValidationFailure = {
  field: string;
  messages: string[];
};

function flattenValidationErrors(
  errors: ValidationError[],
  parentPath = '',
): ValidationFailure[] {
  return errors.flatMap((error) => {
    const currentPath = parentPath
      ? `${parentPath}.${error.property}`
      : error.property;
    const failures: ValidationFailure[] = [];

    if (error.constraints) {
      failures.push({
        field: currentPath,
        messages: Object.values(error.constraints),
      });
    }

    if (error.children?.length) {
      failures.push(...flattenValidationErrors(error.children, currentPath));
    }

    return failures;
  });
}

@Injectable()
class SyncValidationDebugMiddleware {
  async use(
    request: Request,
    _response: Response,
    next: NextFunction,
  ) {
    const payload = plainToInstance(SyncChequesDto, request.body);
    const errors = await validate(payload, {
      whitelist: true,
    });

    if (errors.length > 0) {
      const failures = flattenValidationErrors(errors);

      console.error(
        '[SyncDebug] DTO validation errors:',
        JSON.stringify(sanitizeLogBody(errors), null, 2),
      );
      console.error(
        '[SyncDebug] Validation failure fields:',
        JSON.stringify(sanitizeLogBody(failures), null, 2),
      );

      for (const failure of failures) {
        console.error(
          `[SyncDebug] Validation failed at ${failure.field}: ${failure.messages.join('; ')}`,
        );
      }
    }

    next();
  }
}

@Module({
  imports: [PrismaModule],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(SyncValidationDebugMiddleware)
      .forRoutes({
        path: 'api/v1/sync/cheques',
        method: RequestMethod.POST,
      });
  }
}