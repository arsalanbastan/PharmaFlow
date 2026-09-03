import { IsUUID } from 'class-validator';

export class AcknowledgePushNotificationDto {
  @IsUUID('4')
  deliveryId!: string;
}