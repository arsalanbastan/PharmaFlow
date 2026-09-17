import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PushController } from './push.controller';
import { FirebasePushSenderService } from './firebase-push-sender.service';
import { PushWorkerService } from './push-worker.service';
import { PushDeviceService } from './push-device.service';
import { PushOutboxService } from './push-outbox.service';

@Module({
  imports: [AuthModule],
  controllers: [PushController],
  providers: [
    PushDeviceService,
    PushOutboxService,
    FirebasePushSenderService,
    PushWorkerService,
  ],
  exports: [PushOutboxService],
})
export class PushModule {}
