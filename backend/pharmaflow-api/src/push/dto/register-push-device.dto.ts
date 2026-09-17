import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterPushDeviceDto {
  @IsString()
  @MinLength(16)
  @MaxLength(4096)
  token!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(200)
  installationId!: string;

  @IsIn(['android'])
  platform!: string;

  @IsIn(['com.example.pharmaflow', 'com.example.pharmaflow.dev'])
  appPackage!: string;
}
