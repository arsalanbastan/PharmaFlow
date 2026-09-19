"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FirebasePushSenderService = void 0;
exports.buildCreatedMessage = buildCreatedMessage;
exports.buildOrderCreatedMessage = buildOrderCreatedMessage;
exports.classifyFirebaseMessagingError = classifyFirebaseMessagingError;
const common_1 = require("@nestjs/common");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const FIREBASE_APP_NAME = 'pharmaflow-push';
const PERMANENT_DEVICE_ERROR_CODES = new Set([
    'messaging/invalid-registration-token',
    'messaging/registration-token-not-registered',
]);
function pushEventDescriptor(eventType) {
    switch (eventType) {
        case 'ORDER_CREATED':
            return {
                title: 'سفارش جدید',
                body: 'یک سفارش جدید ثبت شد.',
                aggregateBody: (count) => `شما ${count} سفارش جدید دارید`,
                idKey: 'orderId',
                collapsePrefix: 'order',
            };
        case 'CHEQUE_CREATED':
            return {
                title: 'چک جدید ثبت شد',
                body: 'یک چک جدید ثبت شد.',
                aggregateBody: (count) => `شما ${count} چک جدید دارید`,
                idKey: 'chequeId',
                collapsePrefix: 'cheque',
            };
        case 'CASH_PAYMENT_CREATED':
            return {
                title: 'واریزی جدید ثبت شد',
                body: 'یک واریزی جدید ثبت شد.',
                aggregateBody: (count) => `شما ${count} واریزی جدید دارید`,
                idKey: 'cashPaymentId',
                collapsePrefix: 'cash-payment',
            };
    }
}
function buildCreatedMessage(eventType, token, aggregateId, mode = 'AUDIBLE', notificationAggregation) {
    const descriptor = pushEventDescriptor(eventType);
    const aggregationEnabled = notificationAggregation != null;
    const notificationCount = Math.max(1, Math.trunc(notificationAggregation?.count ?? 1));
    const notificationTag = aggregationEnabled
        ? descriptor.collapsePrefix
        : `${descriptor.collapsePrefix}-${aggregateId}`;
    return {
        token,
        notification: {
            title: descriptor.title,
            body: aggregationEnabled
                ? descriptor.aggregateBody(notificationCount)
                : descriptor.body,
        },
        data: {
            type: eventType,
            [descriptor.idKey]: aggregateId,
            ...(notificationAggregation == null
                ? {}
                : {
                    notificationDeliveryId: notificationAggregation.deliveryId.trim(),
                    notificationCount: String(notificationCount),
                }),
        },
        android: {
            priority: 'high',
            collapseKey: notificationTag,
            notification: mode === 'SILENT'
                ? {
                    tag: notificationTag,
                    channelId: 'pharmaflow_silent',
                }
                : {
                    tag: notificationTag,
                },
        },
    };
}
function buildOrderCreatedMessage(token, orderId, mode = 'AUDIBLE') {
    return buildCreatedMessage('ORDER_CREATED', token, orderId, mode);
}
function classifyFirebaseMessagingError(error) {
    const code = typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        typeof error.code === 'string'
        ? error.code
        : 'messaging/unknown';
    if (PERMANENT_DEVICE_ERROR_CODES.has(code)) {
        return {
            kind: 'invalid-token',
            code,
        };
    }
    return {
        kind: 'retry',
        code,
    };
}
let FirebasePushSenderService = class FirebasePushSenderService {
    app = null;
    isConfigured() {
        try {
            this.readServiceAccount();
            return true;
        }
        catch {
            return false;
        }
    }
    async sendCreatedEvent(eventType, token, aggregateId, mode = 'AUDIBLE', notificationAggregation) {
        try {
            const messaging = (0, messaging_1.getMessaging)(this.getOrCreateApp());
            await messaging.send(buildCreatedMessage(eventType, token.trim(), aggregateId, mode, notificationAggregation));
            return {
                kind: 'sent',
            };
        }
        catch (error) {
            return classifyFirebaseMessagingError(error);
        }
    }
    async sendOrderCreated(token, orderId, mode = 'AUDIBLE') {
        return this.sendCreatedEvent('ORDER_CREATED', token, orderId, mode);
    }
    async onModuleDestroy() {
        if (this.app == null) {
            return;
        }
        await (0, app_1.deleteApp)(this.app);
        this.app = null;
    }
    getOrCreateApp() {
        if (this.app != null) {
            return this.app;
        }
        const existing = (0, app_1.getApps)().find((candidate) => candidate.name === FIREBASE_APP_NAME);
        if (existing != null) {
            this.app = existing;
            return existing;
        }
        const serviceAccount = this.readServiceAccount();
        this.app = (0, app_1.initializeApp)({
            credential: (0, app_1.cert)(serviceAccount),
        }, FIREBASE_APP_NAME);
        return this.app;
    }
    readServiceAccount() {
        const encoded = process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64?.trim() ?? '';
        if (!encoded) {
            throw new Error('Firebase service account is not configured.');
        }
        let parsed;
        try {
            parsed = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
        }
        catch {
            throw new Error('Firebase service account is invalid.');
        }
        const projectId = typeof parsed.project_id === 'string' ? parsed.project_id.trim() : '';
        const clientEmail = typeof parsed.client_email === 'string' ? parsed.client_email.trim() : '';
        const privateKey = typeof parsed.private_key === 'string' ? parsed.private_key : '';
        if (!projectId || !clientEmail || !privateKey) {
            throw new Error('Firebase service account is incomplete.');
        }
        return {
            projectId,
            clientEmail,
            privateKey,
        };
    }
};
exports.FirebasePushSenderService = FirebasePushSenderService;
exports.FirebasePushSenderService = FirebasePushSenderService = __decorate([
    (0, common_1.Injectable)()
], FirebasePushSenderService);
//# sourceMappingURL=firebase-push-sender.service.js.map