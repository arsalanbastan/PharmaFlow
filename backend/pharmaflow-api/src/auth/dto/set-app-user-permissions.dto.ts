import { IsBoolean } from 'class-validator';

export class SetAppUserPermissionsDto {
  @IsBoolean()
  managerAppAccess!: boolean;

  @IsBoolean()
  canCreateOrders!: boolean;

  @IsBoolean()
  canCreateCheques!: boolean;

  @IsBoolean()
  canCreateCashPayments!: boolean;

  @IsBoolean()
  canViewFinancialReports!: boolean;
}
