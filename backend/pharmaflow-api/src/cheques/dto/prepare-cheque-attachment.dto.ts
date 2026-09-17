import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsMimeType,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  Min,
} from 'class-validator';

import { CHEQUE_ATTACHMENT_KINDS } from '../cheque.constants';

export const MAX_CHEQUE_ATTACHMENT_BYTES = 25 * 1024 * 1024;

export class PrepareChequeAttachmentDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsUUID()
  chequeId: string;

  @IsIn(CHEQUE_ATTACHMENT_KINDS)
  kind: string;

  @IsString()
  fileName: string;

  @IsMimeType()
  mimeType: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_CHEQUE_ATTACHMENT_BYTES)
  originalFileSize?: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(MAX_CHEQUE_ATTACHMENT_BYTES)
  fileSize: number;

  @Matches(/^[0-9a-fA-F]{64}$/)
  sha256: string;
}
