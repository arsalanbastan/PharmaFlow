import { IsIn, IsString, Length } from 'class-validator';

export class CheckOrderDuplicateDto {
  @IsIn(['DRUG', 'GOODS'])
  category!: string;

  @IsString()
  @Length(1, 300)
  itemText!: string;
}
