import { Module } from '@nestjs/common';

import { StaffAppUpdateController } from './staff-app-update.controller';
import { StaffAppUpdateService } from './staff-app-update.service';
import { StaffAppUpdateStorageService } from './staff-app-update-storage.service';

@Module({
  controllers: [StaffAppUpdateController],
  providers: [
    StaffAppUpdateService,
    StaffAppUpdateStorageService,
  ],
})
export class StaffAppUpdateModule {}