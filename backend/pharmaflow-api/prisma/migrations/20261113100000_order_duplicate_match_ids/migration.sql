ALTER TABLE "order_requests"
ADD COLUMN "duplicateMatchIds" UUID[] NOT NULL DEFAULT ARRAY[]::UUID[];
