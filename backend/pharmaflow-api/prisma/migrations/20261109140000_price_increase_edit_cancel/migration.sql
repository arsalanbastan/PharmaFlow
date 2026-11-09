ALTER TABLE "price_increases"
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "canceledAt" TIMESTAMP(3),
  ADD COLUMN "canceledByUserId" UUID,
  ADD COLUMN "canceledByName" TEXT,
  ADD COLUMN "cancellationReason" TEXT;
