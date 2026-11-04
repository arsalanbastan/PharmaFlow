import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { StaffSettingsController } from './staff-settings.controller';
import { StaffSettingsService } from './staff-settings.service';

@Module({
  imports: [AuthModule],
  controllers: [StaffSettingsController],
  providers: [StaffSettingsService],
})
export class StaffSettingsModule {}
