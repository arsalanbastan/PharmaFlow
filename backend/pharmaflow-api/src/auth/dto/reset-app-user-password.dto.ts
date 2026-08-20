import { IsString, MaxLength, MinLength } from 'class-validator';

export class ResetAppUserPasswordDto {
  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password!: string;
}
