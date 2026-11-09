-- CreateTable
CREATE TABLE "price_increases" (
    "id" UUID NOT NULL,
    "productName" TEXT NOT NULL,
    "normalizedProductName" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "newPrice" DECIMAL(18,2) NOT NULL,
    "effectiveDate" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "notes" TEXT,
    "createdByUserId" UUID NOT NULL,
    "createdByName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_increases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "price_increase_confirmations" (
    "id" UUID NOT NULL,
    "priceIncreaseId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "displayName" TEXT NOT NULL,
    "confirmedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_increase_confirmations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "price_increase_attachments" (
    "id" UUID NOT NULL,
    "priceIncreaseId" UUID NOT NULL,
    "fileName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "fileSize" INTEGER NOT NULL,
    "storageKey" TEXT NOT NULL,
    "confirmedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "price_increase_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "price_increases_effectiveDate_createdAt_idx" ON "price_increases"("effectiveDate", "createdAt");

-- CreateIndex
CREATE INDEX "price_increases_normalizedProductName_idx" ON "price_increases"("normalizedProductName");

-- CreateIndex
CREATE UNIQUE INDEX "price_increase_confirmations_priceIncreaseId_userId_key" ON "price_increase_confirmations"("priceIncreaseId", "userId");

-- CreateIndex
CREATE INDEX "price_increase_attachments_priceIncreaseId_idx" ON "price_increase_attachments"("priceIncreaseId");

-- AddForeignKey
ALTER TABLE "price_increase_confirmations" ADD CONSTRAINT "price_increase_confirmations_priceIncreaseId_fkey" FOREIGN KEY ("priceIncreaseId") REFERENCES "price_increases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_increase_attachments" ADD CONSTRAINT "price_increase_attachments_priceIncreaseId_fkey" FOREIGN KEY ("priceIncreaseId") REFERENCES "price_increases"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

