import { Controller, Get } from '@nestjs/common';
import { AppUpdateService } from './app-update.service';
import type { AndroidUpdateManifest } from './app-update.service';

@Controller('api/v1/app-update')
export class AppUpdateController {
  constructor(private readonly appUpdateService: AppUpdateService) {}

  @Get('android')
  getAndroidManifest(): Promise<AndroidUpdateManifest> {
    return this.appUpdateService.getAndroidManifest();
  }
}
