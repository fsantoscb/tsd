# Canonical V2 - C5.9 Cutover Readiness Review

Date: 2026-09-19 (Australia/Brisbane)

## Verdict

**C5.9 CUTOVER READINESS: BLOCKED**

This review is a readiness gate only. No domain, scheduler, production environment variable, Supabase production object, Oracle object, or production deployment was changed.

## Environment inventory

| Component | Current production | Canonical V2 |
| --- | --- | --- |
| Git branch | Production deployment is independent of the dirty V2 worktree | `canonical-v2` |
| Git HEAD | Published production lineage | `55db6cfbdb476b21f31045fbd282fa7bfb93da68` in the V2 worktree |
| Supabase project | `gdajktoqmajipivpdude` | `saecycamkyvzzppxudzq` |
| Vercel project | `tsd-production-control` (`prj_uPy9OhX0A3RSSC5wFRPiWBeclHox`) | `tsd-production-control-v2-preview` (`prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`) |
| Deployment | `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB` | `dpl_13mTxAW5QEFP2CEpu7zWXEqWpMan` |
| URL | `https://tsd-production-control.vercel.app` | `https://tsd-production-control-v2-preview-i2hscj6co-tsd7.vercel.app` |
| Sync | `factory-1` online against production | No agent heartbeat |
| Latest observed batch | 2026-09-19 01:44:15 +10, completed | 2026-09-19 00:44:24 +10, completed |
| Batch counts | Orders 1,147; workbank 8,323; stock 57 | Orders 1,147; workbank 8,323; stock 57 |

## Source control and reproducibility

The `canonical-v2` worktree is not release-ready. It contains modified files, deleted legacy migration files, and untracked canonical documentation, SQL, scripts, tests, data, and the definitive `supabase/migrations/001_canonical_baseline.sql`.

The currently validated Preview therefore cannot be reproduced from committed HEAD. A detached clean worktree was created at commit `55db6cf`. Its build did not complete: dependency materialization stalled before compilation and produced no `.next/BUILD_ID`. This is recorded as **NOT PROVEN**, not PASS.

Blocker: freeze the intended V2 tree in a reviewed commit, then perform installation, lint, typecheck, tests, and production build from a fresh checkout of that exact commit.

## Database baseline and migration lineage

V2 reports one applied migration: version `001`, name `canonical_baseline`. The repository currently contains only `001_canonical_baseline.sql` in the active migration directory, but that file is untracked. There is no repository `supabase/config.toml`.

V2 inventory:

- 91 public base tables; RLS enabled on all.
- 49 views and no materialized views.
- 240 indexes, 77 triggers, and 49 policies.
- Private bucket `maintenance-private`.
- No detected `pg_cron`, `pg_net`, or Vault extension.

Production migration metadata remains separate and was not changed. The V2 baseline must be committed and reproducibly applied to a disposable verification target before cutover approval.

## Vercel environment matrix

Values were not printed or copied during this review.

| Variable | Production project | V2 Preview | V2 Production | Readiness |
| --- | --- | --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Production | Present | Missing | BLOCKED |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production | Present | Missing | BLOCKED |
| `SUPABASE_SERVICE_ROLE_KEY` | Production | Present | Missing | BLOCKED |
| `INGEST_SECRET` | Production | Present | Missing | BLOCKED |
| `ORGANIZATION_ID` | Present | Missing | Missing | BLOCKED |
| `ADMIN_EMAIL` | Present | Temporary disabled Preview identity | Missing | BLOCKED |
| `TSD_ENVIRONMENT` | Not inventoried as a production guard | Present | Missing | BLOCKED |
| `APP_ENV` | Not inventoried as a production guard | Present | Missing | BLOCKED |

The V2 Vercel project has no Production-scoped runtime configuration. The existing Preview `ADMIN_EMAIL` refers to the disabled C5.8 test identity and must not be promoted.

## Authentication and authorization

C5.8 proved login using a temporary V2 test account. That account is now banned and its maintenance membership is inactive. V2 has no approved production user population.

The required authentication matrix has not been proven for login, logout, refresh, expired/disabled sessions, unauthorized routes, and real operational users.

The database currently exposes broad write policies to `authenticated` for manufacturing orders, products, routings, operations, production demand, production orders, resources, source mappings, and work centers. Some reconciliation, evidence, routing-exception, and source-operation mapping policies are granted to `public`. The only discovered application membership role is maintenance `admin`; no complete operator/supervisor/manager/admin authorization model was found.

Blocker: define and test least-privilege database authorization for anonymous, operator, supervisor, manager, admin, and service-role access. Server-side `ADMIN_EMAIL` checks do not replace RLS.

## Oracle ingestion and single-writer control

Oracle remains read-only. The active Windows task `TSD Production Control Sync` runs every minute and calls a script under `C:\TSD Production Control Full`. That script targets the legacy production ingest URL and contains the Oracle connection endpoint locally. A second legacy task is disabled.

The database claim function uses an advisory transaction lock, rejects an already-running sync, and applies a stale-run lease. This protects concurrent runs inside one target database, but does not prevent two independent databases from being written by two agents reading Oracle.

V2 has no agent heartbeat and is one completed snapshot behind production. The V2 worktree is not the path used by the active production scheduler.

Blocker: prepare a versioned, reviewed V2 agent configuration and a one-writer switch procedure. Never run legacy production and V2 agents concurrently during cutover.

## Final snapshot and delta procedure

The final cutover snapshot has not been executed. It must be performed only during an approved cutover window:

1. Record current production and V2 batch IDs, counts, timestamps, checksums, and freshness.
2. Prevent a new legacy sync from starting and wait for any running legacy ingestion to finish.
3. Run exactly one controlled COMPLETE snapshot into V2 with a unique ingestion run ID.
4. Confirm status `completed`, zero active claims, expected row counts, and no duplicate demand or execution identity.
5. Re-run C5.7 reconciliation and classify every delta as expected timing, approved model difference, data defect, mapping defect, or unknown.
6. Abort if any unknown or unexplained delta exists.
7. Keep the legacy scheduler disabled but intact for deterministic rollback.

## Selected cutover strategy

The least destructive strategy is to build the frozen V2 commit inside the existing production Vercel project as a non-production deployment with V2-specific environment values, validate that immutable deployment, then promote that exact deployment to production. Do not move the production domain between unrelated Vercel projects.

Exact sequence:

1. Freeze and tag the reviewed V2 commit.
2. Reproduce all validations from a clean checkout.
3. Configure V2 Production secrets without exposing values and verify positive project identity.
4. Build an immutable candidate deployment in the existing production Vercel project without assigning the production alias.
5. Execute final V2 snapshot and reconciliation.
6. Disable the legacy scheduler and verify no run is active.
7. Enable the V2 writer and prove one successful claimed/completed run.
8. Execute smoke tests against the immutable candidate.
9. Promote the exact candidate deployment to production.
10. Execute production smoke tests and monitor freshness, ingest failures, authentication, error rate, and key counts.

## Deterministic rollback

Rollback target: deployment `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB`.

1. Stop/disable the V2 writer and wait for any claimed run to finish or expire safely.
2. Re-enable only the legacy production writer.
3. Promote the recorded previous production deployment.
4. Verify the production alias resolves to the rollback deployment.
5. Confirm login, dashboard, Flow, KPI, Planning, Capacity, DTG, UP, Aged Orders, Ready To Lift, release queue, and ingest health.
6. Preserve V2 data for diagnosis; do not reset either database.

This rollback sequence is designed but has not been rehearsed end to end. That rehearsal is a blocker.

## Smoke tests and abort triggers

Required smoke tests:

- Login, logout, session refresh, expired/disabled user, and unauthorized route.
- Dashboard, Flow, KPIs, Planning, Capacity, DTG, UP, Aged Orders, Ready To Lift, Machine Load, Performance, Labour, Release Queue, Maintenance.
- Latest-sync freshness, counts, filters, pagination where applicable, drilldowns, and empty/error states.
- One controlled Oracle read-only sync with successful claim, COMPLETE snapshot, finish, and heartbeat.
- Screen Print excluded from Release Queue and sourced from Workbank.
- No duplicate MOs, mappings, active demand, order operations, or quantity contribution.

Immediate abort/rollback triggers:

- Wrong Supabase project identity or any DEV/production cross-link.
- More than one active writer, stale/overlapping claim, or Oracle write attempt.
- Unknown reconciliation delta or material count/quantity mismatch.
- Authentication failure, unauthorized write, public data exposure, or failed RLS role test.
- Missing/stale sync beyond the approved freshness threshold.
- Deployment health failure, elevated server errors, broken core page, or non-reproducible artifact.

## Secret review

No exact service-role secret was found in repository/build output during the scan. Tracked environment examples contain names/placeholders. Public anonymous keys are not treated as private secrets. Local Oracle and ingest credentials were not printed. This check passes subject to a final secret scan of the frozen commit.

## Blocking register

| ID | Blocking condition | Required closure evidence |
| --- | --- | --- |
| B1 | V2 implementation and baseline are uncommitted; Preview is not reproducible from HEAD | Reviewed commit/tag and clean-checkout PASS |
| B2 | Clean HEAD build did not complete and is not representative of the Preview | Frozen-commit lint, typecheck, tests, build PASS |
| B3 | V2 Production-scoped Vercel variables are absent; `ORGANIZATION_ID` is absent | Name/scope audit and candidate deployment identity proof |
| B4 | Only a disabled temporary V2 user exists; production authentication is not prepared | Approved users and full auth lifecycle PASS |
| B5 | RLS policies permit broad authenticated/public access; role matrix is incomplete | Least-privilege RLS regression PASS for all roles |
| B6 | V2 has no sync agent/heartbeat; active scheduler targets legacy production from an external local path | Versioned V2 agent and tested single-writer switch |
| B7 | Final COMPLETE snapshot and C5.7 delta reconciliation have not run | Zero unknown deltas and approved final baseline |
| B8 | Deployment rollback and writer rollback have not been rehearsed | Timed rehearsal with recorded deployment IDs and evidence |
| B9 | Failure-mode/observability tests are incomplete | Stale, partial, missing, overlapping, auth, and rollback tests PASS |

## Final gate

**C5.9 CUTOVER READINESS: BLOCKED**

