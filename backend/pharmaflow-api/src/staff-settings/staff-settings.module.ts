import { Module } from '@nestjs/common';

import { StaffSettingsController } from './staff-settings.controller';
import { StaffSettingsService } from './staff-settings.service';

@Module({
  controllers: [StaffSettingsController],
  providers: [StaffSettingsService],
})
export class StaffSettingsModule {}
