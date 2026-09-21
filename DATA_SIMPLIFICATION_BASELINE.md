# TSD Data Simplification Baseline

Captured on 2026-09-21 before architecture changes.

## Identity and safety

| Item | Baseline |
| --- | --- |
| Repository | `https://github.com/fsantoscb/tsd.git` |
| Worktree | `C:\Projects\tsd-canonical-data-simplification` |
| Branch | `codex/canonical-data-simplification` |
| Base SHA | `73f5013db6e48185535fb0868d7d281e2ec2c6ec` |
| Replacement Supabase | `eziirebccovlvhaonsgw` (`ACTIVE_HEALTHY`) |
| Legacy production | `gdajktoqmajipivpdude` (`ACTIVE_HEALTHY`, untouched) |
| Old Canonical V2 | `saecycamkyvzzppxudzq` (preserved) |
| DEV | `tlflipdeahgwsueerkex` (`INACTIVE`, untouched) |
| Oracle | READ ONLY |
| Replacement compute | Nano, approximately 0.5 GB RAM |
| Replacement scheduler | DISABLED |
| Replacement cutover | NOT EXECUTED |
| Database transaction mode | `default_transaction_read_only=on` |

The worktree started clean and is a linked Git worktree. It is intentionally not linked by the Supabase CLI to any project. All database inspection used the Management API with `read_only=true` against the positively identified replacement project.

## Database footprint

Logical database size: **1,999,826,067 bytes** (approximately 1.86 GiB / 2.00 GB decimal).

| Table | Exact rows | Heap bytes | Total bytes |
| --- | ---: | ---: | ---: |
| `source_audit_events` | 1,415,493 | 413,114,368 | 1,130,881,024 |
| `production_events` | 1,050,439 | 476,569,600 | 785,981,440 |
| `source_release_order_lines` | 22,839 | 3,858,432 | 14,950,400 |
| `source_workbank_items` | 9,206 | 8,257,536 | 15,458,304 |
| `source_orders` | 1,151 | 811,008 | 2,252,800 |
| `production_daily_actuals` | 2,910 | 1,064,960 | 2,039,808 |
| `sync_batches` | 99 | 32,768 | 90,112 |
| `sync_runs` | 203 | 49,152 | 114,688 |

The two raw/derived event tables consume approximately 1.92 GB including indexes. The compact daily fact is approximately 2 MB.

## Largest indexes

| Index | Table | Bytes |
| --- | --- | ---: |
| `source_audit_events_organization_id_raw_hash_key` | `source_audit_events` | 212,246,528 |
| `production_events_organization_id_source_source_record_key__key` | `production_events` | 138,526,720 |
| `source_audit_events_dtg_history_idx` | `source_audit_events` | 92,798,976 |
| `source_audit_events_record_key_idx` | `source_audit_events` | 88,104,960 |
| `idx_source_audit_events_org_source_id` | `source_audit_events` | 88,096,768 |
| `source_audit_events_organization_id_source_audit_id_key` | `source_audit_events` | 88,096,768 |
| `production_events_pkey` | `production_events` | 80,568,320 |
| `production_events_timestamp_idx` | `production_events` | 72,540,160 |
| `source_audit_events_pkey` | `source_audit_events` | 59,219,968 |
| `source_audit_event_idx` | `source_audit_events` | 51,650,560 |

## Writer baseline

The current writer performs one source read containing Orders, Release Lines, Workbank, Stock and raw Audit events. It posts the current-state payload to `/api/ingest/sync`, then posts raw audit history to `/api/ingest/audit-backfill` in sequential batches of 500. The cursor is advanced only after the complete operation.

Current stages:

1. Agent control claim and heartbeat.
2. Parallel Oracle reads for Orders, Release Lines, Workbank, Stock and raw Audit events.
3. Current-state `/sync` write.
4. Sequential raw Audit writes in 500-event payloads.
5. Production-event rebuild on the final Audit payload.
6. Optional compact DTG daily refresh exists as a separate command, not the normal `syncOnce` pipeline.

Current database write functions related to the heavy path:

- `ingest_sync_batch(payload jsonb)`
- `stage_audit_backfill(...)`
- `ingest_audit_backfill(...)`
- `normalize_production_event_units()`
- `replace_dtg_daily_actuals(...)`

## Raw-history objects and aggregate objects

Raw Oracle-derived persistence:

- `source_audit_events`
- `production_events` rows with Oracle-derived event grain
- `v_dtg_order_history` over `source_audit_events`
- raw Audit backfill API and database functions

Compact analytical persistence:

- `production_daily_actuals`
- `replace_dtg_daily_actuals(...)`
- `/api/ingest/dtg-daily-actuals`

## Gate 0

**PASS**

- Clean isolated worktree: PASS
- Replacement project positively identified: PASS
- Legacy untouched: PASS
- Oracle read-only contract: PASS
- Baseline rows and sizes captured: PASS
- Executable dependency search completed: PASS

