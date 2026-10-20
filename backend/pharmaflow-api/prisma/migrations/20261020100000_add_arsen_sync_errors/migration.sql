CREATE TABLE "arsen_sync_errors" (
    "id" UUID NOT NULL,
    "arsenFactorId" INTEGER NOT NULL,
    "errorKind" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "occurrences" INTEGER NOT NULL DEFAULT 1,
    "firstSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "arsen_sync_errors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "arsen_sync_errors_arsenFactorId_key" ON "arsen_sync_errors"("arsenFactorId");
CREATE INDEX "arsen_sync_errors_lastSeenAt_idx" ON "arsen_sync_errors"("lastSeenAt" DESC);
