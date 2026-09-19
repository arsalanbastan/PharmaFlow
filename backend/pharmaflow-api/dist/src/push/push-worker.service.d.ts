import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { FirebasePushSenderService } from './firebase-push-sender.service';
export declare function pushTargetKey(input: {
    userId: string;
    installationId: string;
    appPackage: string;
}): string;
export type PushNotificationPreferenceMode = 'AUDIBLE' | 'SILENT' | 'OFF';
export declare function notificationModeForEvent(device: {
    notificationsEnabled: boolean;
    orderNotificationMode: string;
    chequeNotificationMode: string;
    cashPaymentNotificationMode: string;
}, eventType: string): PushNotificationPreferenceMode;
export declare function pushRetryDelayMs(attempt: number): number;
export declare class PushWorkerService implements OnModuleInit, OnModuleDestroy {
    private readonly prisma;
    private readonly sender;
    private readonly logger;
    private timer;
    private running;
    private active;
    private config;
    constructor(prisma: PrismaService, sender: FirebasePushSenderService);
    onModuleInit(): Promise<void>;
    onModuleDestroy(): void;
    runOnce(): Promise<void>;
    private expireOldOutboxRows;
    private claimNextOutbox;
    private processOutbox;
    private applyDeliveryResult;
    private settleOutbox;
    private releaseOutboxAfterFailure;
    private readConfig;
    private readIsoDate;
    private readBoundedInteger;
    private errorName;
}
