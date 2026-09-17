import { Body, Controller, Patch, Post, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import type { AuthPrincipal } from '../auth/auth.types';
import { ReadPushDevicePreferencesDto } from './dto/read-push-device-preferences.dto';
import { RegisterPushDeviceDto } from './dto/register-push-device.dto';
import { UnregisterPushDeviceDto } from './dto/unregister-push-device.dto';
import { UpdatePushDevicePreferencesDto } from './dto/update-push-device-preferences.dto';
import { PushDeviceService } from './push-device.service';

@Roles('MANAGER')
@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/push')
export class PushController {
  constructor(private readonly pushDevices: PushDeviceService) {}

  @Post('devices/register')
  register(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: RegisterPushDeviceDto,
  ) {
    return this.pushDevices.register(user, dto);
  }

  @Post('devices/preferences/read')
  getPreferences(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: ReadPushDevicePreferencesDto,
  ) {
    return this.pushDevices.getPreferences(user, dto);
  }

  @Patch('devices/preferences')
  updatePreferences(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: UpdatePushDevicePreferencesDto,
  ) {
    return this.pushDevices.updatePreferences(user, dto);
  }
  @Post('devices/unregister')
  unregister(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: UnregisterPushDeviceDto,
  ) {
    return this.pushDevices.unregister(user, dto);
  }
}
