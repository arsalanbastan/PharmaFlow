import { Global, Module } from '@nestjs/common';

import { AuditContextService } from './audit-context.service';
import { AuditLogService } from './audit-log.service';

@Global()
@Module({
  providers: [AuditContextService, AuditLogService],
  exports: [AuditContextService, AuditLogService],
})
export class AuditModule {}
