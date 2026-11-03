CREATE TABLE "arsen_catalog_barcodes" (
    "id" UUID NOT NULL,
    "catalogItemId" UUID NOT NULL,
    "arsenBarcodeId" BIGINT NOT NULL,
    "barcode" TEXT NOT NULL,
    "barcodeNormalized" TEXT,
    "lookupKey" TEXT NOT NULL,
    "defQnt" INTEGER,
    "sourceSyncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "arsen_catalog_barcodes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "arsen_catalog_barcodes_arsenBarcodeId_key"
ON "arsen_catalog_barcodes"("arsenBarcodeId");

CREATE UNIQUE INDEX "arsen_catalog_barcodes_lookupKey_key"
ON "arsen_catalog_barcodes"("lookupKey");

CREATE INDEX "arsen_catalog_barcodes_catalogItemId_idx"
ON "arsen_catalog_barcodes"("catalogItemId");

CREATE INDEX "arsen_catalog_barcodes_barcode_idx"
ON "arsen_catalog_barcodes"("barcode");

CREATE INDEX "arsen_catalog_barcodes_barcodeNormalized_idx"
ON "arsen_catalog_barcodes"("barcodeNormalized");

ALTER TABLE "arsen_catalog_barcodes"
ADD CONSTRAINT "arsen_catalog_barcodes_catalogItemId_fkey"
FOREIGN KEY ("catalogItemId") REFERENCES "arsen_catalog_items"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
