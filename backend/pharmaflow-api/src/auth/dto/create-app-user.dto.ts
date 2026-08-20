import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateAppUserDto {
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  username!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(150)
  displayName!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password!: string;

  @IsIn(['MANAGER', 'STAFF'])
  role!: 'MANAGER' | 'STAFF';

  @IsOptional()
  @IsBoolean()
  managerAppAccess?: boolean;

  @IsOptional()
  @IsBoolean()
  canCreateOrders?: boolean;

  @IsOptional()
  @IsBoolean()
  canCreateCheques?: boolean;

  @IsOptional()
  @IsBoolean()
  canCreateCashPayments?: boolean;

  @IsOptional()
  @IsBoolean()
  canViewFinancialReports?: boolean;
}
