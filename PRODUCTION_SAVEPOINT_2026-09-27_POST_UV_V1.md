# TSD PRODUCTION CONTROL
# PRODUCTION SAVEPOINT — POST UV V1

Verified 27 September 2026, approximately 18:24 Australia/Brisbane. This records the live baseline after UV V1 go-live and before UV V2 or further development. It is documentation, not a deployment or a database backup. Live counts below are observations, not acceptance constants.

## 1. Web production

| Item | Verified value |
|---|---|
| Vercel project | `tsd-production-control` |
| Project ID | `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox` |
| Domain | `https://tsd-production-control.vercel.app` |
| Production alias deployment | `dpl_FaUamxywfDHXenCGNpgUcKersaPm` — READY, production target |
| Deployment source commit | `12d78d992522648d632fb7dc87f3c675eeb76371` (clean source used for the deployment/promotion) |
| Source branch | `feature/uv-sidebar-navigation` |
| Source tree | `86b216f1b08bce7b996def23e1ee5e0fdcba9e2b` |
| Source worktree | `C:\Projects\tsd-uv-v1-ui` |
| Source gitDirty before documentation | `0` |
| Source tag | `production-savepoint-post-uv-v1-2026-09-27` → source commit above |

The authenticated Production pages DTG, Underprint, Release Queue and UV rendered on 27 September. The UV page reads `public.v_uv_operational_orders`, has six metric cards, a table, order/customer search, stage filter and Clear. The EXECUTION sidebar sequence is DTG, Underprint, UV, Dispatch, Hold, Scan, with UV linking to `/production/uv`.

Release Queue retains its 20-column presentation, in order: Priority, Order #, Customer, Received, Due, Release status, Blockers, Route, Stop Ship, Cost centre, DTG, Underprint, UV, Hats, Custom Emb, Finished, Stickers, Visual, Production, Eyewear. Order # is plain text and the Production Control return link points to `/`. The live page showed 189 operational orders (88 Eligible, 23 Not Approved, 77 Blocked, 1 Future Due); these values will move with Oracle data.

## 2. Database and migration lineage

Production Supabase projectRef: `eziirebccovlvhaonsgw`.

The read-only Production migration ledger has 16 entries. Latest: `20260926093134_uv_v1_canonical_derivation`; preceding relevant migration: `20260924232247_preserve_referenced_sync_batches`. Both are applied. Earlier recent versions include `014_up_daily_actuals`, `013_compact_dtg_order_history`, `012_compact_dtg_daily_actuals_contract`, and `011_dtg_overtime_shift_rule`.

Critical Production objects were found in `pg_catalog`: functions `ingest_sync_batch`, `claim_sync_work`, `finish_sync_work`; relations `sync_batches`, `sync_runs`, `sync_agent_heartbeat`, `source_orders`, `source_order_release_lines`, `source_workbank_items`, `source_stock_items`, `dtg_order_history_summaries`, `production_daily_actuals`, `up_daily_actuals`, `shift_rules`, `v_dtg_operational_orders`, `v_up_operational_orders`, `v_release_queue`, and `v_uv_operational_orders`. The UV view exposes all six required quantity fields.

### Schema source

The canonical schema branch is `canonical/production-schema-2026-09-27`, at commit `8a4a1597d49ae5a8d7fd72a8529391b73d39b4d4`, tagged `production-schema-post-uv-v1-2026-09-27`. Its migration directory contains the complete applied lineage `001–014`, `20260924232247`, and `20260926093134`. The Supabase CLI migration list for Production projectRef `eziirebccovlvhaonsgw` showed all 16 versions as both local and remote applied, with no remote-only or local-only version.

The applied UV migration is `20260926093134_uv_v1_canonical_derivation.sql`, Git content hash `5acf1e148d35367ad151caf93b11107fd2ec0bf8`; Production ledger status: **APPLIED**. The earlier `20260924232247_preserve_referenced_sync_batches.sql` has Git content hash `cab0f79fbde970789da61fb7a9ceb432f39d5b68`. The schema branch adds these exact two files to the unchanged `001–014` base. It was committed and tagged for source recovery only; no SQL was run against Production as part of that consolidation.

WEB, CONNECTOR, and SCHEMA are intentionally represented by separate Git references. The web tag identifies the deployed web source, the connector tag identifies the active Oracle connector source, and the schema tag identifies the complete migration-source lineage. They are not interchangeable.

## 3. Active connector

| Item | Verified value |
|---|---|
| Repository/worktree | `C:\Projects\tsd-canonical-data-simplification` |
| Branch | `codex/canonical-data-simplification` |
| HEAD | `2aa6e8738acbd878f6ee5f603f535e0f27937224` |
| Tree | `07b84a08c0b601f43e5fd1f491f9f0bb8b7a3c3c` |
| gitDirty | `0` |
| Connector version observed in successful runs | `0.2.0+33571de` |
| Effective INGEST_API_URL | `https://tsd-production-control.vercel.app/api/ingest` |
| Scheduled Task | `TSD Production Control V2 Sync`, enabled; action uses `apps/oracle-sync/scripts/agent-tick.ps1` and `.env.sync.local` |
| Connector tag | `production-connector-post-uv-v1-2026-09-27` → HEAD above |

Existing `IS_WORKBANK_V` Workbank selection and DTG/UP semantics remain. Additive raw `IS_WORKBANK` is restricted to PG02, PG04 and PG42 for active incomplete orders. Both streams merge into one `workbank[]`, with source-row-ID collision rejected, and persist via the existing `source_workbank_items` ingestion path. There is no second UV Workbank table, endpoint, or payload. Stock remains the existing canonical ingestion. Oracle `PACKDESC` is used by connector quantity calculation (`CARTON` → `WEIGHT`; otherwise `QTY`); raw PACKDESC persistence as `sourcePackdesc` remains deferred in this active connector.

The effective scheduler target is Production. The active configuration check found zero operational Preview targets. Preview is retired: do not use it for connector, scheduler, CLI sync, fallback, validation, or rollback.

## 4. UV V1 canonical contract

One row per Sales Order from `public.v_uv_operational_orders`:

| Metric | Canonical derivation |
|---|---|
| UV PICK | Workbank PG02, canonical `production_units` |
| UV2PRINT | Stock location UV, `SUM(source_weight)` |
| UVPRNT | Stock location UVPRNT, `SUM(source_weight)` |
| STICKER PRINT | Stock STICKRDROP, `ROUND(SUM(source_weight) / 13)` |
| FINISHED PICK | Workbank PG04 + PG42, canonical `production_units` |
| UV PACK | Stock location containing PWL3, `SUM(source_weight)` |

Laser and UV Printer are **not separated** in V1. A future V2 may classify by product/SKU only after independent validation.

### Live UV snapshot

At approximately 18:08 Australia/Brisbane on 27 September: 24 rows, 24 unique Sales Orders, 0 duplicate orders. UV PICK 0; UV2PRINT 0; UVPRNT 0; STICKER PRINT 0; FINISHED PICK 0; UV PACK 25,095. The authenticated Production page displayed the same 24 orders and card totals. These are a time-specific snapshot, not fixed future expectations.

## 5. Runtime health and smoke checks

At approximately 18:23 Australia/Brisbane, the latest `sync_agent_heartbeat.last_seen_at` was `2026-09-27T18:22:46.705+10:00`, `last_success_at` was `18:22:09.034+10:00`, and `last_error` was null. Latest automatic `sync_runs` entry `29991413-f891-4e2f-88a1-a842f778863a` was SUCCESS, completed `18:22:08.699+10:00`, with batch `8a35dd70-2fa0-4f48-a1ae-daa1b37cd253`. That batch was completed, with 1,171 orders, 5,199 Workbank rows, 122 Stock rows, 27,144 release lines, and no error. The previous automatic run was also SUCCESS. No recent FK failure or `ACTIVE_RUN_EXISTS` loop was observed. The Scheduled Task was enabled and Running at the observation instant; its last result was 0.

DTG daily actuals: latest operational date 21 September, latest source event 21 September 14:28 AEST, refreshed 27 September 18:05 AEST. UP daily actuals: latest operational date 21 September, latest source timestamp 22 September 05:54 AEST, synced 27 September 18:05 AEST. These distinguish recent refresh execution from the age of the underlying historical source dates; do not label historical business data current merely from a recent refresh timestamp. Authenticated Production DTG and UP operational pages showed Oracle CURRENT and rendered cards/data. Release Queue and UV also rendered with current data. Performance was not part of the required smoke check and was not certified here.

## 6. Backup and exact data rollback

Supabase dashboard shows scheduled physical backups: **BACKUP ENABLED**. The latest visible backup at inspection was 26 September 2026 14:46:14 UTC. PITR was offered as an add-on with an Enable control: **PITR AVAILABLE_NOT_ENABLED**. A backup at this exact savepoint instant and a tested restore were not demonstrated. **Exact Production data rollback is NOT certified by this savepoint.** Git tags and Vercel deployment restoration do not restore Production data.

## 7. Recovery matrix

| Layer | Savepoint | Recovery method |
|---|---|---|
| Web runtime | `dpl_FaUamxywfDHXenCGNpgUcKersaPm` | Restore Production alias to this exact retained deployment after identity checks |
| Web source | `production-savepoint-post-uv-v1-2026-09-27` / `12d78d9` | Check out exact tagged source; documentation commit is not deployed |
| Connector | `production-connector-post-uv-v1-2026-09-27` / `2aa6e87` | Restore exact connector source and separately verify local Production configuration |
| Database schema | `production-schema-post-uv-v1-2026-09-27`, ledger through `20260926093134` | Recover exact migration source from schema tag; use a separately reviewed forward/reversal migration for any runtime schema change |
| Scheduler | Recorded enabled Scheduled Task and Production `.env.sync.local` target | Restore task configuration, only after compatible web/API/schema are confirmed |
| Production data | Separate scheduled backups; PITR not enabled | Recovery requires an independently verified backup/restore capability, not Git or Vercel |

Schema rollback and data rollback are distinct operations.

## 8. Recovery sequence and gates

If connector or database is involved: (1) freeze scheduler deliberately; (2) verify Vercel project ID `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox` and Supabase projectRef `eziirebccovlvhaonsgw`; (3) restore compatible schema using a reviewed migration, if necessary; (4) restore connector commit/config, if necessary; (5) restore the web alias to the exact deployment; (6) verify Production API/projectRef; (7) re-enable scheduler; (8) validate automatic cycle 1; (9) validate automatic cycle 2; (10) smoke test DTG, UP, Release Queue and UV. Do not use Preview at any step.

Release gates: correct Vercel project ID; correct Supabase projectRef; connector target Production; zero active Preview references; current heartbeat; successful automatic sync; DTG and UP operational pages current; Release Queue and UV load; no unexpected runtime errors. The code/schema source lineage is separately recoverable from the three remote tags. Exact Production data rollback remains uncertified because PITR was not enabled at the savepoint time and no exact-point restore was proven.
