CREATE TABLE "arsen_company_mappings" (
    "id" UUID NOT NULL,
    "arsenBusinessPartnerId" INTEGER NOT NULL,
    "arsenName" TEXT NOT NULL,
    "companyId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "arsen_company_mappings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "arsen_company_mappings_arsenBusinessPartnerId_key"
ON "arsen_company_mappings"("arsenBusinessPartnerId");

CREATE INDEX "arsen_company_mappings_companyId_idx"
ON "arsen_company_mappings"("companyId");

ALTER TABLE "arsen_company_mappings"
ADD CONSTRAINT "arsen_company_mappings_companyId_fkey"
FOREIGN KEY ("companyId") REFERENCES "companies"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
