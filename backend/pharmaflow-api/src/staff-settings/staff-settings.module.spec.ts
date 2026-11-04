import { Test } from '@nestjs/testing';

import { AuditModule } from '../audit/audit.module';
import { PrismaModule } from '../database/prisma/prisma.module';
import { PrismaService } from '../database/prisma/prisma.service';
import { StaffSettingsController } from './staff-settings.controller';
import { StaffSettingsModule } from './staff-settings.module';

describe('StaffSettingsModule dependency injection', () => {
  it('resolves AuthGuard and other controller dependencies without a database connection', async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [PrismaModule, AuditModule, StaffSettingsModule],
    })
      .overrideProvider(PrismaService)
      .useValue({})
      .compile();

    try {
      expect(moduleRef.get(StaffSettingsController)).toBeDefined();
    } finally {
      await moduleRef.close();
    }
  });
});
