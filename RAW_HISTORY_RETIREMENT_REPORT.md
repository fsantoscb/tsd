# Raw History Retirement Report

## Decision

Runtime replication of raw Oracle Audit events is retired for DTG. Normal writer runs now ingest current snapshots plus compact `production_daily_actuals` aggregates only.

Physical deletion of `source_audit_events` and `production_events` is deferred. Those tables still serve explicitly identified Underprint productivity, order-history, administration, and ERP-native/manual Screen Print history paths. Deleting either table would create a known data-loss risk.

## Result

- Normal writer raw Oracle Audit calls: 0
- Raw rows inserted by the compact DTG backfill: 0
- `source_audit_events` preserved: 1,415,493 rows
- `production_events` preserved: 1,050,439 rows
- Compact DTG aggregate rows: 3,074
- Compact aggregate duplicate keys: 0
- Physical database size reduction: deferred until every remaining consumer has an approved compact replacement

The simplification benefit is immediate for runtime stability and bounded ingestion payloads. Storage reclamation is intentionally not claimed in this release.

## Safety gate

No ambiguous dependency was deleted. The remaining dependencies are documented and preserved, so runtime cutover may proceed without destructive raw-history retirement.
