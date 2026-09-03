import { Injectable, OnModuleDestroy } from '@nestjs/common';
import {
  cert,
  deleteApp,
  getApps,
  initializeApp,
  type App,
} from 'firebase-admin/app';
import { getMessaging, type Message } from 'firebase-admin/messaging';

const FIREBASE_APP_NAME = 'pharmaflow-push';

const PERMANENT_DEVICE_ERROR_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

type FirebaseServiceAccountJson = {
  project_id?: unknown;
  client_email?: unknown;
  private_key?: unknown;
};

export type PushSendResult =
  | { kind: 'sent' }
  | { kind: 'invalid-token'; code: string }
  | { kind: 'retry'; code: string };

export type PushNotificationMode = 'AUDIBLE' | 'SILENT';

export type SupportedPushEventType =
  'ORDER_CREATED' | 'CHEQUE_CREATED' | 'CASH_PAYMENT_CREATED';

type PushEventDescriptor = {
  title: string;
  body: string;
  aggregateBody: (count: number) => string;
  idKey: 'orderId' | 'chequeId' | 'cashPaymentId';
  collapsePrefix: 'order' | 'cheque' | 'cash-payment';
};

function pushEventDescriptor(
  eventType: SupportedPushEventType,
): PushEventDescriptor {
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

export function buildCreatedMessage(
  eventType: SupportedPushEventType,
  token: string,
  aggregateId: string,
  mode: PushNotificationMode = 'AUDIBLE',
  notificationAggregation?: {
    deliveryId: string;
    count: number;
  },
): Message {
  const descriptor = pushEventDescriptor(eventType);

  const aggregationEnabled = notificationAggregation != null;

  const notificationCount = Math.max(
    1,
    Math.trunc(notificationAggregation?.count ?? 1),
  );

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
            notificationDeliveryId:
              notificationAggregation.deliveryId.trim(),
            notificationCount: String(notificationCount),
          }),
    },
    android: {
      priority: 'high',
      collapseKey: notificationTag,
      notification:
        mode === 'SILENT'
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
export function buildOrderCreatedMessage(
  token: string,
  orderId: string,
  mode: PushNotificationMode = 'AUDIBLE',
): Message {
  return buildCreatedMessage('ORDER_CREATED', token, orderId, mode);
}
export function classifyFirebaseMessagingError(error: unknown): PushSendResult {
  const code =
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    typeof (error as { code?: unknown }).code === 'string'
      ? (error as { code: string }).code
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

@Injectable()
export class FirebasePushSenderService implements OnModuleDestroy {
  private app: App | null = null;

  isConfigured(): boolean {
    try {
      this.readServiceAccount();
      return true;
    } catch {
      return false;
    }
  }

  async sendCreatedEvent(
    eventType: SupportedPushEventType,
    token: string,
    aggregateId: string,
    mode: PushNotificationMode = 'AUDIBLE',
    notificationAggregation?: {
      deliveryId: string;
      count: number;
    },
  ): Promise<PushSendResult> {
    try {
      const messaging = getMessaging(this.getOrCreateApp());

      await messaging.send(
        buildCreatedMessage(
          eventType,
          token.trim(),
          aggregateId,
          mode,
          notificationAggregation,
        ),
      );

      return {
        kind: 'sent',
      };
    } catch (error) {
      return classifyFirebaseMessagingError(error);
    }
  }

  async sendOrderCreated(
    token: string,
    orderId: string,
    mode: PushNotificationMode = 'AUDIBLE',
  ): Promise<PushSendResult> {
    return this.sendCreatedEvent('ORDER_CREATED', token, orderId, mode);
  }
  async onModuleDestroy(): Promise<void> {
    if (this.app == null) {
      return;
    }

    await deleteApp(this.app);
    this.app = null;
  }

  private getOrCreateApp(): App {
    if (this.app != null) {
      return this.app;
    }

    const existing = getApps().find(
      (candidate) => candidate.name === FIREBASE_APP_NAME,
    );

    if (existing != null) {
      this.app = existing;
      return existing;
    }

    const serviceAccount = this.readServiceAccount();

    this.app = initializeApp(
      {
        credential: cert(serviceAccount),
      },
      FIREBASE_APP_NAME,
    );

    return this.app;
  }

  private readServiceAccount(): {
    projectId: string;
    clientEmail: string;
    privateKey: string;
  } {
    const encoded =
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64?.trim() ?? '';

    if (!encoded) {
      throw new Error('Firebase service account is not configured.');
    }

    let parsed: FirebaseServiceAccountJson;

    try {
      parsed = JSON.parse(
        Buffer.from(encoded, 'base64').toString('utf8'),
      ) as FirebaseServiceAccountJson;
    } catch {
      throw new Error('Firebase service account is invalid.');
    }

    const projectId =
      typeof parsed.project_id === 'string' ? parsed.project_id.trim() : '';
    const clientEmail =
      typeof parsed.client_email === 'string' ? parsed.client_email.trim() : '';
    const privateKey =
      typeof parsed.private_key === 'string' ? parsed.private_key : '';

    if (!projectId || !clientEmail || !privateKey) {
      throw new Error('Firebase service account is incomplete.');
    }

    return {
      projectId,
      clientEmail,
      privateKey,
    };
  }
}
