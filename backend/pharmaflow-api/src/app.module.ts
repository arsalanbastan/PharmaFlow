import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './database/prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { CompaniesModule } from './companies/companies.module';
import { BankAccountsModule } from './bank-accounts/bank-accounts.module';
import { ChequesModule } from './cheques/cheques.module';

@Module({
  imports: [
    PrismaModule,
    HealthModule,
    CompaniesModule,
    BankAccountsModule,
    ChequesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}