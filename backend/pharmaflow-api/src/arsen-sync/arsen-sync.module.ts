import { Module } from '@nestjs/common';

import { ArsenSyncController } from './arsen-sync.controller';
import { ArsenSyncGuard } from './arsen-sync.guard';
import { ArsenSyncService } from './arsen-sync.service';

@Module({
  controllers: [ArsenSyncController],
  providers: [ArsenSyncGuard, ArsenSyncService],
})
export class ArsenSyncModule {}
