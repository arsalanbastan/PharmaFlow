CREATE TABLE "arsen_catalog_items" (
    "id" UUID NOT NULL,
    "ingestSequence" BIGSERIAL NOT NULL,
    "arsenDrugId" BIGINT NOT NULL,
    "category" TEXT NOT NULL,
    "persianName" TEXT,
    "genericName" TEXT,
    "persianBrandName" TEXT,
    "brandName" TEXT,
    "unit" TEXT,
    "shapeName" TEXT,
    "packetQuantity" INTEGER,
    "salesPrice" DECIMAL(20,4),
    "lastPurchasePrice" DECIMAL(20,4),
    "isActive" BOOLEAN NOT NULL,
    "description" TEXT,
    "sourceFingerprint" VARCHAR(64) NOT NULL,
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sourceSyncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "arsen_catalog_items_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "arsen_catalog_items_ingestSequence_key"
ON "arsen_catalog_items"("ingestSequence");

CREATE UNIQUE INDEX "arsen_catalog_items_arsenDrugId_key"
ON "arsen_catalog_items"("arsenDrugId");

CREATE INDEX "arsen_catalog_items_category_isActive_ingestSequence_idx"
ON "arsen_catalog_items"("category", "isActive", "ingestSequence" DESC);

CREATE INDEX "arsen_catalog_items_isActive_ingestSequence_idx"
ON "arsen_catalog_items"("isActive", "ingestSequence" DESC);
