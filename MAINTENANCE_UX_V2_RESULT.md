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

## Defects and gate

- P0: 0 confirmed implementation defects.
- P1: 0 confirmed implementation defects.
- Blocker: no isolated Preview database target.
- P2/P3: not fully assessable until browser regression can run against the migrated isolated target.

**MAINTENANCE UX V2: BLOCKED**

Exact blocker: Vercel Preview is configured against the Canonical V2 production Supabase project, so safe migration, RLS and lifecycle fixture validation cannot be performed without violating the no-production-first rule.
