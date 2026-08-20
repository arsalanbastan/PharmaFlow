-- CreateTable
CREATE TABLE "push_devices" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "fcmToken" TEXT NOT NULL,
    "installationId" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "appPackage" TEXT NOT NULL,
    "isEnabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "push_devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "push_outbox" (
    "id" UUID NOT NULL,
    "eventType" TEXT NOT NULL,
    "aggregateType" TEXT NOT NULL,
    "aggregateId" UUID NOT NULL,
    "targetRole" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "claimedAt" TIMESTAMP(3),
    "sentAt" TIMESTAMP(3),
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "push_outbox_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "push_devices_fcmToken_key"
ON "push_devices"("fcmToken");

CREATE UNIQUE INDEX "push_devices_userId_installationId_appPackage_key"
ON "push_devices"("userId", "installationId", "appPackage");

CREATE INDEX "push_devices_userId_isEnabled_idx"
ON "push_devices"("userId", "isEnabled");

CREATE INDEX "push_devices_lastSeenAt_idx"
ON "push_devices"("lastSeenAt");

CREATE UNIQUE INDEX "push_outbox_eventType_aggregateId_key"
ON "push_outbox"("eventType", "aggregateId");

CREATE INDEX "push_outbox_status_nextAttemptAt_createdAt_idx"
ON "push_outbox"("status", "nextAttemptAt", "createdAt");

CREATE INDEX "push_outbox_aggregateType_aggregateId_idx"
ON "push_outbox"("aggregateType", "aggregateId");

ALTER TABLE "push_devices"
ADD CONSTRAINT "push_devices_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "app_users"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
