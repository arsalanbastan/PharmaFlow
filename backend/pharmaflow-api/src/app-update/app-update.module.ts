import { Module } from '@nestjs/common';
import { AppUpdateController } from './app-update.controller';
import { AppUpdateService } from './app-update.service';
import { AppUpdateStorageService } from './app-update-storage.service';

@Module({
  controllers: [AppUpdateController],
  providers: [AppUpdateService, AppUpdateStorageService],
})
export class AppUpdateModule {}
