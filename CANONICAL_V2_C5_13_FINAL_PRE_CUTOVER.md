# Canonical V2 C5.13 Final Pre-Cutover Validation

## Result

**C5.13 FINAL PRE-CUTOVER VALIDATION: PASS**

This document is evidence of readiness only. No cutover, production-domain switch or autonomous V2 scheduler activation was performed.

## Frozen candidate

- Branch: `canonical-v2-security`
- Implementation SHA: `33571deab25f0333b9b8e6cc42a0fff0f063d14b`
- Change after C5.12: the production agent launcher now loads an explicit ignored environment file and requires the ingest endpoint, ingest secret, expected Supabase project ref, agent ID and connector version. It no longer hardcodes the legacy ingest URL.
- Separate Maintenance UX V2 worktree: untouched.

## Environment verification

| Control | Result |
| --- | --- |
| V2 Supabase | `saecycamkyvzzppxudzq` |
| DEV Supabase | Untouched |
| Legacy production Supabase | Untouched |
| Oracle | READ-ONLY / untouched |
| Legacy production domain | Unchanged and HTTP 200 |
| Legacy writer | ON / enabled / healthy |
| V2 scheduler | OFF |
| V2 agent target guard | PASS |
| V2 heartbeat during all runs | PASS |
| V2 locking and release | PASS |

The V2 Vercel Production scope has six required variables: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INGEST_SECRET`, `APP_ENV`, and `TSD_ENVIRONMENT`. Configured = 6, missing = 0, invalid = 0. C5.13 detected and removed literal line-ending suffixes from two secret variables before the final deployment. Secret values are not recorded here.

## Migration verification

| Migration | Repository | V2 remote |
| --- | --- | --- |
| `001_canonical_baseline.sql` | Present | Applied |
| `002_access_control_hardening.sql` | Present | Applied |

Missing migrations = 0. Unexpected migrations = 0. Partial migrations = 0.

## C5_13 baseline

- Captured: `2026-09-19 14:27:39.312133+00`
- Latest COMPLETE batch: `910a1984-fda8-4499-a227-dcf9eb5df19e`
- Oracle source timestamp: `2026-09-19 04:32:55+00`
- Workbank snapshot timestamp: `2026-09-19 13:48:45.677258+00`
- Orders: 1,174
- Workbank: 8,031 rows / 12,777 units
- Release lines: 25,121
- Audit events: 76,399
- DTG history: 826
- Production events: 49,199
- Capacity: 3
- Maintenance: 4 WOs, 6 history, 4 comments, 3 downtime records, 31 assets
- Screen Print Release Queue: 0 rows / 0 units
- Duplicate, orphan, invalid-status, unknown-event and active-run checks: all zero

## Three consecutive runs

All runs used agent `tsd-v2-production-FELIPE-LT`, connector `0.2.0+33571de`, the same code, configuration, Oracle read-only path, V2 endpoint and target guard.

| Run | Run ID | COMPLETE batch | Duration | Orders | Workbank | Result |
| --- | --- | --- | ---: | ---: | ---: | --- |
| 1 | `38570973-afc4-47ec-a7b1-7fae29683936` | `bddcbce3-13eb-439c-8f1b-dba548b58413` | 51,167 ms | 1,174 | 8,031 | PASS |
| 2 | `948b2661-4f52-494d-9da5-a651c95e7a08` | `fc263765-68d5-4b82-8216-6f8ed2769da6` | 45,774 ms | 1,174 | 8,031 | PASS |
| 3 | `ed05a4c2-4365-4703-bcdb-eadafecb07c0` | `e199747f-4ea9-41bf-b57c-95c4a83ddf05` | 47,127 ms | 1,174 | 8,031 | PASS |

| Metric | Baseline | Run 1 | Run 2 | Run 3 | Classification |
| --- | ---: | ---: | ---: | ---: | --- |
| Orders | 1,174 | 1,174 | 1,174 | 1,174 | NO_CHANGE |
| Workbank rows | 8,031 | 8,031 | 8,031 | 8,031 | NO_CHANGE |
| Workbank qty | 12,777 | 12,777 | 12,777 | 12,777 | NO_CHANGE |
| Release lines | 25,121 | 25,191 | 25,191 | 25,191 | EXPECTED_SOURCE_DELTA |
| Audit Events | 76,399 | 76,399 | 76,399 | 76,399 | NO_CHANGE |
| DTG History | 826 | 826 | 826 | 826 | NO_CHANGE |
| Production Events | 49,199 | 49,199 | 49,199 | 49,199 | NO_CHANGE |
| Capacity | 3 | 3 | 3 | 3 | NO_CHANGE |
| Maintenance WOs | 4 | 4 | 4 | 4 | NO_CHANGE |
| Screen Print RQ | 0 | 0 | 0 | 0 | NO_CHANGE |

The 70-line release-source delta occurred on run 1 and then stabilized. No Workbank or derived-state quantity changed. `UNEXPLAINED = 0`.

## Integrity and authority regressions

- Duplicate Workbank keys, audit IDs/hashes, DTG history, production-event keys, maintenance WOs, capacity keys and active mappings: 0 after every run.
- Orphan release lines, MO operations, maintenance assets and parts: 0 after every run.
- Invalid maintenance statuses: 0.
- Unknown audit events: 0.
- Active/stale sync locks after each run: 0.
- Current operational load authority: Workbank only.
- Release Queue authority: Oracle Sales Order Lines, separate from Workbank.
- Screen Print: MAKE TO STOCK, PAK7 Workbank-only, Release Queue 0, missing-release Not Approved 0.
- DTG history remains derived and does not inflate current Workbank load.
- Production events remained stable at 49,199 with no duplicate inflation.
- Capacity remained three configuration/denominator records, never workload.
- Maintenance remained 4 WOs with child history intact and valid assets/statuses.

## Security and credential rotation

- `fsantos_cb@hotmail.com`: ACTIVE, `admin`, login PASS after final rotation.
- `felipe.s@tankstreamdesign.com`: ACTIVE, `admin`, login PASS after final rotation.
- Temporary smoke credentials: invalidated.
- Final credentials: stored in Windows Credential Manager as `TSD_V2_ADMIN_FSANTOS_CB` and `TSD_V2_ADMIN_FELIPE_TSD`; never printed or committed.
- Public/anon operational access: denied.
- Public policies and anonymous operational grants: 0 per remote hardening validation.
- Service-only writes remain denied to normal identities; agent service path remains functional.
- Runtime `ADMIN_EMAIL` bypass is absent from Production configuration.

## Automated validation

| Check | Result |
| --- | --- |
| Lint | PASS |
| Typecheck | PASS |
| Shared tests | 49/49 PASS |
| Oracle agent/sync tests | 18/18 PASS |
| Web/security tests | 133/133 PASS |
| Total tests | 200/200 PASS |
| Production build | PASS, 44 routes generated |

The first invocation produced a Windows temporary-path write error after its 44 discovered assertions had passed. Re-running with `TEMP` and `TMP` bound to a stable checkout directory completed the full 200-test suite. No code was changed for this environmental condition.

## Deployment and browser smoke

- Vercel project: `prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`
- Deployment: `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m`
- Immutable URL: `https://tsd-production-control-v2-preview-4lmswmj2o-tsd7.vercel.app`
- Stable V2 URL: `https://tsd-production-control-v2-preview.vercel.app`
- Target: Production configuration in the isolated V2 Vercel project
- Build status: Ready
- Legacy production domain: unchanged

Authenticated smoke PASS: Login, Dashboard, Orders/DTG, Planning, Machine Load, Release Queue, Scanner, Operational Performance, Production Flow, Screen Print, Maintenance, Assets and Preventive Maintenance. Two data-heavy navigations exceeded the automation's initial wait but subsequently rendered complete content without application errors. P0 = 0. P1 = 0.

## Cutover runbook

1. Confirm legacy production healthy.
2. Confirm final V2 snapshot COMPLETE.
3. Confirm candidate commit and deployment ID.
4. Confirm rollback deployment, database and writer configuration.
5. Stop the legacy writer.
6. Prove the legacy writer and active run are stopped.
7. Start exactly one V2 writer using the validated configuration.
8. Verify target guard and current heartbeat.
9. Verify the first V2 sync is COMPLETE and reconciled.
10. Switch the production application/domain to the frozen deployment.
11. Run the critical browser smoke matrix.
12. Verify freshness, counts, duplicates and orphans.
13. Verify writer overlap remains zero.
14. Record the cutover timestamp and declare completion.

## Rollback runbook

1. Stop the V2 writer and prove no active V2 run remains.
2. Restore the legacy writer.
3. Restore the legacy application/domain/deployment.
4. Verify the legacy heartbeat.
5. Verify the next legacy sync completes.
6. Verify critical production pages and freshness.

The legacy application, deployment `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB`, database `gdajktoqmajipivpdude`, writer configuration and scheduler remain available. V2 data must be retained for diagnosis after rollback.

## Abort conditions

Abort for any P0 defect, P1 operational defect, authentication failure, incorrect Supabase target, writer overlap, sync failure, incomplete snapshot, unexpected data collapse, unexplained delta, critical page failure, or Oracle/Workbank unavailability.

## Remaining controlled risks

- Actual cutover still requires an approved window and named decision owner.
- The V2 scheduler intentionally remains OFF until the controlled cutover step.
- The production domain intentionally remains on the legacy deployment.
- Four previously documented P2 navigation gaps remain non-blocking and unchanged.

## Final gate

**C5.13 FINAL PRE-CUTOVER VALIDATION: PASS**

**READY FOR CONTROLLED PRODUCTION CUTOVER**
