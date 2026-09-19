import { OnModuleDestroy } from '@nestjs/common';
import { type Message } from 'firebase-admin/messaging';
export type PushSendResult = {
    kind: 'sent';
} | {
    kind: 'invalid-token';
    code: string;
} | {
    kind: 'retry';
    code: string;
};
export type PushNotificationMode = 'AUDIBLE' | 'SILENT';
export type SupportedPushEventType = 'ORDER_CREATED' | 'CHEQUE_CREATED' | 'CASH_PAYMENT_CREATED';
export declare function buildCreatedMessage(eventType: SupportedPushEventType, token: string, aggregateId: string, mode?: PushNotificationMode, notificationAggregation?: {
    deliveryId: string;
    count: number;
}): Message;
export declare function buildOrderCreatedMessage(token: string, orderId: string, mode?: PushNotificationMode): Message;
export declare function classifyFirebaseMessagingError(error: unknown): PushSendResult;
export declare class FirebasePushSenderService implements OnModuleDestroy {
    private app;
    isConfigured(): boolean;
    sendCreatedEvent(eventType: SupportedPushEventType, token: string, aggregateId: string, mode?: PushNotificationMode, notificationAggregation?: {
        deliveryId: string;
        count: number;
    }): Promise<PushSendResult>;
    sendOrderCreated(token: string, orderId: string, mode?: PushNotificationMode): Promise<PushSendResult>;
    onModuleDestroy(): Promise<void>;
    private getOrCreateApp;
    private readServiceAccount;
}
