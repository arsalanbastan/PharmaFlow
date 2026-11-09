# Price increase source audit — 2026-11-09

Source: https://github.com/arsalanbastan/PharmaFlow
All source was freshly cloned from GitHub. No workstation archives were used.

Development branch: `feature/price-increase-management`.
Base: staff branch `bb9e9a8a7301b9f41eb688d6e0adce6316ba1deb` plus a clean merge of main `9ef8e90030093c476b100604f15f532de1b855bf`.
The staff branch contains the latest staff/web/scanner/POS work; main contributes the Arsen sync error report missing from that branch.
Other divergent branches were inspected but not merged: their purchase invoice/sync/experimental changes are unrelated to this feature and require separate integration decisions.

Remote branch inventory at start:

```text
2026-11-04 17:03:55 +0330 bb9e9a8a7301b9f41eb688d6e0adce6316ba1deb origin/feature/staff-web-invoice-redesign-20261018 fix(staff web): mirror camera stream in HTML scanner preview
2026-10-20 08:30:15 +0330 9ef8e90030093c476b100604f15f532de1b855bf origin Remove empty accidental bridge file
2026-10-20 08:30:15 +0330 9ef8e90030093c476b100604f15f532de1b855bf origin/main Remove empty accidental bridge file
2026-09-26 00:41:58 +0330 3deba5cc9917b269a35c9899af8fdebd470c5342 origin/feature/staff-sales-invoices-20260923 build(staff-web): fix invoice alignment and unnamed buyers
2026-09-21 13:20:32 +0330 2773642f210d256b1f6a122dd73020cd22ee572c origin/fix/cash-attachment-upload-403-20260921 fix(storage): generate S3-compatible presigned attachment upload URLs
2026-09-20 19:45:15 +0330 68447e2bcdfbe92f4404a0a3e1bfa3838efbd6c3 origin/feature/purchase-invoice-redesign-20260920 feat(invoices): redesign settlement UI and per-invoice discounts
2026-09-20 16:52:28 +0330 99be6ca707b5c38d2c851515b6bc10d83b895fdb origin/feature/arsen-sync-error-report-20261020 fix(sync): do not fail completed sync for isolated cheque conflict
2026-09-20 16:52:28 +0330 99be6ca707b5c38d2c851515b6bc10d83b895fdb origin/fix/cash-attachment-soft-deleted-parent fix(sync): do not fail completed sync for isolated cheque conflict
2026-09-20 15:11:27 +0330 6a771a6fcff091ea538db0f74925f6f241c134b7 origin/fix/mobile-sync-isolation-20260920 fix: recover sync after isolated cheque conflicts
2026-09-19 09:21:17 +0330 fb0fa2d1d47c3bb5777d64c78ff556061daa84d2 origin/dev/manager-next-20260917 fix(dev): restore login overlay and password controls
2026-09-17 10:51:22 +0330 158206b2183ccc34f1e3b80ba6491cecc764ba65 origin/feature/admin-invoice-settlement-20260917_104439 fix: complete invoice settlement admin build
2026-09-17 10:19:57 +0330 acdbf86339e5a60bda1b31f510bb76cf69360471 origin/sync/pharmacy-production-20260917 Sync current pharmacy production backend
2026-09-05 00:40:08 +0330 6040d11346c6b72fe57608fcda9e3283993d612a origin/work/next-release feat(catalog): add smart live search
2026-08-20 17:38:36 +0330 6c5ef52105dbb3e8b517e7dc53aeaad4e44b53dc origin/backup/laptop-20260812 checkpoint: manager 1.0.4 and staff 1.0.2
2026-08-12 00:44:37 +0330 50ef3d29d15a18c6c1536622fa1f6db434f6c3c0 origin/feature/dashboard-v1 merge: integrate production backend deployment with laptop work
2026-07-22 18:26:29 +0330 0c6d3052a3cb6011cd2234f716eb4e4cfebc550c origin/feature/company-module-completion feat(bank): complete repository implementation
```

## Behavior

Manager: menu → افزایش قیمت‌ها. Create drug/goods notice with name, exact new price in rials, Jalali effective date, source and notes. Add optional image/PDF attachments from the saved record (repeat for multiple attachments).
Staff Android/Web: افزایش قیمت menu, history/search/category/status/Jalali date range, attachment download/share, explicit confirmation after manually applying the price in the main system.
Shared Flutter package `packages/price_increases_ui` keeps UI behavior identical across all clients.

Confirmations are per employee: each authenticated staff member may confirm once per notice. Pending/confirmed staff filters apply to the current employee; manager filters mean no confirmations/at least one confirmation. Names and IDs are snapshotted from the authenticated principal; confirmation timestamps are database-generated. Retries preserve the original timestamp. All staff confirmation records remain visible in history.

No edit/delete endpoint is provided for notices or confirmations, preserving history. Attachments are JPEG/PNG/WebP/PDF, up to 10 MiB each; signed upload/download URLs and server verification reuse the existing document-storage conventions, under a separate namespace. Only confirmed attachments appear in history. Upload failures can be retried from the saved record without recreating the notice.

Permissions reuse existing policy: manager role plus managerAppAccess for creation/attachments; staff role plus canCreateOrders for confirmation. Both roles can view. Server guards are authoritative. No Arsen write paths, catalog price updates, operational database connections or Liara deployments were introduced or executed.

## Verification

- Backend TypeScript build: PASS (local Node 24; repository/CI target remains Node 22).
- Full backend suite: 55 suites / 231 tests PASS; feature/access suite contributes 33 tests.
- Fresh isolated PostgreSQL 18: all 31 migrations PASS, including the new additive migration.
- Real DB integration: PASS for exact Decimal(18,2), eight concurrent retries, unique confirmation/audit event, independent staff histories, server timestamp and transaction rollback on audit failure.
- Dart formatter/parser for changed files: PASS, without Flutter initialization or network calls.
- Flutter widget tests, analyzer, Android APKs and web build: NOT RUN. Flutter SDK initialization was blocked by automatic approval review for attempted cloud metadata access. No bypass was attempted.
- New CI workflow covers Node 22/PostgreSQL 17 and Flutter 3.44.4 checks, without deployment steps; NOT EXECUTED because the branch cannot currently be pushed.
- Real S3 upload/download and device/browser interaction: NOT VERIFIED; covered only through service/storage boundary checks and prepared Flutter tests.

## Access / release status

A read-only `git ls-remote`, clone, branch inventory and history inspection succeeded. `git push --dry-run` failed because GitHub write authentication is not configured. The new branch exists only in this checkout until an authorized push is possible. No claim is made that it exists on GitHub.
No main/official branch, remote reference, live database or Liara deployment was changed.

## Developer validation

From backend/pharmaflow-api: `npm ci`, `npm run build`, `npm test -- --runInBand`.
For DB integration use ONLY an isolated localhost database whose name ends in `_test`: apply migrations there, then `node test/price-increases.integration.cjs`. The integration runner rejects other hosts/database names.
For Flutter: run pub get in the shared package and both apps, then the shared widget tests, both analyzers, staff web build and both Android debug builds. See `.github/workflows/price-increase-checks.yml`.
Do not use `npm start` against production for validation: the existing start command runs migrations.
