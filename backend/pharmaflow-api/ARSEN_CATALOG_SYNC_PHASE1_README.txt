PharmaFlow Arsen Catalog Item Sync - Phase 1
Date: 2026-08-31

Adds:
- Prisma model/table arsen_catalog_items
- POST /api/v1/integrations/arsen/items/batch
- DRUG / GOODS category derived server-side from isDrug
- idempotent SHA-256 source fingerprint
- batch size up to 100
- catalog counts/latest item in existing Arsen status endpoint
- unit tests for duplicate IDs, idempotency, and category mapping

User-selected transferred business fields:
arsenDrugId, category, persianName, genericName, persianBrandName,
brandName, unit, shapeName, packetQuantity, salesPrice,
lastPurchasePrice, isActive, description.

Explicitly excluded:
NationalCode/IRC, producer, group/subgroup, tax flag.

Barcodes were excluded from Phase 1 and were added later by ARSEN_CATALOG_BARCODE_SYNC_20261103.txt.

This patch does not create the backfill/Windows bridge yet.
