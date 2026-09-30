# UP shift daily actuals — Stage A local schema contract

## Approved scope and lineage

Base: 877a013904c61bc0fe9296dfdcb24ee38f614601, clean canonical schema worktree.
Production ledger read-only verification contains 001–014, 20260924232247,
20260926093134, 20260929103104, 20260929173001, 20260930081042 and
20260930121114. Local rollback 20260930151207 is NOT applied and must never
be swept into a bulk push. This commit is local only: no migration application,
Production data write, deployment, connector change, Preview or backfill.

Migration: 20261001050728_up_shift_daily_actuals.sql, newly generated unused
timestamp after the latest local lineage. Preserve this version thereafter.

Implementation sequence: write SQL contract test; add minimal empty schema;
review schema/security and future contract; run available static checks;
commit exactly migration, SQL test and this document. No application edits.

## Schema and security

Only new relation: public.up_shift_daily_actuals. UUID surrogate PK; unique
(organization_id, operational_date, shift_code). No jobs field. Valid shifts:
SHIFT_1/SHIFT_2/SHIFT_3/OUT_OF_SHIFT. Numeric garments preserve fractional WEIGHT.
Nonnegative garments and event counts; existing CURRENT/STALE/MISSING vocabulary.
Organization FK uses default NO ACTION on update/delete, matching up_daily_actuals.
Owner postgres; RLS enabled; same organization-role SELECT policy; authenticated
SELECT only; service_role ALL; no public/anon privileges. No user triggers or RPC.
Unique btree supplies the organization/date prefix: no extra period index.
Existing tables, functions, views, consumers and historical migrations stay unchanged.

## Snapshot identity is correlation, NOT completeness

source_snapshot_id is required UUID with NO default and NO FK to sync_batches.
sync_batches/sync_runs describe the main operational sync, not the later UP
read-only Oracle aggregate extraction. Each future UP extraction supplies one UUID
shared by all its shift rows and daily summary payload. No companion table now.
An ID alone proves neither a consistent Oracle read nor complete period coverage.
Future writer must validate both and commit shifts plus daily compatibility in
the SAME transaction. The daily table remains unchanged in Stage A, so it cannot
yet retain that identity; no claim of durable daily snapshot certification now.

## Future contract — design only

Evolve the existing endpoint explicitly/versionedly; do not activate a writer here.
Payload includes organizationId, from, to, sourceSnapshotId, complete coverage
for EVERY date, rows by operationalDate/shiftCode, and dailySummaries.
Coverage records distinguish a completely read date with no qualifying source
events from a missing/failed/partial extraction; omitted shift rows are allowed
only when validated coverage confirms no events. Do not manufacture zero rows.
A real source aggregate whose WEIGHT sums to zero remains a real aggregate row.
OUT_OF_SHIFT is persisted only when actual classified events exist.

Future function validates the entire bounded period before deleting anything:
organization identity, complete date coverage, unique grain, allowed shifts,
numeric values, one snapshot identity, and daily-vs-shift reconciliation.
Acquire an organization-scoped transaction lock to serialize overlapping writers;
replace target shift rows AND up_daily_actuals daily summaries atomically.
Any failure rolls back both. Legacy writers must be prevented from independently
overwriting activated periods. Service-role access only; no new user access.

Daily jobs use the current direct Oracle daily distinct identity calculation
(FROM_PACK_ID, TO_PACK_ID, ONO, AUDIT_ID fallback), not SUM of shift distincts.
Every source event must classify exactly once. Daily source_event_count equals
SUM(shift source_event_count). Discovery counts for 23/24/25/28/29/30 Sep were
49/50/35/60/47/37 and matched persisted daily counts. Normal observed data supports
additivity; future tests must also reject overlapping classifier rules.
Shift last_source_timestamp is MAX event time for its own date/shift;
daily last_source_timestamp is MAX across that date. They need not all be equal.
Neither timestamp maximum certifies completeness or detects late backdated events.

## Existing consumers and invariants

Daily Production Flow keeps readDailyOutputSources/buildDailyProductionFlow reading
up_daily_actuals. Performance legacy UP, operational UP, Labour, Capacity, DTG,
Deputy, shifts, middleware and UI remain untouched. New table starts EMPTY.
Oracle predicate remains UPPER(FROM_LOCATION) LIKE '%UNDERPRINT%' AND
UPPER(TO_LOCATION) NOT LIKE '%UNDERPRINT%'; quantity WEIGHT only, no QTY fallback.

## Execution certification

NOT EXECUTION-CERTIFIED. No authorized disposable database is confirmed.
Do not run fixture SQL against Production. No Docker setup or tooling installation.
Test intentionally requires tsd.disposable_db='true', which is an explicit opt-in,
NOT an identity verification; first independently verify the disposable target.
Use psql ON_ERROR_STOP. Migration must be tested in disposable lineage matching
Production, EXCLUDING the unapplied rollback migration. Capture pre/post existing
daily metadata/data/writer externally around migration as an activation gate;
the SQL test also checks fixture operations do not change the daily contract.
Test writes fixture organization/shift rows only inside BEGIN/ROLLBACK.
Prepared assertions are not reported as executed PASS.
