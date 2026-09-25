# TSD PRODUCTION CONTROL — PRODUCTION SAVEPOINT

Captured 25 September 2026, 12:46–12:48 Australia/Brisbane (AEST). This is an observed, multi-layer baseline before subsequent development, not a frozen copy of changing factory data. Read-only checks were used except for creating this document and the local Git tag. No secret values are recorded.

## 1. Purpose and verification status

This document identifies the approved web artifact, active data target, local connector, scheduler and observed runtime health. The expected project, domain, deployment, web commit, Supabase projectRef and connector target matched the values observed. **Database migration history and Production backup/PITR capability were not independently verified.** Exact Production data rollback is **NOT** certified by this savepoint.

## 2. Web

| Item | Observed value |
|---|---|
| Project / ID | `tsd-production-control` / `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox` |
| Domain | `https://tsd-production-control.vercel.app` |
| Deployment | `dpl_9yRh3CZcPBWXaenXJkwgh5kdFYNg`, Production, READY; alias resolved to this deployment |
| Source worktree | `C:/Projects/tsd-release-queue-visual` |
| Branch / HEAD | `hotfix/release-queue-visual` / `8b7b57c1cfc2100a8e50dff749038db42209a44f` |
| HEAD tree | `dff5a23259362f87d8544e3393eda62dd8e11b1e` |
| gitDirty at capture | `0` (before this documentation file) |
| Web source evidence | This clean commit was the source used to create the verified Production deployment. Vercel CLI confirmed deployment identity/READY; the CLI response did not independently expose a Git SHA. |

Web rollback tag: annotated tag `production-savepoint-2026-09-25`, verified to peel **exactly** to `8b7b57c1cfc2100a8e50dff749038db42209a44f`. It was absent from `origin` at initial capture. This documentation file is not part of the tagged runtime tree.

## 3. Supabase

Production's authenticated runtime guard returned projectRef `eziirebccovlvhaonsgw`. The active V2 URL independently points to the same project. No database write was made.

**Migration state:** local migration file `20260924232247_preserve_referenced_sync_batches.sql` exists in `C:/Projects/tsd-production-ingest-contract/supabase/migrations`. Production currently retains 135 `sync_batches`, including referenced release-line data (20,537 current rows), which is consistent with retention no longer deleting older batches. This is **indirect evidence only**: the remote migration ledger and exact latest applied migration were not readable through the available public PostgREST schema. Status of migration `20260924232247` in the remote ledger: **NOT PROVEN**. Critical local migration references include `001_canonical_baseline.sql`, `002_access_control_hardening.sql`, `003_maintenance_ux_v2_lifecycle.sql` and `20260924232247_preserve_referenced_sync_batches.sql`; these filenames are **not** a certified list of remotely applied migrations.

### Critical runtime object manifest

All objects below were exposed by Production PostgREST/OpenAPI at capture time. Table/view existence was additionally checked with read-only `GET ...?select=*&limit=1`. Function paths were inspected, **not executed**.

| Object | Type | Existence / relevant contract |
|---|---|---|
| `ingest_sync_batch` | RPC function | Present, POST; request body contains `payload` |
| `claim_sync_work` | RPC function | Present, POST; accepts agent ID, connector version, interval and organization ID |
| `finish_sync_work` | RPC function | Present, POST; accepts run/status/batch/count/failure fields |
| `sync_batches` | table | Present; 135 rows at capture |
| `sync_runs` | table | Present |
| `sync_agent_heartbeat` | table | Present |
| `source_orders` | table | Present |
| `source_order_release_lines` | table | Present; 20,537 current rows at capture |
| `source_workbank_items` | table | Present |
| `source_stock_items` | table | Present |
| `dtg_order_history_summaries` | table | Present |
| `production_daily_actuals` | table | Present |
| `up_daily_actuals` | table | Present |
| `shift_rules` | table | Present |
| `v_release_queue` | view | Present |
| `v_dtg_operational_orders` | view | Present |
| `v_up_operational_orders` | view | Present |

This manifest establishes endpoint/object availability, not byte-for-byte SQL definitions or migration lineage.

## 4. Connector and scheduler

| Item | Observed value |
|---|---|
| Scheduled Task action | `powershell.exe` launches `C:/Projects/tsd-canonical-data-simplification/apps/oracle-sync/scripts/agent-tick.ps1` |
| Connector repository/worktree | `C:/Projects/tsd-canonical-data-simplification` (linked worktree of the same Git repository as the web source, not a separate repository) |
| Branch / HEAD | `codex/canonical-data-simplification` / `3a948228ad53cfa284e07edb19597106cd91a831` |
| HEAD tree / gitDirty | `28ec1fa40b41e9bca1f0f2f067072effbf1ee034` / `0` |
| Exposed connector version / agent ID | `0.2.0+33571de` / `tsd-v2-production-FELIPE-LT` |
| `INGEST_API_URL` | `https://tsd-production-control.vercel.app/api/ingest` |
| Expected target guard | `eziirebccovlvhaonsgw` |
| Task | `TSD Production Control V2 Sync`, enabled; observed running at 12:42 and subsequently completed with result `0` at 12:47; next scheduled time at inspection 12:48 AEST |

Connector rollback tag: annotated tag `production-connector-savepoint-2026-09-25`, verified to peel **exactly** to `3a948228ad53cfa284e07edb19597106cd91a831`. The WEB and connector worktrees use the **same Git repository** but have **different worktrees, branches and commits**; each has its own tag. Restore this exact connector commit and its Production-targeted local configuration together; Git does not contain the local secret values.

## 5. Runtime health

Observed at approximately 12:47 AEST; timestamps below are Australia/Brisbane. A scheduled cycle may advance these values after capture.

| Signal | Last observed value |
|---|---|
| Heartbeat | `2026-09-25 12:46:33.449`, `online`, no last error |
| Latest successful run | `abd69fd0-95e2-4297-b38a-47d51e5f7787`, SUCCESS, completed `12:44:44.403` |
| Latest completed main batch | `63a449ef-4ca2-47d7-ba65-33ab18c286ac`, completed `12:44:07.130` |
| Oracle | Current by recent agent heartbeat and successful Oracle-sourced ingestion; no direct Oracle query was made in this snapshot |
| DTG daily actuals | Latest operational date `2026-09-25`; last observed refresh `12:44:37.176` |
| UP daily actuals | Latest operational date `2026-09-25`; last observed sync `12:44:43.486`, status `CURRENT` |
| Active/stale runs | One RUNNING run was observed during a scheduler-owned cycle at 12:43; that same run subsequently reached SUCCESS at 12:44. No stale run was evidenced in that window. |

## 6. Release Queue

At `2026-09-25 12:46:28 AEST`, Production `v_release_queue` returned **149 rows / 149 unique orders / 0 duplicates**: ELIGIBLE **61**, NOT_APPROVED **15**, BLOCKED **72**, FUTURE_DUE **1**, UNKNOWN **0**. The source changes with live factory activity; 149 is a timestamped observation, **not a hardcoded expected count**. The Production page had been verified in the immediately preceding release at 148 rows while the view also had 148; the next live snapshot increased to 149.

Final validated table order (20 columns): Priority, Order #, Customer, Received, Due, Release status, Blockers, Route, Stop Ship, Cost centre, DTG, Underprint, UV, Hats, Custom Emb, Finished, Stickers, Visual, Production, Eyewear.

Visual/functional contract: Order # is plain non-clickable text; no expanded details remain; compact `← Production Control` links to `/` above the right-aligned operational total; horizontal scrolling is local to the table, with no page-wide horizontal overflow at the tested narrow viewport; Apply and Clear worked after promotion. The existing process allowlist rejects SCREEN_PRINT and PAK7 (`0` admitted by rule); the view has no standalone SCREEN_PRINT/PAK7 quantity columns. This is a code-contract check, not a count of raw Oracle process lines.

## 7. Preview retirement

Preview project `tsd-production-control-v2-preview` is **not part of the operational architecture**. No connector, scheduler, fallback or Production validation may use Preview. The current connector target is Production, and Preview was not called during this savepoint inspection. Historical or external Preview traffic was not audited.

## 8. Rollback matrix

| Layer | Savepoint | Recovery method |
|---|---|---|
| Web | `dpl_9yRh3CZcPBWXaenXJkwgh5kdFYNg` | Reassign the Production alias to this exact READY deployment. |
| Web source | `8b7b57c1cfc2100a8e50dff749038db42209a44f` | Check out/redeploy the exact commit only after validating project/environment; a rebuild is not identical to reassigning the retained artifact. |
| Database schema | Observed objects; remote migration ledger **not proven** | Review a forward/reversal migration and verify compatibility before applying it. Never infer schema rollback from Git/Vercel. |
| Connector | `3a948228ad53cfa284e07edb19597106cd91a831` plus Production-targeted local config | Restore exact connector commit/config and verify target/secret without printing secrets. |
| Scheduler | `TSD Production Control V2 Sync`, enabled, action/path above | Restore recorded task configuration only after dependent layers are compatible. |
| Production data | **NOT represented by Git/Vercel savepoint** | Use a verified database backup/PITR restore point if exact historical data restoration is required. Exact Production data rollback is **NOT certified by this savepoint**. |

## 9. Recommended recovery order

1. Freeze the scheduler if database or connector recovery is involved.
2. Restore or verify database compatibility.
3. Restore the connector if required.
4. Restore the web deployment.
5. Verify Production Vercel project ID, domain and Supabase projectRef.
6. Re-enable the scheduler.
7. Validate one scheduler-owned automatic cycle.
8. Validate a second automatic cycle for repeatability.
9. Verify DTG, UP, Performance and Release Queue.

Do not execute this sequence merely because this document exists; it requires incident-specific approval and a validated data-recovery plan.

## 10. Health gates after rollback

Require correct Vercel project ID `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox`; Supabase projectRef `eziirebccovlvhaonsgw`; connector target Production; Preview calls `0`; current heartbeat; sync run SUCCESS; current DTG and UP; Release Queue rendering; and no unexpected runtime error. If schema or data restoration is needed, first verify migration history and backup/PITR capability, which were not certified in this snapshot.
