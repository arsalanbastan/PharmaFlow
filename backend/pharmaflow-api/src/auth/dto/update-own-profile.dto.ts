import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateOwnProfileDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  displayName!: string;
}
