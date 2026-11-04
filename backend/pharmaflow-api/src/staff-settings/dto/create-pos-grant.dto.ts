import { Type } from 'class-transformer';
import { IsIn, IsInt, IsString, Matches, Max, Min } from 'class-validator';

export class CreatePosGrantDto {
  @IsIn(['purchase', 'test', 'status'])
  operation!: 'purchase' | 'test' | 'status';

  @IsString()
  @Matches(/^[A-Za-z0-9_-]{1,128}$/)
  requestId!: string;

  @IsString()
  @Matches(/^[A-Za-z0-9_-]{1,80}$/)
  deviceId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(999999999999)
  amount!: number;
}
