import { IsBoolean } from 'class-validator';

export class SetAppUserActiveDto {
  @IsBoolean()
  isActive!: boolean;
}
