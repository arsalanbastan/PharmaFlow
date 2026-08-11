import {
  BadRequestException,
  Body,
  CallHandler,
  Controller,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  Post,
  Req,
  UseInterceptors,
} from '@nestjs/common';
import type { Request } from 'express';
import { SyncService } from './sync.service';
import { SyncChequesDto } from './dto/sync-cheques.dto';
import { catchError, tap, throwError } from 'rxjs';
import { sanitizeLogBody } from '../common/logging/sanitize-log-body';

type SyncDebugRequest = Request & {
  __syncControllerReached?: boolean;
};

@Injectable()
class SyncDebugInterceptor implements NestInterceptor {
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ) {
    const request = context.switchToHttp().getRequest<SyncDebugRequest>();
    request.__syncControllerReached = false;

    console.log('[SyncDebug] Request entered sync endpoint pipeline');
    console.log(
      '[SyncDebug] Received request body:',
      JSON.stringify(sanitizeLogBody(request.body), null, 2),
    );

    return next.handle().pipe(
      tap(() => {
        console.log(
          '[SyncDebug] Controller reached:',
          request.__syncControllerReached === true,
        );
      }),
      catchError((error: unknown) => {
        console.error(
          '[SyncDebug] Controller reached:',
          request.__syncControllerReached === true,
        );

        if (error instanceof BadRequestException) {
          console.error(
            '[SyncDebug] BadRequestException response body:',
            JSON.stringify(sanitizeLogBody(error.getResponse()), null, 2),
          );
        }

        console.error(
          '[SyncDebug] Exception stack trace:',
          error instanceof Error ? error.stack : error,
        );

        return throwError(() => error);
      }),
    );
  }
}

@Controller('api/v1/sync/cheques')
@UseInterceptors(SyncDebugInterceptor)
export class SyncController {
  constructor(
    private readonly syncService: SyncService,
  ) {}

  @Post()
  async syncCheques(
    @Req() request: SyncDebugRequest,
    @Body() syncChequesDto: SyncChequesDto,
  ) {
    request.__syncControllerReached = true;

    console.log('[SyncDebug] Controller reached: true');
    console.log(
      '[SyncDebug] Validated DTO body:',
      JSON.stringify(sanitizeLogBody(syncChequesDto), null, 2),
    );

    try {
      return await this.syncService.syncCheques(syncChequesDto);
    } catch (error: unknown) {
      console.error(
        '[SyncDebug] Exception stack trace:',
        error instanceof Error ? error.stack : error,
      );
      throw error;
    }
  }
}