import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { ArsenSyncController } from './arsen-sync.controller';
import { ArsenSyncErrorsController } from './arsen-sync-errors.controller';
import { ArsenSyncGuard } from './arsen-sync.guard';
import { ArsenSyncService } from './arsen-sync.service';

@Module({
  imports: [AuthModule],
  controllers: [ArsenSyncController, ArsenSyncErrorsController],
  providers: [ArsenSyncGuard, ArsenSyncService],
})
export class ArsenSyncModule {}
