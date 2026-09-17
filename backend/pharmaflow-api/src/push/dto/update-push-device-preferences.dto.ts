import { IsBoolean, IsIn } from 'class-validator';

import { ReadPushDevicePreferencesDto } from './read-push-device-preferences.dto';

const NOTIFICATION_MODES = ['AUDIBLE', 'SILENT', 'OFF'] as const;

export class UpdatePushDevicePreferencesDto extends ReadPushDevicePreferencesDto {
  @IsBoolean()
  notificationsEnabled!: boolean;

  @IsIn(NOTIFICATION_MODES)
  orderNotificationMode!: string;

  @IsIn(NOTIFICATION_MODES)
  chequeNotificationMode!: string;

  @IsIn(NOTIFICATION_MODES)
  cashPaymentNotificationMode!: string;
}
