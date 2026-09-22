# TSD Production Control - Infrastructure Consolidation Baseline

Captured: 2026-09-22 (Australia/Brisbane)

## Scope and freeze

This document records the pre-change state for Phase 0. No production
configuration, credentials, migrations, projects, deployments, databases,
schedulers, writer configuration, or Oracle objects were changed while
capturing this baseline.

The following remain frozen until their applicable phase and gate:

- database migrations;
- infrastructure configuration;
- credentials and passwords;
- Vercel and Supabase project creation or deletion;
- production deployments;
- writer and scheduler configuration.

## Repository

| Field | Captured value |
| --- | --- |
| Repository | `C:\Projects\tsd-canonical-data-simplification` |
| Remote | `https://github.com/fsantoscb/tsd.git` |
| Current branch | `codex/canonical-data-simplification` |
| HEAD | `507992b5733b8c26352d00afad2dc268296f090f` |
| Upstream | `origin/codex/canonical-data-simplification` |
| Upstream state | Local branch ahead by 1 commit |
| `origin/main` | `55db6cfbdb476b21f31045fbd282fa7bfb93da68` |
| Difference from `origin/main` | Current branch ahead by 33 commits, behind by 0 |

### Working tree at capture

The working tree was not clean before this document was created.

Pre-existing untracked paths:

- `.superpowers/`
- `apps/oracle-sync/scripts/dtg-three-orders-diagnostic.mts`

No pre-existing tracked modification was reported by `git status`.

## Vercel production

| Field | Captured value |
| --- | --- |
| Project name | `tsd-production-control-v2-preview` |
| Project ID | `prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc` |
| Team ID | `team_3yv8zOxnzDfuaOlAPEjkNvbd` |
| Production domain | `https://tsd-production-control.vercel.app` |
| Domain deployment | `dpl_GDYgrPm385SLf1xYao3cW2UTyVb5` |
| Deployment URL | `tsd-production-control-v2-preview-eroyrv6wd-tsd7.vercel.app` |
| Deployment state | `READY` |
| Deployment source | Vercel CLI promotion |
| Deployment Git ref | `codex/canonical-data-simplification` |
| Deployment Git SHA | `507992b5733b8c26352d00afad2dc268296f090f` |
| Deployment metadata | `gitDirty=1` |
| Application health | `/api/health` returned HTTP 200 with `status=ok` |

The deployment SHA matches the current local HEAD. The Vercel project name is
potentially misleading and is not treated as evidence of environment purpose.
The deployment metadata records a dirty source tree and must be reviewed in a
later phase.

## Supabase target

| Field | Captured value |
| --- | --- |
| Current production target | `eziirebccovlvhaonsgw` |
| Project URL | `https://eziirebccovlvhaonsgw.supabase.co` |
| Evidence | Runtime login, PostgREST recovery checks, local web target, writer target guard, and writer ingest endpoint |
| Current status | Healthy after one controlled infrastructure restart earlier on 2026-09-22 |
| PostgREST | Responsive after restart; service-role minimal read HTTP 200 |

The Vercel Production environment variable is encrypted in the Vercel API, so
its value was not printed. Runtime authentication and the live application were
previously verified against this project. Full cross-environment classification
belongs to Phase 1 and Phase 2.

## Factory writer

| Field | Captured value |
| --- | --- |
| Repository path | `C:\Projects\tsd-canonical-data-simplification\apps\oracle-sync` |
| Branch / HEAD | `codex/canonical-data-simplification` / `507992b5733b8c26352d00afad2dc268296f090f` |
| Agent ID | `tsd-v2-production-FELIPE-LT` |
| Connector version | `0.2.0+33571de` |
| Ingest endpoint | `https://tsd-production-control-v2-preview.vercel.app/api/ingest` |
| Expected Supabase ref | `eziirebccovlvhaonsgw` |
| Sync interval | 300 seconds |
| Last observed successful batch | `06be4b2c-e3e6-4bd6-9f65-30b48040ea14` |
| Last observed successful batch completion | `2026-09-22T11:50:17.4746613+10:00` |
| Last observed heartbeat/tick | `2026-09-22T11:53:42.6209182+10:00` |
| Raw Oracle audit replication | Disabled in current successful sync log |
| Concurrent writer process at capture | None outside the scheduled tick |

The writer contains a runtime project-ref guard and refuses a mismatched
Supabase target.

## Scheduler

| Field | Captured value |
| --- | --- |
| Scheduled Task | `TSD Production Control V2 Sync` |
| State | `Ready` |
| Last run | `2026-09-22 11:50:28 +10:00` |
| Last result | `0` |
| Next run at capture | `2026-09-22 11:51:27 +10:00` |
| Script | `apps/oracle-sync/scripts/agent-tick.ps1` |
| Working directory | `C:\Projects\tsd-canonical-data-simplification\apps\oracle-sync` |

## Oracle safety

| Field | Captured value |
| --- | --- |
| Connect target | `192.168.0.222:1521/TSDPROD` |
| Credential target | `TSDPROD_KPI_ORACLE` |
| Mode | READ ONLY |

Evidence:

- source readers issue `SET TRANSACTION READ ONLY` before operational reads;
- the Oracle connectivity test executes only `SELECT 1 ... FROM dual`;
- the source-reader execution sites contain read queries and no Oracle DML or
  DDL operation was found;
- no Oracle change was performed during baseline capture.

## Known unresolved production issue

`/production/performance` remains under investigation. The mission supplied
digest `1502913064`; a later authenticated attempt after infrastructure recovery
returned server-component digest `2241656518`. Phase 0 does not diagnose or fix
this application path.

## Audit log

| Time / phase | Action | Production side effect |
| --- | --- | --- |
| Phase 0 | Read Git identity and worktree state | None |
| Phase 0 | Read Vercel project, alias, deployment metadata and health | None |
| Phase 0 | Read writer configuration, logs, process and scheduler state | None |
| Phase 0 | Read Oracle safety controls in source | None |
| Phase 0 | Created this baseline document | Repository documentation only |

## Gate 0

**PASS**

The current system identity was captured without modifying Production. All
infrastructure, migration, credential, project and deployment changes remain
frozen. Phase 1 may inventory the full environment; no cleanup is authorised by
this gate.
