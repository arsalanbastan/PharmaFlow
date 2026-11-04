import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { CurrentUser } from './current-user.decorator';
import { CreateAppUserDto } from './dto/create-app-user.dto';
import { LoginDto } from './dto/login.dto';
import { ResetAppUserPasswordDto } from './dto/reset-app-user-password.dto';
import { SetAppUserActiveDto } from './dto/set-app-user-active.dto';
import { SetAppUserPermissionsDto } from './dto/set-app-user-permissions.dto';
import { UpdateOwnProfileDto } from './dto/update-own-profile.dto';
import { ChangeOwnPasswordDto } from './dto/change-own-password.dto';
import { Roles } from './roles.decorator';
import { RolesGuard } from './roles.guard';
import type { AuthPrincipal } from './auth.types';

@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(AuthGuard)
  me(@CurrentUser() user: AuthPrincipal) {
    return {
      user,
    };
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  async logout(
    @Headers('authorization')
    authorization?: string,
  ) {
    await this.authService.logout(authorization);

    return {
      ok: true,
    };
  }

  @Put('me/profile')
  @UseGuards(AuthGuard)
  updateOwnProfile(
    @CurrentUser() user: AuthPrincipal,
    @Body() dto: UpdateOwnProfileDto,
  ) {
    return this.authService.updateOwnProfile(user.userId, dto);
  }

  @Post('me/change-password')
  @UseGuards(AuthGuard)
  async changeOwnPassword(
    @CurrentUser() user: AuthPrincipal,
    @Headers('authorization') authorization: string | undefined,
    @Body() dto: ChangeOwnPasswordDto,
  ) {
    await this.authService.changeOwnPassword(
      user.userId,
      authorization,
      dto,
    );
    return { ok: true };
  }

  @Get('users')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  listUsers() {
    return this.authService.listUsers();
  }

  @Post('users')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  createUser(@Body() dto: CreateAppUserDto) {
    return this.authService.createUser(dto);
  }

  @Post('users/:id/reset-password')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  async resetPassword(
    @Param('id') id: string,
    @Body() dto: ResetAppUserPasswordDto,
  ) {
    await this.authService.resetPassword(id, dto);

    return {
      ok: true,
    };
  }

  @Post('users/:id/active')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  setActive(
    @CurrentUser() currentUser: AuthPrincipal,
    @Param('id') id: string,
    @Body() dto: SetAppUserActiveDto,
  ) {
    return this.authService.setActive(id, dto, currentUser.userId);
  }

  @Post('users/:id/permissions')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  setPermissions(
    @Param('id') id: string,
    @Body() dto: SetAppUserPermissionsDto,
  ) {
    return this.authService.setPermissions(id, dto);
  }

  @Get('users/:id/activity')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  listUserActivity(@Param('id') id: string, @Query('limit') limit?: string) {
    return this.authService.listUserActivity(id, limit);
  }
}
