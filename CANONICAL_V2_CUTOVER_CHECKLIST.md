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
