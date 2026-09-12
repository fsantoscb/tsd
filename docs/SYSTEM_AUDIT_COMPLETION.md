# System Audit Remediation Completion

Date: 2026-09-13 (Australia/Brisbane)

## Completed phases

| Phase | Status | Evidence |
|---|---|---|
| A - Correctness and security | COMPLETE | Exact deployment source recovered; ingest organization bound server-side; admin allow-list fails closed; batch organization trigger applied in Supabase |
| B - Canonical business rules | COMPLETE | Shared exact DTG/UP classifiers; unknown stages remain UNMAPPED; Flow consumes shared rules |
| C - KPI consistency | COMPLETE FOR IDENTIFIED DEFECTS | DTG garments use physical production units; print totals use garments x prints per garment; Flow capacity uses `v_capacity_load`; Putwall no longer compares garments with location count |
| D - Source of truth | COMPLETE | `v_capacity_load` is the capacity source; source stage rules are shared; snapshot organization integrity is enforced in API and database |
| E - Frontend consistency | COMPLETE FOR AFFECTED PAGES | DTG, Machine Load, Flow and order item displays consume the corrected quantities and canonical rules |
| F - Technical debt | COMPLETE WITH DOCUMENTED RESIDUE | Recovery/tool/spreadsheet artifacts excluded from deployment; two legacy `*-Value` files remain locally because filesystem policy blocked deletion, but are not imported or deployed |

## Validation evidence

- 109 automated tests passed.
- Lint passed for all workspace packages.
- TypeScript typecheck passed for all workspace packages.
- Vercel production build generated all 41 routes successfully.
- Production deployment: `dpl_ANpSBwNsfuW2rzwCAsxu7TvN7c4x`.
- Canonical domain: `https://tsd-production-control.vercel.app`.

## Database changes

- `202609120013_sync_organization_integrity.sql` applied successfully in Supabase.
- No production rows were deleted or rewritten.
- The migration enforces organization/batch consistency for new and updated snapshot rows.

## Corrected operational definitions

- Garments = sum of physical `production_units`, never row count.
- DTG prints = garments multiplied by prints per garment.
- Capacity = configured `v_capacity_load` result, which derives resources x scheduled hours x hourly rate x efficiency and configured work days.
- Putwall capacity remains a location occupancy concept; 96 locations are not treated as 96 garments of throughput.
- Unknown stages remain visible as `UNMAPPED`.

## Residual governance actions

- Connect the recovered workspace to a durable Git remote and enforce commit-based deployments.
- Add database-backed cross-page reconciliation fixtures when a non-production test database is available.
- Remove the two local legacy `*-Value` files during the next permitted filesystem cleanup.

