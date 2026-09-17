import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  ValidateNested,
} from 'class-validator';

import { ArsenCatalogItemDto } from './arsen-catalog-item.dto';

export class ArsenCatalogItemBatchDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => ArsenCatalogItemDto)
  items!: ArsenCatalogItemDto[];
}
