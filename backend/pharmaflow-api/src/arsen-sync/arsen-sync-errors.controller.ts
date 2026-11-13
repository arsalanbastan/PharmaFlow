import { Controller, Delete, Get, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ArsenSyncService } from './arsen-sync.service';

@Roles('MANAGER')
@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/integrations/arsen/sync-errors')
export class ArsenSyncErrorsController {
  constructor(private readonly arsenSyncService: ArsenSyncService) {}

  @Get()
  list() {
    return this.arsenSyncService.listSyncErrors();
  }

  @Delete()
  clear() {
    return this.arsenSyncService.clearSyncErrors();
  }
}
