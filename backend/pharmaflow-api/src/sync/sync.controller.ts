import {
  Body,
  Controller,
  Post,
} from '@nestjs/common';
import { SyncService } from './sync.service';
import { SyncChequesDto } from './dto/sync-cheques.dto';

const isSyncDebugLoggingEnabled =
  process.env.SYNC_DEBUG_LOGGING?.trim().toLowerCase() === 'true';

@Controller('api/v1/sync/cheques')
export class SyncController {
  constructor(
    private readonly syncService: SyncService,
  ) {}

  @Post()
  async syncCheques(
    @Body() syncChequesDto: SyncChequesDto,
  ) {
    if (isSyncDebugLoggingEnabled) {
      console.log('[SyncDebug] Sync cheques request accepted');
    }

    try {
      return await this.syncService.syncCheques(syncChequesDto);
    } catch (error: unknown) {
      if (isSyncDebugLoggingEnabled) {
        console.error(
          '[SyncDebug] Sync cheques request failed:',
          error instanceof Error ? error.name : 'UnknownError',
        );
      }

      throw error;
    }
  }
}