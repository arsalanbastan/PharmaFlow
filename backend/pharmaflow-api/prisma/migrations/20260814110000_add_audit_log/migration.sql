CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "source" TEXT NOT NULL,
    "actorDisplayName" TEXT,
    "actorUserId" UUID,
    "actorVerified" BOOLEAN NOT NULL DEFAULT false,
    "deviceId" TEXT,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT,
    "beforeData" JSONB,
    "afterData" JSONB,
    "ipAddress" TEXT,
    "requestId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "audit_logs_createdAt_idx"
ON "audit_logs"("createdAt");

CREATE INDEX "audit_logs_entityType_entityId_createdAt_idx"
ON "audit_logs"("entityType", "entityId", "createdAt");

CREATE INDEX "audit_logs_actorDisplayName_createdAt_idx"
ON "audit_logs"("actorDisplayName", "createdAt");