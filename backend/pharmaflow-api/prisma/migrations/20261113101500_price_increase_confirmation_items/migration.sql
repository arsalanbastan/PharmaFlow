ALTER TABLE "price_increases"
ADD COLUMN "productItems" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

ALTER TABLE "price_increase_confirmations"
ADD COLUMN "itemIndex" INTEGER NOT NULL DEFAULT -1,
ADD COLUMN "note" TEXT;

CREATE UNIQUE INDEX "price_increase_confirmations_notice_user_item_key"
ON "price_increase_confirmations" ("priceIncreaseId", "userId", "itemIndex");

DROP INDEX "price_increase_confirmations_priceIncreaseId_userId_key";
