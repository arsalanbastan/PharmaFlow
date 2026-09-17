import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, ValidateNested } from 'class-validator';

import { ArsenCompanyDto } from './arsen-company.dto';

export class ArsenCompanyBatchDto {
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => ArsenCompanyDto)
  companies!: ArsenCompanyDto[];
}
