# Canonical V2 Cutover Checklist

This checklist is intentionally incomplete. Unchecked items are required before cutover. It is not authorization to execute cutover.

## Identity and protection

- [x] V2 Supabase ref identified as `saecycamkyvzzppxudzq`.
- [x] Production Supabase ref identified as `gdajktoqmajipivpdude`.
- [x] DEV and production remained untouched during C5.9.
- [x] Oracle remained read-only.
- [ ] Approved cutover window and named decision owner recorded.
- [ ] Explicit TARGET identity guard passes before every write-capable command.

## Source control and build

- [ ] All intended V2 files committed on `canonical-v2`.
- [ ] `001_canonical_baseline.sql` committed and reviewed.
- [ ] Working tree clean.
- [ ] Release commit hash and immutable tag recorded.
- [ ] Fresh checkout install passes.
- [ ] Lint passes from the release commit.
- [ ] Typecheck passes from the release commit.
- [ ] Application and SQL tests pass from the release commit.
- [ ] Production build passes from the release commit.
- [ ] Built artifact matches the approved candidate deployment.

## V2 database

- [x] V2 baseline migration `001 canonical_baseline` is recorded remotely.
- [x] All 91 public base tables report RLS enabled.
- [x] `maintenance-private` is private.
- [ ] Baseline recreated successfully on a disposable verification target from the committed migration.
- [ ] Tables, views, functions, constraints, indexes, triggers, and grants match the frozen contract.
- [ ] No duplicate MO, mapping, active demand, MO line, or operation identities.
- [ ] Header quantities equal canonical active quantity.
- [ ] Inactive demand contributes zero.
- [ ] Migration and schema checksums captured.

## RLS and authentication

- [ ] Anonymous access matrix passes.
- [ ] Operator read/write matrix passes.
- [ ] Supervisor read/write matrix passes.
- [ ] Manager read/write matrix passes.
- [ ] Admin read/write matrix passes.
- [ ] Service-role matrix passes.
- [ ] Broad `public` policies reviewed and restricted.
- [ ] Broad `authenticated` manage policies reviewed and restricted.
- [ ] Approved production users provisioned.
- [ ] Login passes.
- [ ] Logout passes.
- [ ] Session refresh passes.
- [ ] Expired/disabled user handling passes.
- [ ] Unauthorized route protection passes.

## Vercel and secrets

- [x] Existing production deployment recorded as `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB`.
- [x] V2 Preview deployment recorded as `dpl_13mTxAW5QEFP2CEpu7zWXEqWpMan`.
- [x] Exact V2 service-role value was not found in repository/build scan.
- [ ] `NEXT_PUBLIC_SUPABASE_URL` configured for V2 Production scope.
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` configured for V2 Production scope.
- [ ] `SUPABASE_SERVICE_ROLE_KEY` configured for V2 Production scope.
- [ ] `INGEST_SECRET` configured for V2 Production scope.
- [ ] `ORGANIZATION_ID` configured and positively validated.
- [ ] `ADMIN_EMAIL` replaced with approved production identity configuration.
- [ ] `APP_ENV` and `TSD_ENVIRONMENT` production guards configured.
- [ ] Final secret scan passes on the frozen commit and build output.
- [ ] Immutable candidate built in the existing production Vercel project without production alias.

## Sync and final data snapshot

- [x] Legacy production agent `factory-1` observed online.
- [x] V2 currently has no agent heartbeat.
- [x] Claim function includes advisory locking and active-run prevention.
- [ ] V2 agent configuration is versioned and reviewed.
- [ ] Oracle endpoint and credential loading use approved secret storage, not hardcoded release files.
- [ ] Single-writer switch runbook rehearsed.
- [ ] Legacy scheduler prevented from starting a new run.
- [ ] Any running legacy sync completed safely.
- [ ] Pre-cutover production/V2 batch IDs, timestamps, counts, and checksums recorded.
- [ ] Exactly one final COMPLETE snapshot ingested into V2.
- [ ] Final V2 claim completed with zero active claims.
- [ ] C5.7 three-run stability remains valid.
- [ ] All final deltas classified.
- [ ] Unknown/unexplained deltas equal zero.
- [ ] Screen Print Release Queue rows and quantity equal zero.
- [ ] Screen Print current load reconciles to Workbank without double counting.

## Failure modes and observability

- [ ] Stale data alert tested.
- [ ] Missing source dataset tested.
- [ ] Partial snapshot rejection tested.
- [ ] Overlapping run prevention tested.
- [ ] Failed run retry/heartbeat degradation tested.
- [ ] Last Sync visible and correct.
- [ ] Production error and ingest monitoring owner identified.
- [ ] Approved freshness threshold and rollback threshold recorded.

## Candidate smoke tests

- [ ] Dashboard.
- [ ] Flow.
- [ ] KPIs.
- [ ] Planning.
- [ ] Capacity.
- [ ] DTG Workbank.
- [ ] UP Workbank.
- [ ] Aged Orders.
- [ ] Ready To Lift.
- [ ] Machine Load.
- [ ] Operational Performance.
- [ ] Labour.
- [ ] Release Queue.
- [ ] Maintenance.
- [ ] Filters, search, sorting, drilldowns, links, and empty/error states.

## Cutover execution

- [ ] Freeze and record release commit/tag.
- [ ] Confirm candidate deployment ID and V2 project identity.
- [ ] Complete final snapshot and reconciliation.
- [ ] Disable legacy writer and confirm no active run.
- [ ] Enable V2 writer and prove one successful run.
- [ ] Promote the exact candidate deployment.
- [ ] Verify production alias and TLS.
- [ ] Run production smoke tests.
- [ ] Confirm sync freshness and key counts.
- [ ] Record cutover timestamp and evidence.

## Rollback readiness

- [ ] Promotion back to `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB` rehearsed.
- [ ] V2 writer stop procedure rehearsed.
- [ ] Legacy writer re-enable procedure rehearsed.
- [ ] Rollback smoke tests rehearsed.
- [ ] Rollback preserves V2 data for diagnosis.
- [ ] Named rollback decision owner and time limit recorded.

## Gate

- [ ] All blockers in `CANONICAL_V2_C5_9_CUTOVER_READINESS.md` closed.
- [ ] Formal approval to cut over recorded.

Current result: **C5.9 CUTOVER READINESS: BLOCKED**

## C5.10 evidence update

- [x] Canonical V2 source frozen in commit `0ff57cd`.
- [x] `001_canonical_baseline.sql` version controlled.
- [x] Target guard committed in `880812f7e2fcbf10898d1d1133938f66e526866c`.
- [x] Sync refuses a mismatched Supabase project before heartbeat or claim.
- [x] Lint PASS after target guard.
- [x] Typecheck PASS after target guard.
- [x] Application tests 197/197 PASS after target guard.
- [x] Production build PASS after target guard.
- [ ] V2 Production environment complete.
- [ ] Approved operational users provisioned.
- [ ] Permission matrix approved and encoded.
- [ ] Least-privilege RLS regression PASS.
- [ ] Real V2 heartbeat proven.
- [ ] Single-writer transition rehearsed.
- [ ] Rollback rehearsed.
- [ ] Final snapshot reconciled.
- [ ] Three production-intended V2 runs PASS.

Current result: **C5.10 CUTOVER REMEDIATION: BLOCKED**

## C5.11 evidence update

- [x] Existing organization membership architecture reused.
- [x] Canonical role capability matrix documented with no ambiguous cells.
- [x] V2 user inventory captured without exposing credentials.
- [x] C5.8 temporary user remains banned and membership inactive.
- [x] Incremental access-control migration prepared.
- [x] Imported source and canonical history classified service-only for writes.
- [x] Local lint PASS.
- [x] Local typecheck PASS.
- [x] Local tests 197/197 PASS.
- [x] Local production build PASS.
- [ ] V2 Production variables complete.
- [x] Real production users defined and assigned.
- [x] Access-control migration applied to V2.
- [x] SQL/RLS security tests PASS remotely.
- [x] Anonymous and disabled-user tests PASS.
- [x] Operator, Supervisor, Manager, and Admin tests PASS.
- [x] Direct API bypass tests PASS.
- [x] Preview security regression P0=0 and P1=0.

Current result: **C5.11 PRODUCTION CONFIG + ACCESS CONTROL: BLOCKED**

## C5.11.1 evidence update

- [x] Canonical V2 target positively verified as `saecycamkyvzzppxudzq` before remote writes.
- [x] Pre-migration remote security snapshot captured.
- [x] Migration `002 access_control_hardening` applied and recorded remotely.
- [x] Remote structural access-control SQL test PASS with zero failures.
- [x] Remote public/anon policies equal zero.
- [x] Remote anonymous public-schema grants equal zero.
- [x] Disabled C5.8 temporary identity remained banned and inactive.
- [x] Legacy PROD, DEV, Oracle, production domain, and schedulers remained unchanged.
- [x] Approved master V2 identities provisioned; sequential OPERATOR, SUPERVISOR, MANAGER, and ADMIN capability checks PASS.
- [x] Direct identity-based RLS/API matrix PASS.
- [ ] V2 Production environment variables complete.
- [x] Approved production admin identities replace disabled temporary `ADMIN_EMAIL`.
- [x] Preview redeployed and functional/security regression P0=0 and P1=0.

Current result: **C5.11.1 REMOTE SECURITY ACTIVATION: PASS**

## C5.11.2B evidence update

- [x] Preview tested at commit `5e2bb18c7c87f4a23a6a1615750a0aa0db16f45a`.
- [x] Both approved master identities authenticate and receive ADMIN access.
- [x] Required Production, Flow, Maintenance, Capacity, Source Data, and Release Queue pages load successfully.
- [x] Screen Print remains excluded from Release Queue (`PAK7` rows = 0).
- [x] Service-only direct writes remain denied with HTTP 403.
- [x] Browser/runtime P0 = 0 and P1 = 0.
- [x] Automated regression: lint PASS, typecheck PASS, tests 198/198 PASS, build PASS.
- [ ] Rotate temporary master-user credentials before cutover.
- [ ] Review four non-blocking P2 navigation gaps documented in `CANONICAL_V2_C5_11_2B_PREVIEW_BROWSER_REGRESSION.md`.

Current result: **C5.11.2B PREVIEW BROWSER FUNCTIONAL REGRESSION: PASS**
