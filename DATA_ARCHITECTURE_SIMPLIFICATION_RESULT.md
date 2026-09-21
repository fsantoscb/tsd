# Data Architecture Simplification Result

## Outcome

The normal Oracle writer no longer replicates raw Audit history. DTG Performance uses compact daily/shift aggregates sourced read-only from Oracle and persisted in `production_daily_actuals`.

## Gates

| Gate | Result |
| --- | --- |
| Baseline and dependency inventory | PASS |
| Compact aggregate contract | PASS |
| Historical aggregate backfill | PASS |
| Source reconciliation | PASS |
| Normal writer without raw Audit | PASS |
| Nano load validation | PASS |
| Raw-history retirement safety | PASS — physical deletion deferred |
| Legacy ERP-owned failover reconciliation | PASS |
| SQL contract test | PASS |
| Application regression | PASS |

## Evidence

- Oracle source range: 2023-09-04 through 2026-09-21
- Compact rows: 3,074
- Garment/event total: 1,262,337
- Print total: 1,782,419
- Duplicate compact keys: 0
- Manual compact writer sync: SUCCESS
- Writer raw Audit count: 0
- Legacy maintenance history missing after merge: 0
- Maintenance orphans: 0
- Screen Print Release Queue/current Workbank (`PAK7`): 0
- Oracle writes: 0

## Validation

- Lint: PASS
- Typecheck: PASS
- Shared tests: 49/49 PASS
- Oracle writer tests: 45/45 PASS
- Web tests: 150/150 PASS
- Total tests: 244/244 PASS
- Production build: PASS
- Compact SQL test: PASS

## Remaining physical storage decision

`source_audit_events` and `production_events` remain physically present because documented Underprint, order-history, administration, and ERP-native history consumers still exist. Runtime raw replication is removed; physical deletion requires a separate, approved replacement for those consumers.
