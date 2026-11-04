import { Body, Controller, Get, Post, Put, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthPrincipal } from '../auth/auth.types';
import { CreatePosGrantDto } from './dto/create-pos-grant.dto';
import { VerifyPosReceiptDto } from './dto/verify-pos-receipt.dto';
import { UpdateStaffPosSettingsDto } from './dto/update-staff-pos-settings.dto';
import { StaffSettingsService } from './staff-settings.service';

@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/staff-settings')
export class StaffSettingsController {
  constructor(private readonly settings: StaffSettingsService) {}

  @Roles('STAFF', 'MANAGER')
  @Get('pos')
  posSettings() {
    return this.settings.posSettings();
  }

  @Roles('STAFF', 'MANAGER')
  @Post('pos/grant')
  createPosGrant(@Body() dto: CreatePosGrantDto, @CurrentUser() actor: AuthPrincipal) {
    return this.settings.issueGrant(dto, actor.userId);
  }

  @Roles('STAFF', 'MANAGER')
  @Post('pos/verify-receipt')
  verifyReceipt(@Body() dto: VerifyPosReceiptDto) {
    return this.settings.verifyReceipt(dto);
  }

  @Roles('MANAGER')
  @Put('pos')
  updatePosSettings(@Body() dto: UpdateStaffPosSettingsDto) {
    return this.settings.updatePosSettings(dto);
  }
}
