ALTER TABLE "push_devices"
ADD COLUMN "notificationAggregationVersion" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "push_deliveries"
ADD COLUMN "deliverySequence" BIGSERIAL NOT NULL,
ADD COLUMN "acknowledgedAt" TIMESTAMP(3);

-- Existing deliveries pre-date notification aggregation.
-- Mark them acknowledged so the first V2 notification starts at count 1.
UPDATE "push_deliveries"
SET "acknowledgedAt" = CURRENT_TIMESTAMP;

CREATE UNIQUE INDEX "push_deliveries_deliverySequence_key"
ON "push_deliveries"("deliverySequence");

CREATE INDEX "push_deliveries_deviceId_acknowledgedAt_deliverySequence_idx"
ON "push_deliveries"(
  "deviceId",
  "acknowledgedAt",
  "deliverySequence"
);