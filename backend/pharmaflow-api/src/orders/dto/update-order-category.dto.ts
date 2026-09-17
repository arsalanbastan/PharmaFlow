import { IsIn } from 'class-validator';

export class UpdateOrderCategoryDto {
  @IsIn(['DRUG', 'GOODS'])
  category!: string;
}
