# Canonical V2 C5.5 Audit and DTG History

## Result summary

| Measure | Count |
| --- | ---: |
| Audit PROD total | 76,092 |
| Audit canonical-required | 0 |
| Audit operational-required | 76,092 |
| Audit derived rows | 0 |
| Audit obsolete/test | 0 |
| Audit unknown | 0 |
| Audit migrated/preserved | 76,092 |
| DTG history PROD total | 826 |
| DTG authoritative source events | 65,459 |
| DTG migrated/preserved view rows | 826 |
| DTG derived/excluded | 0 |
| DTG unknown | 0 |

## Authority decisions

`AUDIT_HISTORY_AUTHORITY = ORACLE/WMS source_audit_events`

`DTG_HISTORY_AUTHORITY = ORACLE/WMS source_audit_events`

`v_dtg_order_history` is a derived cache/view. It groups DTG Pick (`PG11 -> DTGS`) and DTG Print (`DTGS -> PWL1`) movements by `order_no`; it is not an independent production-history table.

The 826 rows represent 826 orders. Of these, 387 have at least one Print transition and 439 have Pick history but no observed Print transition. There are 33,571 Pick events and 31,888 Print events. The view spans 2 August through 18 September 2026.

Machine, asset, job ID, Sales Order Line and recipe/profile are not present in this source and remain `NOT_OBSERVED`. Order association, operator, timestamps, movement locations and quantities are source-confirmed at event level. No machine identity is fabricated.

## Migration strategy and provenance

All 76,092 source movement events were migrated from production read-only into Canonical V2 with original source IDs, actors, timestamps, quantities, movement fields, raw hashes and source import timestamps preserved.

Provenance is:

- raw movement event: `SOURCE_CONFIRMED`, migration path `MIGRATED_FROM_PROD`;
- `v_dtg_order_history`: `DERIVED`;
- absent machine/job/line attributes: `NOT_OBSERVED`.

No production-derived row is relabelled as independently source-confirmed when it is derived.

## Reconciliation

| Check | PROD | V2 | Result |
| --- | ---: | ---: | --- |
| Raw audit events | 76,092 | 76,092 | PASS |
| DTG history orders | 826 | 826 | PASS |
| Duplicate source IDs | 0 | 0 | PASS |
| Duplicate raw hashes | 0 | 0 | PASS |
| Oldest source event | 2026-08-02 20:37:36 UTC | same | PASS |
| Newest source event | 2026-09-18 07:35:02 UTC | same | PASS |
| Canonical derived production events | legacy 55,163 | 48,582 | EXPECTED DERIVED MODEL DIFFERENCE |

The production-events difference is not a source-history loss. Production contains legacy transformation results; V2 rebuilt the canonical metrics from the complete source history using the current rules.

## Idempotency

The complete source history is present in V2. Re-applying all existing source rows produced zero inserts. Unique source IDs and hashes remain duplicate-free, and original timestamps remain unchanged.

## Current load isolation

Historical production is never reconstructed from current Workbank. Machine Load continues to use `v_current_workbank`; DTG history and performance history use `source_audit_events` and its derived view. Tests keep `currentLoad` and `historicalProduction` as separate measures and prohibit addition.

## Remaining blockers outside C5.5

- capacity configuration parity;
- four maintenance work orders;
- three consecutive complete V2 syncs;
- scheduler, preview and cutover remain off.

## Gate

`C5.5 AUDIT & DTG HISTORY: PASS`
