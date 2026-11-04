import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIP,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class StaffPosDeviceDto {
  @IsString()
  @MaxLength(80)
  id!: string;

  @IsString()
  @MaxLength(120)
  name!: string;

  @IsIP(4)
  ip!: string;

  @IsString()
  @MaxLength(80)
  terminalId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(10)
  @Max(180)
  timeout!: number;

  @IsBoolean()
  enabled!: boolean;
}

export class UpdateStaffPosSettingsDto {
  @IsOptional()
  @IsIP(4)
  bridgeHost?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(65535)
  bridgePort!: number;

  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => StaffPosDeviceDto)
  devices!: StaffPosDeviceDto[];
}
