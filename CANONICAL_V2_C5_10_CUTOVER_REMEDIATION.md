# Canonical V2 - C5.10 Cutover Readiness Remediation

Date: 2026-09-19 (Australia/Brisbane)

## Result

**C5.10 CUTOVER REMEDIATION: BLOCKED**

No production cutover was performed. The production domain, legacy Supabase, inactive DEV, Oracle, and the active legacy scheduler were not modified.

## Git remediation

- Branch: `canonical-v2`.
- Baseline freeze commit: `0ff57cd`.
- Target-identity protection commit: `880812f7e2fcbf10898d1d1133938f66e526866c`.
- `.tmp/` and `supabase/.temp/` are excluded as local cache/CLI state.
- Canonical source, contracts, migration, tests, deterministic data, and schema evidence are version controlled.
- Secret scan found no service-role key, ingest secret, Oracle password, credential-bearing database URL, or private JWT in tracked candidate files.

## Migration remediation

`supabase/migrations/001_canonical_baseline.sql` is now version controlled. Legacy migrations remain preserved under `supabase/legacy-migrations-reference` and are not part of the executable V2 chain.

The last verified V2 remote migration inventory contained only version `001`, name `canonical_baseline`, matching the single executable repository migration. The Supabase CLI was unavailable during the final C5.10 command session, so no new remote write or repair was attempted.

## Security and RLS remediation

Security remains a blocker. The C5.9 inventory found broad `authenticated` management policies and some `public` policies on operational structures. The current application does not contain a complete authoritative Operator/Supervisor/Manager/Admin membership model that can safely be used to rewrite all RLS policies without inventing business authorization.

No RLS policy was weakened or guessed. A least-privilege migration requires an approved role source of truth and role-to-action ownership.

## Permission matrix

| Capability | Operator | Supervisor | Manager | Admin | Status |
| --- | --- | --- | --- | --- | --- |
| Read orders and production | Expected | Expected | Expected | Expected | Approval required |
| Operate production workflows | Expected | Expected | Policy decision | Expected | Approval required |
| View maintenance | Expected | Expected | Expected | Expected | Approval required |
| Create maintenance request | Expected | Expected | Expected | Expected | Approval required |
| Complete maintenance work | Policy decision | Expected | Expected | Expected | Approval required |
| Manage assets/configuration | No | Policy decision | Expected | Expected | Approval required |
| Delete/cancel records | No | Policy decision | Expected | Expected | Approval required |
| Administer users | No | No | No | Expected | Approval required |

The matrix is deliberately not encoded in RLS until the policy decisions are approved.

## Production users readiness

BLOCKED. The C5.8 temporary Preview user remains disabled. No shared or invented production account was created. Approved named users, their roles, and account lifecycle must be supplied before authentication and RLS regression can be completed.

## Vercel Production environment readiness

BLOCKED. The V2 project has Preview configuration but no complete Production scope. `ORGANIZATION_ID` is missing, and the Preview `ADMIN_EMAIL` identifies a disabled temporary account. The Vercel CLI was unavailable in the final local session; no secrets were copied or fabricated.

Required Production variables remain:

| Variable | Target | Status |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | V2 `saecycamkyvzzppxudzq` | BLOCKED |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | V2 | BLOCKED |
| `SUPABASE_SERVICE_ROLE_KEY` | V2 server only | BLOCKED |
| `INGEST_SECRET` | V2 server/agent only | BLOCKED |
| `ORGANIZATION_ID` | V2 canonical organization | BLOCKED |
| `ADMIN_EMAIL` or approved replacement | Named approved admin | BLOCKED |
| `APP_ENV` | production | BLOCKED |
| `TSD_ENVIRONMENT` | production | BLOCKED |

## Clean build

Validation after target-protection implementation:

- Lint: PASS.
- Typecheck: PASS when run after build; a parallel run failed only because `next build` recreated `.next/types` concurrently.
- Tests: 197/197 PASS. The count increased from 196 because a target-mismatch denial test was added.
- Production build: PASS, 44 static/dynamic routes generated.

## Legacy sync architecture

- Active task: `TSD Production Control Sync`.
- State observed: Running/Ready under the existing Windows account.
- Script: `C:\TSD Production Control Full\apps\oracle-sync\scripts\agent-tick.ps1`.
- Frequency: one-minute task trigger; application interval control is five minutes.
- Target: legacy production ingest URL.
- Oracle credential target: Windows credential manager entry `TSDPROD_KPI_ORACLE`.
- Last observed task result: `0`.
- Legacy fallback task: `TSD Production Control - Oracle Sync`, disabled.

The legacy writer was not stopped.

## V2 sync architecture and target protection

The V2 agent code is prepared but remains unscheduled and OFF. It now requires `EXPECTED_SUPABASE_PROJECT_REF`. Before heartbeat or claim, it calls the authenticated organization endpoint and compares both organization ID and server-derived Supabase project ref.

Proven outcomes:

- Matching V2 identity permits heartbeat/claim flow.
- A legacy project ref is refused before heartbeat or claim.
- The endpoint derives the project ref from server-only Supabase configuration.

The intended V2 value is `saecycamkyvzzppxudzq`.

## Heartbeat

Code path and database structure exist, but no real V2 heartbeat was produced because Production V2 secrets/configuration are incomplete and enabling an autonomous second writer is prohibited. Status: BLOCKED.

## Locking

Existing database claim logic uses advisory locking, active-run refusal, and a stale-run lease. Unit tests cover idle claim behavior and target refusal. Live overlap, failure, and timeout release tests remain BLOCKED until a safe manual V2 configuration exists.

## Single-writer rehearsal

Not executed. The critical invariant was preserved: the legacy writer continued and the V2 writer remained OFF. A rehearsal requires a controlled window and complete V2 configuration; stopping legacy production during ordinary operation was expressly prohibited.

## Rollback rehearsal

Not executed. Evidence still confirms the legacy deployment, database, scheduler configuration, and active sync exist. The application rollback deployment remains `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB`, but promotion and writer rollback must be rehearsed in an approved window.

## Failure handling

Static logic supports failed-run recording, degraded heartbeat, retry, active-run refusal, and preservation of the previous COMPLETE snapshot. Live source-unavailable, database-unavailable, lock-conflict, and timeout exercises were not run against V2 because the V2 agent is intentionally OFF.

## Final sync and three-run result

Not executed. These phases are gated by Production env completion, approved users/RLS, V2 manual agent proof, overlap proof, single-writer rehearsal, and rollback rehearsal. The last known V2 snapshot remains behind the active production writer; it is not accepted as a final pre-cutover snapshot.

## Blocker matrix

| C5.9 Blocker | Resolution | Evidence | Status |
| --- | --- | --- | --- |
| Reproducible commit | Canonical source frozen | `0ff57cd`, then target guard `880812f` | PASS |
| Baseline migration | Authoritative `001` version controlled | `supabase/migrations/001_canonical_baseline.sql` | PASS |
| Production env vars | Values/scopes incomplete | V2 Production matrix has missing required variables | BLOCKED |
| Operational users | Temporary user disabled; no generic user created | Named approved users not supplied | BLOCKED |
| Permission matrix | Drafted, policy decisions identified | Role source of truth not approved | BLOCKED |
| RLS | Unsafe broad policies identified, not guessed over | Role regression cannot yet pass | BLOCKED |
| V2 sync agent | Code path prepared and remains OFF | Exact project-ref guard and denial test | BLOCKED |
| Heartbeat | Real heartbeat requires safe V2 config/manual run | No V2 agent heartbeat | BLOCKED |
| Single writer | Invariant preserved; rehearsal not run | Legacy active, V2 OFF | BLOCKED |
| Rollback | Assets exist; rehearsal not run | Deployment/database/scheduler retained | BLOCKED |
| Final snapshot | Correctly deferred | Prerequisites incomplete | BLOCKED |
| Clean build | Fresh validation completed | lint, typecheck, 197 tests, build PASS | PASS |

## Remaining blockers

1. Complete V2 Production-scoped variables without exposing secrets.
2. Provide approved named operational users and authoritative roles.
3. Approve the permission matrix and implement/test least-privilege RLS.
4. Manually validate the V2 agent with target guard and real heartbeat while remaining non-autonomous.
5. Prove overlap/lock release behavior.
6. Rehearse single-writer transition in an approved service window.
7. Rehearse application and writer rollback.
8. Exercise failure scenarios.
9. Run final COMPLETE snapshot and reconciliation.
10. Run three consecutive production-intended V2 syncs with zero unexplained deltas.

## Final gate

**C5.10 CUTOVER REMEDIATION: BLOCKED**

