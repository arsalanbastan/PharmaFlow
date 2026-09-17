import { Type } from 'class-transformer';
import { IsInt, IsString, MaxLength, Min } from 'class-validator';

export class ArsenCompanyDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  arsenBusinessPartnerId!: number;

  @IsString()
  @MaxLength(255)
  arsenName!: string;
}
