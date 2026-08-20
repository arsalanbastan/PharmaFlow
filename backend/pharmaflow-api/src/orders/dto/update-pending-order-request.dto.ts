import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
} from 'class-validator';

export class UpdatePendingOrderRequestDto {
  @IsIn(['DRUG', 'GOODS'])
  category!: string;

  @IsString()
  @Length(1, 300)
  itemText!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000000)
  requestedQuantity?: number | null;

  @IsOptional()
  @IsString()
  @Length(1, 200)
  suggestedCompanyText?: string | null;

  @IsOptional()
  @IsString()
  @Length(1, 1000)
  notes?: string | null;
}
