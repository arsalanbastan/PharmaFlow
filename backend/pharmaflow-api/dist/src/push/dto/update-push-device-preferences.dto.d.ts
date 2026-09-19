import { ReadPushDevicePreferencesDto } from './read-push-device-preferences.dto';
export declare class UpdatePushDevicePreferencesDto extends ReadPushDevicePreferencesDto {
    notificationsEnabled: boolean;
    orderNotificationMode: string;
    chequeNotificationMode: string;
    cashPaymentNotificationMode: string;
}
