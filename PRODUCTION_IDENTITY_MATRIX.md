# TSD Production Control - Production Identity Matrix

Captured: 2026-09-22 (Australia/Brisbane)

## Gate result

**STAGE A: IN PROGRESS**

Production resolves to a primary infrastructure chain. Preview write access to
Production has been removed and the stale scheduler has been disabled. Git/main,
clean deployment, and authenticated runtime validation remain pending.

No configuration was changed while producing this matrix.

## Production identity

| Component | Expected target | Actual target | Evidence | Result |
| --- | --- | --- | --- | --- |
| Git repository | `https://github.com/fsantoscb/tsd.git` | `https://github.com/fsantoscb/tsd.git` | `git remote -v` | MATCH |
| Git production branch | `main` | `codex/canonical-data-simplification` | Vercel deployment metadata and local writer checkout | MISMATCH |
| Git production SHA | `origin/main` = `55db6cfbdb476b21f31045fbd282fa7bfb93da68` | `507992b5733b8c26352d00afad2dc268296f090f` | Vercel deployment metadata | MISMATCH |
| Vercel project | One clearly named Production project | `tsd-production-control-v2-preview` (`prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`) | Vercel project API and alias resolution | REVIEW |
| Vercel production deployment | Deployment serving the production domain | `dpl_GDYgrPm385SLf1xYao3cW2UTyVb5` | Vercel alias API | MATCH |
| Production domain | `tsd-production-control.vercel.app` | Alias targets `dpl_GDYgrPm385SLf1xYao3cW2UTyVb5` | Vercel alias API | MATCH |
| Vercel Production Supabase ref | Verified Production ref | `eziirebccovlvhaonsgw` | Decrypted environment reference inspected without printing secrets | MATCH |
| Vercel Preview Supabase ref | No Production write access | No Supabase URL, anon key, service role, or ingest secret configured | Vercel environment inventory | MATCH |
| Factory repository | Canonical production checkout | `C:\Projects\tsd-canonical-data-simplification` | Scheduled Task action and process command line | MATCH |
| Factory branch | Production branch | `codex/canonical-data-simplification` | Git and Scheduled Task path | MISMATCH |
| Factory HEAD | Production SHA | `507992b5733b8c26352d00afad2dc268296f090f` | Git HEAD | MATCH to deployment, MISMATCH to `main` |
| Factory Supabase ref | Production Supabase ref | `eziirebccovlvhaonsgw` | `.env.sync.local` safe fields | MATCH |
| Writer Supabase ref | Production Supabase ref | `eziirebccovlvhaonsgw` | Runtime `EXPECTED_SUPABASE_PROJECT_REF` guard | MATCH |
| Production scheduler | Exactly one enabled scheduler | `TSD Production Control V2 Sync` only | Windows Scheduled Tasks inventory | MATCH |
| Production writer | Exactly one active writer | One current writer process observed | Process inventory | MATCH at capture |
| Oracle mode | READ ONLY | Explicit read-only transactions and SELECT-only source reader | Source audit | MATCH |

## Authoritative production chain observed

```text
GitHub fsantoscb/tsd
  branch codex/canonical-data-simplification
  SHA 507992b5733b8c26352d00afad2dc268296f090f
        |
        v
Vercel project prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc
  deployment dpl_GDYgrPm385SLf1xYao3cW2UTyVb5
        |
        v
tsd-production-control.vercel.app
        |
        v
Supabase eziirebccovlvhaonsgw
        ^
        |
Factory writer C:\Projects\tsd-canonical-data-simplification\apps\oracle-sync
        ^
        |
TSD Production Control V2 Sync
        ^
        |
Oracle TSDPROD (READ ONLY)
```

The application, deployment and current writer converge on
`eziirebccovlvhaonsgw`; this is therefore the verified `CURRENT_PROD` project.
The classification is based on live references, not project naming.

## Git and GitHub inventory

| Item | Value |
| --- | --- |
| Canonical remote | `https://github.com/fsantoscb/tsd.git` |
| Intended production branch | `main` |
| `origin/main` | `55db6cfbdb476b21f31045fbd282fa7bfb93da68` |
| Deployed branch | `codex/canonical-data-simplification` |
| Deployed/current HEAD | `507992b5733b8c26352d00afad2dc268296f090f` |
| Current branch upstream | `origin/codex/canonical-data-simplification` |
| Current branch state | Ahead of upstream by 1 commit |
| Current working tree before Phase 0 doc | Untracked `.superpowers/` and `apps/oracle-sync/scripts/dtg-three-orders-diagnostic.mts` |
| Current deployment source | CLI promotion with `gitDirty=1` metadata |

Multiple historical feature, routing, maintenance, DTG and backup worktrees
remain present. None was modified during this inventory.

## Vercel inventory

### Current domain-serving project

| Field | Value |
| --- | --- |
| Name | `tsd-production-control-v2-preview` |
| Project ID | `prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc` |
| Production deployment | `dpl_GDYgrPm385SLf1xYao3cW2UTyVb5` |
| Deployment state | READY |
| Production Supabase ref | `eziirebccovlvhaonsgw` |
| Preview Supabase ref | None; Production Supabase credentials removed |
| Status | Active; serves the production alias |

### Legacy-named project

| Field | Value |
| --- | --- |
| Name | `tsd-production-control` |
| Project ID | `prj_uPy9OhX0A3RSSC5wFRPiWBeclHox` |
| Latest listed production deployment | `dpl_BWXUyNJWL3txZp3Jo9Kp2MFYVmqA` |
| Configured Production Supabase ref | `gdajktoqmajipivpdude` |
| Status | Deployment exists, but the authoritative domain alias resolves to the other project/deployment |
| Classification | LEGACY candidate; not safe to retire without dependency review |

Secrets were not printed. Only variable names, targets and project refs were
used for classification.

## Supabase inventory

| Project ref | Evidence and accessibility | References found | Classification | Safe to retire now |
| --- | --- | --- | --- | --- |
| `eziirebccovlvhaonsgw` | Active; Auth/PostgREST responsive; canonical tables and data present | Current Vercel Production, current Vercel Preview, writer and scheduler | CURRENT_PROD | NO |
| `saecycamkyvzzppxudzq` | Active; Auth/PostgREST responsive; canonical tables and data present | Local `C:\Projects\tsd-canonical-v2` configuration | ROLLBACK | NO |
| `gdajktoqmajipivpdude` | Endpoint active, but credentials retained by the old Vercel project return 401 | Legacy Vercel Production environment | LEGACY | NO |
| `tlflipdeahgwsueerkex` | DNS unavailable at capture; local DEV configuration remains | Local `C:\Projects\tsd` DEV files | DEV | NO |

`tlflipdeahgwsueerkex` is consistent with a paused or otherwise unavailable DEV
project, but the exact control-plane state could not be read during the browser
session. It is not classified as deleted.

## Factory agent and scheduler inventory

### Current production writer

| Field | Value |
| --- | --- |
| Path | `C:\Projects\tsd-canonical-data-simplification\apps\oracle-sync` |
| Branch / HEAD | `codex/canonical-data-simplification` / `507992b...` |
| Agent ID | `tsd-v2-production-FELIPE-LT` |
| Connector version | `0.2.0+33571de` |
| Supabase guard | `eziirebccovlvhaonsgw` |
| Oracle target | `192.168.0.222:1521/TSDPROD` |
| Last observed successful batch | `06be4b2c-e3e6-4bd6-9f65-30b48040ea14` |
| Last observed successful completion | `2026-09-22T11:50:17.4746613+10:00` |
| Last observed tick | `2026-09-22T11:53:42.6209182+10:00` |

### Scheduled Tasks

| Task | State | Target | Last result | Assessment |
| --- | --- | --- | --- | --- |
| `TSD Production Control V2 Sync` | Enabled; Ready | Current canonical writer path | `0`; current log records repeated `SYNC_SUCCESS` | Intended production scheduler |
| `TSD Production Control Sync` | Disabled | `C:\TSD Production Control Full\...\agent-tick.ps1` | `1`; log reports control API HTTP 401 | Preserved but inactive stale scheduler |
| `TSD Production Control - Oracle Sync` | Disabled | Historical `C:\Projects\TSD Production Control\...` | `0` at last historical run | Inactive legacy task |

The stale process was ended before its task was disabled. Exactly one production
scheduler remains enabled.

## Phase 1 conclusion

The inventory is complete enough to establish the active chain and identify
conflicts. No project, task, credential, deployment or database was changed.

## Gate 2 blockers

1. Production is deployed from `codex/canonical-data-simplification`, not
   `main`.
2. Production SHA `507992b...` differs from `origin/main` `55db6cf...`.
3. The active Vercel project name contains `preview`, creating operational
   ambiguity, although the alias and project IDs are unambiguous.
4. The active deployment records `gitDirty=1`, so the released artifact was not
   produced from a demonstrably clean checkout.

Per the consolidation plan, Phase 3 configuration correction must not begin
until these mismatches are deliberately resolved with rollback steps.
