# Routing Architecture Phase A Result

## Delivery boundary

Phase A establishes canonical production master data only. Routing Master, production orders, BOM/MRP, capacity-engine replacement, KPI rewrites and production deployment remain outside this phase.

## Safety checkpoint

- Baseline commit: `221560026aec764e3e546bd4647affda9d28170f`
- Safety tag: `pre-routing-architecture-v1`
- Delivery branch: `feature/routing-architecture`
- Remote: `https://github.com/fsantoscb/tsd.git`

## Delivered

- Organization-scoped Product Families, Product Types and Products.
- Source-to-canonical Product Mappings with explicit `UNMAPPED` handling.
- Canonical Operations, Work Centers and Production Resources.
- Optional linkage between production resources and maintenance assets, protected against cross-organization assignment.
- Product-mix classification view using invoker security.
- RLS read access for organization members and write access for administrators and supervisors.
- Compact administration page at `/admin/production-master`.
- Reusable code normalization rules and focused unit coverage.
- Architecture, migration and master-data documentation.
- CI workflow for lint, typecheck, tests and conditional build.

## Operational notes

- The migration is committed but intentionally not applied to production in Phase A.
- WMS remains authoritative for inventory and warehouse movement.
- BOM/MRP remains a future standby capability.
- GitHub publication requires an authenticated GitHub credential on this workstation.
