# PharmaFlow Arsen Company Mapping Patch

Production source basis SHA-256:
`fe309e5ec280fb26259091afd6206bd3d8cef26cedf6d82cef277592db646d9b`

## Scope

This patch adds the persistent Arsen BusinessPartner -> PharmaFlow Company mapping layer only.
It does not connect to the Arsen SQL Server and it does not import invoices.

## Database

New Prisma model/table:
- `ArsenCompanyMapping`
- table: `arsen_company_mappings`
- unique identity: `arsenBusinessPartnerId`
- relation to `Company` with `ON DELETE RESTRICT`

Migration:
- `prisma/migrations/20260826163000_add_arsen_company_mappings/migration.sql`

## Initial mapping import

Script:
- `scripts/arsen_company_mappings.ts`
- exactly 95 Arsen BusinessPartner IDs
- 92 unique PharmaFlow Company UUIDs (some Arsen aliases intentionally map to the same Company)
- default mode is read-only CHECK
- `--apply` is required for writes
- refuses silent remapping if an existing Arsen ID points to a different PharmaFlow Company
- verifies all target Company UUIDs exist and are not soft-deleted
- writes audit rows for mapping creates / source-name updates

After build:
- read-only: `npm run arsen:mappings`
- apply: `npm run arsen:mappings -- --apply`

## Admin safety

Company hard-delete now also checks Arsen mapping dependencies.
The Company admin list shows the Arsen mapping count.

## Explicitly not included

- no Arsen SQL credentials
- no environment files
- no invoice import
- no direct production database SQL outside Prisma migration/import script
- no national ID copy from Arsen
