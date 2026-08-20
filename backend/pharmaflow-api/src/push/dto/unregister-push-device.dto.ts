import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class UnregisterPushDeviceDto {
  @IsString()
  @MinLength(8)
  @MaxLength(200)
  installationId!: string;

  @IsIn(['com.example.pharmaflow', 'com.example.pharmaflow.dev'])
  appPackage!: string;
}
