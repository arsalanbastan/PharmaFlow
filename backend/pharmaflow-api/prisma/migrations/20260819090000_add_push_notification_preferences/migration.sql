ALTER TABLE "push_devices"
ADD COLUMN "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "orderNotificationMode" TEXT NOT NULL DEFAULT 'AUDIBLE',
ADD COLUMN "chequeNotificationMode" TEXT NOT NULL DEFAULT 'AUDIBLE',
ADD COLUMN "cashPaymentNotificationMode" TEXT NOT NULL DEFAULT 'AUDIBLE';