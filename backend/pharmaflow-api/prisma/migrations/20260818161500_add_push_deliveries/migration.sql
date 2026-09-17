-- CreateTable
CREATE TABLE "push_deliveries" (
    "id" UUID NOT NULL,
    "outboxId" UUID NOT NULL,
    "deviceId" UUID,
    "targetKey" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "nextAttemptAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sentAt" TIMESTAMP(3),
    "lastError" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "push_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "push_deliveries_outboxId_targetKey_key"
ON "push_deliveries"("outboxId", "targetKey");

-- CreateIndex
CREATE INDEX "push_deliveries_outboxId_status_nextAttemptAt_idx"
ON "push_deliveries"("outboxId", "status", "nextAttemptAt");

-- CreateIndex
CREATE INDEX "push_deliveries_deviceId_idx"
ON "push_deliveries"("deviceId");

-- AddForeignKey
ALTER TABLE "push_deliveries"
ADD CONSTRAINT "push_deliveries_outboxId_fkey"
FOREIGN KEY ("outboxId") REFERENCES "push_outbox"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "push_deliveries"
ADD CONSTRAINT "push_deliveries_deviceId_fkey"
FOREIGN KEY ("deviceId") REFERENCES "push_devices"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
