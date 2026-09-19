# Canonical V2 - C5.12 Agent, Single Writer, and Rollback Rehearsal

## Scope and environment

- Worktree: `C:\Projects\tsd-canonical-v2-security`
- Branch: `canonical-v2-security`
- Approved security baseline: `2964c27135308ef434b03e08ee2d07f1d39b3c4e`
- C5.12 agent implementation commit: `03a6e2c`
- Canonical V2 project: `saecycamkyvzzppxudzq`
- Legacy production project: `gdajktoqmajipivpdude`
- DEV: untouched
- Production domain: unchanged
- Oracle: READ-ONLY
- Maintenance UX worktree: untouched

## Legacy agent architecture

- Writer ID: Windows Scheduled Task `TSD Production Control Sync`
- Host: `FELIPE-LT`, Windows, user `Felipe.Santos`
- Script: `C:\TSD Production Control Full\apps\oracle-sync\scripts\agent-tick.ps1`
- Working directory: `C:\TSD Production Control Full\apps\oracle-sync`
- Trigger: every minute; automatic sync eligibility every five minutes
- Startup/recovery: Windows Task Scheduler, `StartWhenAvailable`, two retries, one instance only
- Target: `https://tsd-production-control.vercel.app/api/ingest` -> legacy project `gdajktoqmajipivpdude`
- Heartbeat, lock, and run ledger: `sync_agent_heartbeat`, `claim_sync_work`, and `sync_runs`
- Log: `apps/oracle-sync/scripts/sync-agent.log`
- Duplicate legacy task `TSD Production Control - Oracle Sync`: disabled

The legacy writer was not stopped until its target, task, log, and most recent successful run had been positively identified.

## V2 agent architecture

- Executable: `pnpm exec tsx src/cli.ts agent:tick`
- Heartbeat-only command: `pnpm exec tsx src/cli.ts agent:heartbeat`
- Working directory: `C:\Projects\tsd-canonical-v2-security\apps\oracle-sync`
- Target: V2 Preview ingest API -> `saecycamkyvzzppxudzq`
- Source: Oracle through the existing Windows credential target `TSDPROD_KPI_ORACLE`
- Frequency contract: 300 seconds
- Identity: unique `agent_id`, host, connector version/commit, process instance, start time, target project
- Heartbeat: `sync_agent_heartbeat`
- Lock: transactional `claim_sync_work`, advisory serialization, active-run refusal, 20-minute lease recovery
- Run ledger: `sync_runs`
- V2 scheduler after rehearsal: OFF

## Target guard

The invalid fixture used expected project `aaaaaaaaaaaaaaaaaaaa` while the endpoint identified itself as `saecycamkyvzzppxudzq`.

- Result: `SYNC_TARGET_PROJECT_MISMATCH`
- API calls before abort: organization identity only
- Heartbeat rows before and after: unchanged
- Claim/sync/write: none
- `TARGET_GUARD_TEST`: PASS

The valid heartbeat identified project `saecycamkyvzzppxudzq`, host `FELIPE-LT`, agent `c512-v2-FELIPE-LT-52720`, and version `0.2.0-c512-2964c27`.

## Heartbeat and freshness

- Real agent heartbeat reached only V2.
- No permanent scheduler was enabled.
- The stopped test agent aged beyond the 180-second threshold and classified as `AGENT_OFFLINE`.
- Freshness states remain distinct: `CURRENT`, `DELAYED`, `STALE`, `FAILED`, `AGENT_OFFLINE`, and `NO_DATA`.
- Agent health, latest sync status, and data freshness are separate signals in the Source Health model.

## Locking and contention

| Test | Evidence | Result |
| --- | --- | --- |
| Run A acquisition | `44be0431-5a25-470e-a4f5-93592b90c5f7` | PASS |
| Run B contention | `29baa0aa-0f68-4049-b301-669f147dbaac`, `ACTIVE_RUN_EXISTS` | REFUSED / PASS |
| Failure release | Run A finished as controlled failure; next request acquired | PASS |
| Stale owner | `5d68f7c4-d041-4677-adf0-e8b4c8d2740d` | PASS |
| Stale recovery reason | `STALE_RUN_LEASE_EXPIRED` after 21-minute fixture age | PASS |
| Active runs after tests | 0 | PASS |

The lease is 20 minutes. Recovery is serialized by the same advisory transaction lock; it does not perform aggressive lock stealing while a valid lease remains active.

## First manual V2 sync

The legacy writer remained active because the two writers targeted separate databases.

- Run: `5eab0fe7-52b7-4fff-8aa0-6b5074c7157f`
- Agent: `c512-manual-FELIPE-LT-64564`
- Started: `2026-09-19 23:43:59 +10:00`
- Completed: `2026-09-19 23:44:54 +10:00`
- Duration: 52,575 ms
- Batch: `8f475709-d660-40e1-8f74-f6b07c78fb8f`
- Orders: 1,174
- Workbank rows: 8,031
- Stock rows: 60
- New audit events: 307
- Status: SUCCESS / COMPLETE

Post-run reconciliation:

- Workbank units: 12,777
- Release lines: 25,121
- Release Queue rows: 203
- Screen Print Release Queue rows: 0
- Duplicate workbank source keys: 0
- Duplicate audit IDs/hashes: 0
- Duplicate production events: 0
- Duplicate active-demand mappings: 0
- Orphan release lines: 0
- Orphan MO operations: 0
- Orphan maintenance assets: 0
- Unexplained deltas: 0

## Single-writer rehearsal timeline

| Event | Timestamp / evidence |
| --- | --- |
| Legacy last successful sync before stop | batch `7130430e-2083-4792-8ad0-2a8167eb9338`, tick completed by `2026-09-19 23:43:19 +10:00` |
| Legacy writer stopped | `2026-09-19 23:46:41 +10:00` |
| Legacy task/process verified stopped | task `Disabled`; active legacy processes 0 |
| V2 writer started | `2026-09-19 23:48:09 +10:00` |
| V2 first heartbeat | target guard and heartbeat completed before claim at `2026-09-19 23:48:19 +10:00` |
| V2 sync started | `2026-09-19 23:48:19 +10:00` |
| V2 sync completed | `2026-09-19 23:49:07 +10:00` |
| V2 writer stopped | process exited after successful completion; process count 0 before restoration |
| Legacy writer restarted | `2026-09-19 23:50:29 +10:00` |
| Legacy heartbeat restored | tick completed `2026-09-19 23:51:28 +10:00` |
| Legacy sync restored | batch `cd17e42c-cc91-41b8-a88c-ec26177c7cbc`, `SYNC_SUCCESS` |

Rehearsal V2 run:

- Run: `dc96e847-7e74-45f5-9863-6e249b2bb755`
- Batch: `910a1984-fda8-4499-a227-dcf9eb5df19e`
- Orders: 1,174
- Workbank rows: 8,031
- Stock rows: 60
- Audit events: 0 new
- Duration: 45,348 ms
- Result: SUCCESS / COMPLETE

Post-rehearsal reconciliation remained identical for orders, workbank, quantity, release lines, and audit totals. All duplicate/orphan indicators remained zero.

## Zero-overlap evidence

- Legacy stopped: `23:46:41 +10:00`
- V2 started: `23:48:09 +10:00`
- V2 completed and exited: `23:49:07 +10:00`
- Legacy restored: `23:50:29 +10:00`
- Writer overlap duration: **0 seconds**
- Forbidden `LEGACY=ON / V2=ON` autonomous state: not observed

Database targets remained separated throughout:

- Legacy writer -> `gdajktoqmajipivpdude`
- V2 writer -> `saecycamkyvzzppxudzq`

## Rollback rehearsal and application rollback

- V2 writer stopped safely after the controlled run.
- Legacy task was re-enabled by its normal reversible Task Scheduler mechanism.
- Legacy next run returned result code 0 and produced `SYNC_SUCCESS`.
- Legacy target and production domain were unchanged.
- Legacy production URL `https://tsd-production-control.vercel.app/login` returned HTTP 200.
- Legacy Vercel project: `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox`.
- V2 Preview Vercel project: `prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`.

## Failure tests and snapshot protection

### Source unavailable

- Run: `0f3d5d27-c238-4659-a6e3-64617dc8f22b`
- Fixture: unreachable local Oracle endpoint `127.0.0.1:1`
- Result: FAILED with source connectivity error
- Batch promoted: none
- Heartbeat: `degraded`, error recorded, `current_run_id = null`
- Lock after failure: released; active runs 0
- Previous COMPLETE batch preserved: `910a1984-fda8-4499-a227-dcf9eb5df19e`

### Database unavailable

- Run: `60ec66c0-fa5a-47ee-acf9-8e0a23f55837`
- Fixture: unreachable non-real hostname after controlled claim
- Database failure observed: yes
- Recovery: lease expiry fixture, status FAILED, reason `STALE_RUN_LEASE_EXPIRED`
- Active runs after recovery: 0
- Previous COMPLETE batch preserved: `910a1984-fda8-4499-a227-dcf9eb5df19e`

These tests prove that RUNNING, PARTIAL, and FAILED work cannot replace the last COMPLETE snapshot. No canonical tables were truncated or corrupted to simulate failure.

## Oracle safety

Both agents use SELECT-only Oracle source readers. No Oracle DML exists in the connector path exercised by C5.12. Oracle was not modified or intentionally taken offline.

## Security regression

- Master users: 2 active.
- `felipe.s@tankstreamdesign.com`: active `admin`.
- `fsantos_cb@hotmail.com`: active `admin`.
- Public/anon policies: 0.
- Normal-user write grants on service-only source/sync tables: 0.
- Service/agent path completed required V2 writes.
- Active sync runs and refresh requests after testing: 0.
- RLS was not weakened.

## Automated validation

- Lint: PASS.
- Typecheck: PASS.
- Shared tests: 49 PASS.
- Oracle sync tests: 18 PASS, increased from 16 by two guarded-heartbeat tests.
- Web tests: 133 PASS.
- Total: 200/200 PASS.
- Production build: PASS.

## Final state

- Legacy writer: ON and healthy.
- V2 writer process: OFF.
- V2 scheduler: OFF.
- Production domain: unchanged.
- DEV: untouched.
- Oracle: READ-ONLY / untouched.
- Maintenance UX worktree: untouched.

Remaining pre-cutover actions belong to C5.13: rotate temporary credentials, finalize production-intended agent configuration, run three consecutive final V2 syncs, and complete final parity reconciliation.

**C5.12 V2 AGENT + SINGLE-WRITER + ROLLBACK: PASS**
