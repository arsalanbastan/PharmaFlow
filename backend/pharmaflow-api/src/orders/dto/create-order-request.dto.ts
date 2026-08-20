import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
} from 'class-validator';

export class CreateOrderRequestDto {
  @IsOptional()
  @IsUUID()
  id?: string;

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
