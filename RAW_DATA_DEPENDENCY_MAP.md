# Raw Data Dependency Map

## Classification

| Object | Source | Written by | Read by | Why it exists | Rows | Size | Replacement | Required after cutover? |
| --- | --- | --- | --- | --- | ---: | ---: | --- | --- |
| `source_audit_events` | Oracle `ISIS_AUDIT` | `OracleSourceReader` -> `/audit-backfill` -> `stage_audit_backfill` / `ingest_audit_backfill` | `v_dtg_order_history`, admin dataset/detail, UP productivity, legacy flow/KPI readers, event rebuild functions | Raw Oracle movement replica | 1,415,493 | 1,130,881,024 B | Current snapshots plus compact process aggregates; retain only explicitly proven order-history/current evidence | NO for historical replication; limited replacement evidence may be needed |
| `production_events` | Derived from Oracle Audit plus ERP manual Screen Print events | Audit rebuild functions and manual Screen Print action | Performance/flow/KPI readers, UP productivity, Screen Print event page | Mixed raw-derived and ERP-native event fact | 1,050,439 | 785,981,440 B | `production_daily_actuals` for DTG analytics; preserve ERP-native/manual facts separately | NO for Oracle-derived event history; YES for ERP-native/manual facts until separated |
| `production_daily_actuals` | Read-only Oracle aggregate query | `/dtg-daily-actuals` -> `replace_dtg_daily_actuals` | Performance workload/KPI reader | Compact canonical DTG fact | 2,910 | 2,039,808 B | Reuse as canonical compact fact | YES |
| `v_dtg_order_history` | `source_audit_events` | Database view | `apps/web/lib/source-data.ts` | Per-order pick/print timestamps and count | derived | view | Current Workbank/order snapshot plus a bounded order-history summary if operationally required | Replace before raw retirement |
| Raw Audit API | Agent raw Audit array | `apps/web/app/api/ingest/audit-backfill` and DB RPCs | Writer `syncOnce` | Historical replication transport | n/a | n/a | Remove from normal runtime after aggregate path passes | NO |

## Executable consumers

| Consumer | Classification | Current dependency | Exact replacement path |
| --- | --- | --- | --- |
| `apps/oracle-sync/src/source-reader.ts` | HISTORICAL_RAW writer | Queries individual `ISIS_AUDIT` rows for normal sync | Keep SELECT-only compact `readDtgDailyActuals`; remove raw Audit from normal `read()` |
| `apps/oracle-sync/src/sync.ts` | HISTORICAL_RAW writer | Posts raw events to `/audit-backfill` in batches of 500 | Independent current-state sync plus compact aggregate refresh |
| `apps/oracle-sync/scripts/backfill-audit.ts` | HISTORICAL_RAW writer | Historical event backfill | Deprecate/guard; historical refresh uses bounded aggregate queries |
| `apps/web/lib/source-data.ts` admin Audit dataset | HISTORICAL_RAW | Browses `source_audit_events` | Deprecate raw browser or point to explicit retained evidence only |
| `apps/web/lib/source-data.ts` order detail/history | HISTORICAL_RAW | Raw Audit rows and `v_dtg_order_history` | Current snapshot plus compact bounded order-history summary where needed |
| `apps/web/lib/up-productivity.ts` | ANALYTICAL_AGGREGATE built from raw | Joins `production_events` to `source_audit_events` | Future compact UP aggregate; raw objects must be preserved until this replacement exists |
| `apps/web/lib/erp-kpis.ts` | ANALYTICAL_AGGREGATE | Reads production event facts | DTG reads `production_daily_actuals`; non-DTG remains on preserved canonical source until separately migrated |
| `apps/web/lib/performance-workload.ts` | ANALYTICAL_AGGREGATE | Production actuals | Reuse `production_daily_actuals` |
| `apps/web/lib/flow-dashboard.ts` / `production-flow-kpis.ts` | CURRENT_STATE plus historical same-day dispatch | Uses current snapshots and event facts | Current Workbank/Stock snapshots plus bounded current operational facts |
| `apps/web/lib/labour-dashboard.ts` | ANALYTICAL_AGGREGATE | Production facts for productivity joins | Compact aggregate join; Deputy semantics unchanged |
| Screen Print actions/page | ERP_NATIVE | Writes/reads manual `production_events` | Preserve; do not delete with Oracle-derived history |

## Database dependencies

- `ingest_sync_batch(payload jsonb)` writes current snapshots and historically included raw Audit events.
- `stage_audit_backfill(...)` stages raw Audit rows.
- `ingest_audit_backfill(...)` persists raw Audit rows and triggers derived rebuild behavior.
- `normalize_production_event_units()` resolves Oracle-derived units from raw events.
- `replace_dtg_daily_actuals(...)` is the compact absolute-window replacement path.

No database view was returned by the replacement project's information-schema dependency query, but repository contracts and live application code prove `v_dtg_order_history` as a raw consumer. It is therefore treated as a dependency rather than ignored.

## Destructive-action ruling

There are no UNKNOWN dependencies permitted for deletion. Two consumers are explicitly **not yet replaceable** in this phase:

- UP operator productivity.
- ERP-native/manual Screen Print events mixed into `production_events`.

Therefore raw tables remain preserved until their required data is separated or replaced. This does not block disabling DTG raw replication, but it blocks wholesale deletion of `production_events` and `source_audit_events`.

## Gate 1

**PASS for design; destructive action remains prohibited until later gates.**

- Every raw object has a known writer: PASS
- Every executable application consumer identified: PASS
- UNKNOWN destructive dependency: 0
- Explicit replacement/preservation path for each required consumer: PASS

