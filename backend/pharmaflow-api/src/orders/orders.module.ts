import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { PushModule } from '../push/push.module';
import { OrdersController } from './orders.controller';
import { OrderPhotoStorageService } from './order-photo-storage.service';
import { OrdersAvailabilityGuard } from './orders-availability.guard';
import { OrdersService } from './orders.service';

@Module({
  imports: [AuthModule, PushModule],
  controllers: [OrdersController],
  providers: [OrdersService, OrderPhotoStorageService, OrdersAvailabilityGuard],
  exports: [OrdersService],
})
export class OrdersModule {}
