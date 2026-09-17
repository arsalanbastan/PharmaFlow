import { Controller, Get } from '@nestjs/common';

import { StaffAppUpdateService } from './staff-app-update.service';

@Controller('api/v1/app-update/staff')
export class StaffAppUpdateController {
  constructor(
    private readonly service: StaffAppUpdateService,
  ) {}

  @Get('android')
  getAndroidManifest() {
    return this.service.getAndroidManifest();
  }
}