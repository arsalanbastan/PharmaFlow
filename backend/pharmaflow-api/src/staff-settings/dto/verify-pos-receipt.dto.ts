import { Type } from 'class-transformer';
import { IsInt, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

export class VerifyPosReceiptDto {
  @IsString()
  @MaxLength(4096)
  receipt!: string;

  @IsString()
  @Matches(/^[A-Za-z0-9_-]{1,80}$/)
  deviceId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1000)
  @Max(999999999999)
  amount!: number;
}
