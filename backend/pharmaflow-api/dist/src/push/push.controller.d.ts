import type { AuthPrincipal } from '../auth/auth.types';
import { AcknowledgePushNotificationDto } from './dto/acknowledge-push-notification.dto';
import { ReadPushDevicePreferencesDto } from './dto/read-push-device-preferences.dto';
import { RegisterPushDeviceDto } from './dto/register-push-device.dto';
import { UnregisterPushDeviceDto } from './dto/unregister-push-device.dto';
import { UpdatePushDevicePreferencesDto } from './dto/update-push-device-preferences.dto';
import { PushDeviceService } from './push-device.service';
export declare class PushController {
    private readonly pushDevices;
    constructor(pushDevices: PushDeviceService);
    register(user: AuthPrincipal, dto: RegisterPushDeviceDto): Promise<{
        id: string;
        platform: string;
        appPackage: string;
        isEnabled: boolean;
        lastSeenAt: Date;
    }>;
    getPreferences(user: AuthPrincipal, dto: ReadPushDevicePreferencesDto): Promise<{
        notificationsEnabled: boolean;
        orderNotificationMode: string;
        chequeNotificationMode: string;
        cashPaymentNotificationMode: string;
    }>;
    updatePreferences(user: AuthPrincipal, dto: UpdatePushDevicePreferencesDto): Promise<{
        notificationsEnabled: boolean;
        orderNotificationMode: string;
        chequeNotificationMode: string;
        cashPaymentNotificationMode: string;
    }>;
    acknowledgeNotification(user: AuthPrincipal, dto: AcknowledgePushNotificationDto): Promise<{
        ok: boolean;
    }>;
    acknowledgeAllNotifications(user: AuthPrincipal, dto: ReadPushDevicePreferencesDto): Promise<{
        ok: boolean;
        acknowledgedCount: number;
    }>;
    unregister(user: AuthPrincipal, dto: UnregisterPushDeviceDto): Promise<{
        ok: boolean;
    }>;
}
