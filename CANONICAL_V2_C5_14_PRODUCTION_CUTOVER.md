# Canonical V2 C5.14 Controlled Production Cutover

## Result

**C5.14 CONTROLLED PRODUCTION CUTOVER: PASS**

**CANONICAL V2 IS NOW PRODUCTION**

## Production identity

| Item | Production value |
| --- | --- |
| Application implementation | `33571deab25f0333b9b8e6cc42a0fff0f063d14b` |
| C5.13 evidence | `560054267aa49d54c5d61362d12636574c08e791` |
| Vercel deployment | `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m` |
| Immutable Vercel URL | `https://tsd-production-control-v2-preview-4lmswmj2o-tsd7.vercel.app` |
| Production domain | `https://tsd-production-control.vercel.app` |
| Supabase project | `saecycamkyvzzppxudzq` |
| V2 agent | `tsd-v2-production-FELIPE-LT` |
| Connector | `0.2.0+33571de` |
| Oracle | READ-ONLY |

No application code was changed during cutover. DEV, legacy Supabase and Oracle were not modified.

## Cutover event log

| Time, Australia/Brisbane | Action | Result |
| --- | --- | --- |
| 2026-09-20 01:09:12 | Cutover started | PASS |
| 2026-09-20 01:09:15 | Legacy writer disabled | PASS |
| 2026-09-20 01:09:15 | Zero-writer transition state | PASS |
| 2026-09-20 01:09:58 | V2 writer and scheduler enabled | PASS |
| 2026-09-20 01:11:26 | First V2 production sync completed | PASS |
| 2026-09-20 01:12:34 | Production domain assigned to V2 deployment | PASS |
| 2026-09-20 01:24:37 | Autonomous scheduled V2 sync completed | PASS |
| 2026-09-20 01:25:57 | Production smoke and cutover completed | PASS |

Writer overlap duration was zero seconds. The forbidden state `legacy ON / V2 ON` was not observed.

## Legacy health and rollback target

Immediately before cutover:

- Legacy application health endpoint: HTTP 200.
- Legacy writer task: enabled, ready, last result 0.
- Legacy last successful sync: batch `9b197c23-babe-42ca-ba8d-29957d01fcad` at approximately 01:07 AEST.
- Legacy Vercel deployment: `dpl_4rox7t3m7Q4aLbzuS5yKj1gZvNzB`.
- Legacy immutable URL: `https://tsd-production-control-4i4vku22j-tsd7.vercel.app`.
- Legacy Supabase: `gdajktoqmajipivpdude`.
- Legacy writer task: `TSD Production Control Sync`.
- Legacy writer launcher: `C:\TSD Production Control Full\apps\oracle-sync\scripts\agent-tick.ps1`.

The deployment, database, scripts, environment variables, logs and disabled scheduler remain available. Nothing was deleted or overwritten.

## Final pre-switch V2 sync

- Run: `cd35db47-b1e7-41f0-aa3e-7670f5bedfc3`
- Batch: `e7b38b9b-a2b8-4684-afb9-e6e217f7a5cc`
- Trigger: MANUAL
- Result: SUCCESS / COMPLETE
- Orders: 1,174
- Workbank: 8,031 rows / 12,777 units
- Release lines: 25,191
- Audit events: 76,399
- DTG history: 826
- Production events: 49,199
- Capacity: 3
- Maintenance WOs: 4
- Screen Print Release Queue: 0 rows / 0 units
- Duplicates, orphans, invalid statuses, unknown events and active locks: all zero

The Oracle source business timestamp remained unchanged because the source rows did not change. The connector read completed successfully and the new Workbank snapshot timestamp was current. This is stable source content, not stale ingestion.

## Writer transition and first production sync

The legacy scheduler was disabled through `schtasks /Change`; no legacy writer process remained. The V2 scheduled task was created from the already rehearsed task definition with the validated launcher, one-minute polling and internal five-minute automatic sync cadence.

- First production V2 run: `92268865-df02-47c9-baf4-22f36597fdfe`
- Batch: `e88dc524-77c1-4d7c-84c9-916a018e782e`
- Started: 2026-09-20 01:10:11 AEST
- Completed: 2026-09-20 01:11:26 AEST
- Duration: 73,090 ms
- Trigger: MANUAL
- Result: SUCCESS / COMPLETE
- Orders / Workbank / Stock / Audit inserted: 1,174 / 8,031 / 60 / 0
- Target guard: `saecycamkyvzzppxudzq`
- Heartbeat: online, no error, no current run after completion

Post-run reconciliation returned zero duplicates, zero unexpected orphans, zero unexplained deltas, zero invalid statuses and zero active/stale runs.

## Domain switch

At 01:12:34 AEST the alias `tsd-production-control.vercel.app` was assigned to deployment `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m`. The health endpoint returned HTTP 200 and Vercel resolved the public domain to the frozen V2 deployment.

The application Production environment contains the validated V2 URL, anon key, service-role key, ingest secret and production environment guards. No legacy Supabase target remains in the V2 Production scope.

## Authentication and security

- `fsantos_cb@hotmail.com`: login PASS, membership ACTIVE, role admin.
- `felipe.s@tankstreamdesign.com`: login PASS, membership ACTIVE, role admin.
- Both accounts were validated using their final rotated credentials.
- Browser authentication on the production domain: PASS.
- Normal ADMIN direct writes to service-only source tables: DENIED for both identities.
- Public/anon operational access remains denied.
- No runtime `ADMIN_EMAIL` bypass was introduced.
- Credentials were not printed, committed or added to reports.

## Production browser smoke

| Page | Result |
| --- | --- |
| Dashboard | PASS |
| Orders / DTG | PASS |
| Planning | PASS |
| Machine Load | PASS |
| Release Queue | PASS |
| Scanner | PASS |
| Operational Performance | PASS |
| Production Flow | PASS |
| Screen Print | PASS |
| Maintenance | PASS |
| Assets | PASS |
| Preventive Maintenance | PASS |

Data-heavy pages occasionally exceeded the initial browser automation wait but completed normally on the same request. No 5xx, authorization failure, infinite loading or application error remained. P0 = 0 and P1 = 0.

## Business assertions

- Current operational load is sourced from Workbank.
- Release Queue authority is Oracle Sales Order Lines and is not added to Workbank.
- Screen Print remains MAKE TO STOCK and PAK7 Workbank-only.
- Screen Print Release Queue remains 0 rows / 0 units.
- Missing Oracle release does not classify Screen Print as Not Approved.
- DTG history does not contribute to current workload.
- Capacity remains configuration/denominator, not workload.
- Maintenance retains 4 WOs, 6 history rows, 4 comments, 3 downtime records and valid asset/status relations.

## Autonomous scheduler proof

The normal V2 scheduler produced successful automatic runs after activation:

| Run | Batch | Completed | Result |
| --- | --- | --- | --- |
| `603e9f4b-4e31-4a93-a152-8273e5d934e8` | `cec9b09a-4e38-4857-92e4-58826b961482` | 01:13:45 AEST | SUCCESS / COMPLETE |
| `3b307410-7bb9-497e-abb2-8b368cff9db7` | `ccb2f1c4-914d-49bf-9a09-aeb4dec6be3e` | 01:18:44 AEST | SUCCESS / COMPLETE |
| `d322b3e9-1eb2-4414-b832-1f7a6dc41d3d` | `d154a948-4ea1-450d-8a05-d419cd9ed102` | 01:24:37 AEST | SUCCESS / COMPLETE |

Final Source Health displayed:

- Status: CURRENT.
- Agent: ONLINE.
- Last heartbeat: 2026-09-20 01:24:38 AEST.
- Last successful sync: 2026-09-20 01:24:16 AEST.
- Last attempt: SUCCESS / AUTOMATIC.
- Next expected sync: 2026-09-20 01:29:38 AEST.
- Latest batch: `d154a948-4ea1-450d-8a05-d419cd9ed102`.

## Production V2 baseline

| Metric | Final value |
| --- | ---: |
| Orders | 1,174 |
| Workbank rows | 8,031 |
| Workbank units | 12,777 |
| Release lines | 25,191 |
| Audit events | 76,399 |
| DTG history | 826 |
| Production events | 49,199 |
| Capacity | 3 |
| Maintenance WOs | 4 |
| Maintenance history | 6 |
| Maintenance comments | 4 |
| Maintenance downtime | 3 |
| Screen Print Release Queue | 0 |

Final duplicate and unexpected-orphan checks are zero. Final active sync runs are zero.

## Final writer state

- Legacy writer: OFF, disabled, retained.
- V2 writer: ON.
- V2 scheduler: ON, enabled, last task result 0.
- Writer overlap: 0 seconds.
- Production domain: V2.
- Legacy rollback environment: retained.

## Rollback procedure retained

1. Disable `TSD Production Control V2 Sync`.
2. Prove no V2 process or active run remains.
3. Enable `TSD Production Control Sync`.
4. Run and verify the legacy writer heartbeat and next COMPLETE sync.
5. Reassign `tsd-production-control.vercel.app` to `https://tsd-production-control-4i4vku22j-tsd7.vercel.app`.
6. Verify legacy login, Dashboard, Machine Load, Release Queue, Maintenance and freshness.
7. Preserve V2 for diagnosis.

No database restoration is part of rollback because legacy and V2 databases remain independent.

## Final classification

- P0: 0.
- P1: 0.
- Data integrity: PASS.
- Authentication: PASS.
- Production smoke: PASS.
- Autonomous sync: PASS.
- Rollback target: RETAINED.

**C5.14 CONTROLLED PRODUCTION CUTOVER: PASS**

**CANONICAL V2 IS NOW PRODUCTION**
