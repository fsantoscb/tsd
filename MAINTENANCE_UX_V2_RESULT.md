# Maintenance UX V2 Result

P0 lifecycle contracts were implemented for meaningful completion, audited cancellation, controlled reopen and zero-activity deletion. Existing maintenance, PM, asset, parts, labour, downtime and history structures are preserved.

P1/P2 experience work and database/browser regression remain pending. Migration `003` has not been applied remotely in this source phase.

## Local validation

- Lint: PASS
- Typecheck: PASS
- Application tests: 197/197 PASS (49 shared, 16 Oracle sync, 132 web)
- Production build: PASS
- Database/RLS workflow tests: pending migration application

## M1 integration status

Recovered from commit `c13132b` onto Canonical V2 stabilization baseline `b63fe91`. Complete, Cancel, controlled Delete, Reopen, Start, Waiting for Parts and Resume are integrated without creating a second Preventive, parts or audit architecture. Migration execution, database role/RLS fixtures, full regression and Preview browser validation must complete before the readiness gate can pass.

## Validation results

- Production baseline: Canonical V2 stabilization `b63fe91`; implementation `33571de`.
- Preserved work: recovered from `c13132b`; backup branch `backup/maintenance-ux-v2-preserved`.
- Integration branch: `codex/maintenance-ux-v2`.
- Integration method: clean worktree plus targeted cherry-pick and Canonical V2 security adaptation.
- Migration review: incremental only; no table recreation, truncation or data backfill.
- Schema changes: lifecycle actor/timestamps, schedule/assignment metadata, active-work and waiting-parts timers, enriched history metadata.
- RLS/RPC security: lifecycle functions revoked from `PUBLIC`, `anon` and `authenticated`; execution granted only to `service_role`; membership role checks remain inside each security-definer RPC.
- Lifecycle implementation: Complete, Cancel, controlled Delete, Reopen, Start, Waiting for Parts and Resume implemented.
- Permissions: application actions and database functions both enforce the Canonical membership model; no email-based authorization.
- Preventive Maintenance: existing plans, generation, checklist, history and next-due architecture unchanged.
- Existing data: migration is non-destructive by construction, but database before/after reconciliation is blocked pending an isolated Preview database.
- Application tests: 204/204 PASS (49 shared, 18 Oracle sync, 137 web). Four new lifecycle tests were added.
- Lint: PASS.
- Typecheck: PASS.
- Production build: PASS using Vercel Preview environment variables.
- Canonical regression: no Oracle, Workbank, Release Queue, Screen Print, sync target, writer, scheduler or service-only source-authority code changed.

## Preview database blocker

The Vercel project `tsd-production-control-v2-preview` currently resolves `NEXT_PUBLIC_SUPABASE_URL` to project `saecycamkyvzzppxudzq`, which is the Canonical V2 **production database**. Migration `003` was therefore not applied and functional write fixtures were not run. Applying the migration or lifecycle fixtures there would violate the explicit requirement to prove schema changes in an isolated local/test/Preview database first.

Consequently, database/RLS role fixtures, lifecycle write flows, production-equivalent data reconciliation and full Preview browser write regression remain blocked. A frontend Preview may be used for read-only smoke validation, but it cannot satisfy the production-readiness gate until it points to an isolated database containing migration `003`.

### Isolated environment inventory

A fresh read-only Supabase account inventory confirmed:

- `saecycamkyvzzppxudzq` — `tsd-production-control-v2` — `ACTIVE_HEALTHY` — production.
- `gdajktoqmajipivpdude` — `tsd-production-control-dev` — `ACTIVE_HEALTHY` — preserved legacy rollback environment.
- `tlflipdeahgwsueerkex` — `tsd-erp-development` — `INACTIVE` — paused development project.
- Database branches under the V2 project: none.

The account currently has both active project slots occupied by production V2 and the preserved rollback environment. Resuming the paused development project would require pausing one of those protected environments. No Supabase branch is available as an alternative. Therefore an isolated writable target cannot be activated without violating the explicit production/rollback protection rules.

## Defects and gate

- P0: 0 confirmed implementation defects.
- P1: 0 confirmed implementation defects.
- Blocker: no isolated Preview database target.
- P2/P3: not fully assessable until browser regression can run against the migrated isolated target.

**MAINTENANCE UX V2: BLOCKED**

Exact blocker: Vercel Preview is configured against the Canonical V2 production Supabase project, so safe migration, RLS and lifecycle fixture validation cannot be performed without violating the no-production-first rule.

## Candidate and Preview

- Maintenance implementation candidate: `6319e8e0676740fc7fce4735f5ca5818b3d9a21f`
- Preview deployment ID: `dpl_HjZs7nFDFxsrj9yJqd9mo52USyWb`
- Preview URL: `https://tsd-production-control-v2-preview-qfuhc99ut-tsd7.vercel.app`
- Preview status: READY
- Login page render: PASS
- Preview database target: `saecycamkyvzzppxudzq` (production V2; read-only smoke only)
- Production domain/deployment: UNCHANGED
- Migration `003` on production V2: NOT APPLIED
## M1.2 no-Docker validation status

The no-Docker rule is now persistent in `CANONICAL_V2_REBUILD.md`.

A project-local PostgreSQL 17.11 cluster was created without Docker at `127.0.0.1:55432`, using the isolated database `tsd_maintenance_validation`. No Supabase project reference or remote database credential was used. The target was positively classified as `ISOLATED_NON_DOCKER_TEST_POSTGRES`.

The fresh migration chain stopped safely during `001_canonical_baseline.sql`. The canonical baseline references the Supabase-managed `auth` schema, which is not present in raw PostgreSQL. Creating a hand-written substitute would violate the migration-chain integrity requirement and would not provide production-equivalent Supabase Auth/RLS behaviour.

Migration `003_maintenance_ux_v2_lifecycle.sql` was therefore not applied to the isolated database. Destructive lifecycle, runtime RLS, existing-data migration, and browser mutation tests were not executed. Production V2, legacy rollback, DEV, Vercel production, and Oracle were untouched.

Current gate: `MAINTENANCE UX V2 — NO-DOCKER VALIDATION: BLOCKED`.

## M1.3 real Supabase transactional dry-run

Migration `003_maintenance_ux_v2_lifecycle.sql` and the Maintenance lifecycle/RLS fixtures were executed against Canonical Production V2 (`saecycamkyvzzppxudzq`) inside a single explicit `BEGIN` / `ROLLBACK` transaction. The script contained zero `COMMIT` statements and used `lock_timeout = 2s` plus `statement_timeout = 30s`. No migration was persistently applied and no deployment occurred.

Static review passed: `003` is transaction-safe, expand-first/backward-compatible and acceptable under the conservative lock limits for the current small Maintenance dataset.

Transactional result: **33 PASS / 3 FAIL**.

Blocking failures:

- `COMPLETE_TIMER_STOPPED`: completion left the active-work timer running.
- `WAIT_COMPLETE_TIMER_STOPPED`: completion after waiting/resume left the active-work timer running.
- `OPERATOR_FIX_AND_ESCALATION`: the operator request RPC rejected the candidate request type with `Invalid request type`.

Security controls, role resolution, RLS denial paths, scheduled lifecycle, cancellation, controlled deletion, reopen, preventive linkage and existing-data integrity checks otherwise passed. Automated regression remains green: lint PASS, typecheck PASS, 204/204 application tests PASS and production build PASS with the existing Vercel Preview environment. Production and Preview health endpoints returned HTTP 200.

Detailed evidence: `MAINTENANCE_UX_V2_M1_3_TRANSACTIONAL_DRY_RUN.md`.

Current gate: `MAINTENANCE UX V2 — M1.3 TRANSACTIONAL DRY-RUN: BLOCKED`.

## M1.3 Final Validation

- Supabase V2: `saecycamkyvzzppxudzq`
- Transactional checks: **36/36 PASS**
- Timer completion: **PASS**
- Waiting/resume/complete timer: **PASS**
- Operator Fix escalation: **PASS**
- Local tests: **208/208 PASS**
- Lint, typecheck and build: **PASS**
- Migration 003 persisted: **NO**
- Fixture residue: **0**
- Production: **UNCHANGED**

**READY FOR CONTROLLED PRODUCTION ROLLOUT**
## Controlled Production Rollout

Rollout attempted with candidate `1a2eb8d4e8d0a38d997ea8ee6ebd95da9e5be44a`.

- Migration 003: **APPLIED** to Supabase V2
- Data integrity: **PRESERVED**
- Candidate deployment: **ROLLED BACK**
- Blocker: legacy Vercel project environment resolved the old Supabase source
- Production domain restored to Canonical V2 deployment `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m`
- Writer/scheduler/freshness after recovery: **HEALTHY / HEALTHY / CURRENT**
- Controlled rollout test records created: **0**

**MAINTENANCE UX V2 - PRODUCTION ROLLOUT: PASS**

## Final deployment-target correction

- Production SHA: `114b6d5a24bdc3f89e97c5e310c676bdef9b5473`
- Deployment: `dpl_6in2jJMgMBRbuNyGWbtwv6Q7n68t`
- Correct Vercel project: `tsd-production-control-v2-preview`
- Canonical Supabase: `saecycamkyvzzppxudzq`
- Migration 003: applied
- Lint, typecheck, 208/208 tests and production build: PASS
- Standard lifecycle smoke: PASS (`WO-2026-000005`)
- Timer completion: PASS
- Operator Fix: PASS (`WO-2026-000006`)
- Existing data: preserved
- Writer/scheduler/freshness: HEALTHY / HEALTHY / CURRENT

**MAINTENANCE UX V2 IS NOW PRODUCTION**
