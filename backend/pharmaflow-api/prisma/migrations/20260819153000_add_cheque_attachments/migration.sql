CREATE TABLE "cheque_attachments" (
    "id" UUID NOT NULL,
    "chequeId" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "originalFileSize" INTEGER,
    "fileSize" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "cheque_attachments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "cheque_attachments_storageKey_key"
ON "cheque_attachments"("storageKey");

CREATE INDEX "cheque_attachments_chequeId_kind_deletedAt_idx"
ON "cheque_attachments"("chequeId", "kind", "deletedAt");

CREATE INDEX "cheque_attachments_updatedAt_id_idx"
ON "cheque_attachments"("updatedAt", "id");

ALTER TABLE "cheque_attachments"
ADD CONSTRAINT "cheque_attachments_chequeId_fkey"
FOREIGN KEY ("chequeId") REFERENCES "cheques"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
