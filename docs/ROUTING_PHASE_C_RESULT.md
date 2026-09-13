# Routing Architecture Phase C

Phase C establishes an application-owned production execution foundation without replacing legacy operational views.

## Delivered

- Backward-compatible extension of the existing planning-owned `production_orders` table.
- Product and source-order links, production status, planned and actual quantities.
- Immutable Routing code, name and revision snapshots.
- Immutable ordered Production Operation snapshots with operation and Work Center identity.
- Production Operation lifecycle, quantities, timestamps, planned date and shift.
- Current, next and last-completed operation calculation foundation.
- Organization-scoped RLS, role-controlled execution and audit trail.
- Local database integration tests covering snapshot history and access isolation.

## Compatibility boundaries

- Existing planning records remain valid as `UNROUTED` records.
- Flow, KPI, Planning and Capacity continue to use their legacy engines.
- Oracle validation and source-event reconciliation are deferred to Phase D.
- No BOM/MRP or WMS stock ownership changes.
- No production Supabase migration or deployment was performed.

## Validation

- Clean local Supabase reset applied every migration through Phase C.
- Phase B and Phase C database/RLS integration suites passed.
- Lint and typecheck passed.
- 130 unit tests passed.
- Production build passed.
- Production Supabase was not accessed or modified.
