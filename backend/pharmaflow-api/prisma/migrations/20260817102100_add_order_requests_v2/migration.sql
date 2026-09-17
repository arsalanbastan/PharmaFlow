CREATE TABLE "order_requests" (
    "id" UUID NOT NULL,
    "category" TEXT NOT NULL,
    "itemText" TEXT NOT NULL,
    "normalizedItemText" TEXT NOT NULL,
    "requestedQuantity" INTEGER,
    "orderedQuantity" INTEGER,
    "suggestedCompanyText" TEXT,
    "notes" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "possibleDuplicate" BOOLEAN NOT NULL DEFAULT false,
    "assignedCompanyId" UUID,
    "requestedByName" TEXT NOT NULL,
    "orderedByName" TEXT,
    "receivedByName" TEXT,
    "canceledByName" TEXT,
    "deletedByName" TEXT,
    "requestedByUserId" UUID,
    "orderedByUserId" UUID,
    "receivedByUserId" UUID,
    "canceledByUserId" UUID,
    "deletedByUserId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "orderedAt" TIMESTAMP(3),
    "receivedAt" TIMESTAMP(3),
    "canceledAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "photoStorageKey" TEXT,
    "photoFileSize" INTEGER,
    "photoSha256" TEXT,
    "photoDeletedAt" TIMESTAMP(3),

    CONSTRAINT "order_requests_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "order_requests_status_category_createdAt_idx"
ON "order_requests"("status", "category", "createdAt");

CREATE INDEX "order_requests_updatedAt_id_idx"
ON "order_requests"("updatedAt", "id");

CREATE INDEX "order_requests_normalizedItemText_status_idx"
ON "order_requests"("normalizedItemText", "status");

CREATE INDEX "order_requests_assignedCompanyId_status_idx"
ON "order_requests"("assignedCompanyId", "status");

ALTER TABLE "order_requests"
ADD CONSTRAINT "order_requests_assignedCompanyId_fkey"
FOREIGN KEY ("assignedCompanyId")
REFERENCES "companies"("id")
ON DELETE SET NULL
ON UPDATE CASCADE;