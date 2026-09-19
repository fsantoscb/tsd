# Canonical V2 - C5.15 Post-Cutover Stabilization

## Scope

Post-cutover observation of Canonical V2 production. No feature, schema, migration, Oracle, legacy environment, or Maintenance UX change was made during this phase.

## Production baseline

- Production URL: `https://tsd-production-control.vercel.app`
- Production implementation commit: `33571de`
- V2 Supabase project: `saecycamkyvzzppxudzq`
- Legacy Supabase project: `gdajktoqmajipivpdude` (untouched)
- Legacy rollback deployment: `https://tsd-production-control-4i4vku22j-tsd7.vercel.app`
- Legacy sync task: disabled
- V2 sync task: enabled
- Oracle: read-only and untouched

## Automatic synchronization stability

Seven consecutive automatic production runs were observed after cutover. All seven completed successfully. Durations ranged from 44.856 to 61.391 seconds. Every run reported 1,174 orders, 8,031 Workbank rows, 60 stock rows, and no sync failure.

Latest observed successful baseline:

- Run ID: `5966ba1b-e205-475c-a13f-be6ad29c235e`
- Batch ID: `2f103df3-978c-4636-b6c2-781c0cbf5f39`
- Completed: `2026-09-19 15:46:25 UTC`
- Agent: `tsd-v2-production-FELIPE-LT`
- Agent state: online
- Current run after completion: none
- Last agent error: none

The Oracle source timestamp remained stable while connector runs continued successfully. This is consistent with unchanged source data and is not a stale-agent condition.

## Data integrity baseline

| Check | Result |
| --- | ---: |
| Orders | 1,174 |
| Workbank rows | 8,031 |
| Workbank quantity | 12,777 |
| Release lines | 25,191 |
| Release Queue rows | 204 |
| Release Queue quantity | 118,307 |
| Audit events | 76,399 |
| DTG history rows | 826 |
| Production events | 49,199 |
| Capacity rows | 3 |
| Maintenance work orders | 4 |
| Maintenance history rows | 6 |
| Maintenance comments | 4 |
| Maintenance downtime rows | 3 |
| Active sync runs | 0 |

Duplicate checks returned zero for Workbank, audit event IDs, audit hashes, DTG history, production events, maintenance records, and capacity records.

Orphan checks returned zero for release lines, Manufacturing Order operations, maintenance assets, and maintenance parts.

## Source authority regression

- Screen Print Release Queue rows: 0
- Screen Print Release Queue quantity: 0
- Screen Print incorrectly classified as Not Approved: 0
- No double-counting evidence was found.
- Legacy writer remained disabled; Canonical V2 remained the single active writer.

## Production browser smoke test

| Route | Result |
| --- | --- |
| `/` | PASS |
| `/production/dtg` | PASS |
| `/production/planning` | PASS |
| `/production/machine-load` | PASS |
| `/production/release-queue` | PASS |
| `/scan` | PASS |
| `/production/performance` | PASS after reload; see P2 observation |
| `/production/flow` | PASS |
| `/production/screen-events` | PASS |
| `/maintenance` | PASS |
| `/maintenance/assets` | PASS |
| `/maintenance/preventive` | PASS |

## Runtime observation

One non-reproducible server-side exception appeared once on `/production/performance`, digest `2241656518`. An immediate reload rendered the complete page and data, and subsequent access remained operational. No corresponding new error was captured by the bounded Vercel log stream. This is classified as P2 for monitoring, not P0/P1, because the page recovered without a change and the failure could not be reproduced.

Existing navigation gaps remain P2 and were not reclassified or changed during stabilization.

## Authentication and security

- Production login and authorized navigation: PASS
- Both permanent V2 identities had previously passed active-membership and login validation in C5.14.
- The temporary first-user smoke password was rotated after testing to a new random password.
- The final credential is stored only in Windows Credential Manager under `TSD_V2_ADMIN_FSANTOS_CB`.
- Direct login after final rotation: PASS
- Public/anonymous RLS policies found: 0
- Anonymous operational write grants found: 0
- No service credential was exposed in this report.

## Regression status inherited from controlled cutover

The deployed C5.14 implementation retains the validated C5.13/C5.14 quality baseline: lint PASS, typecheck PASS, 200/200 application tests PASS, production build PASS, database/security validation PASS. No application or database code changed in C5.15, so no new implementation regression was introduced.

## Severity summary

| Severity | Count | Status |
| --- | ---: | --- |
| P0 | 0 | PASS |
| P1 | 0 | PASS |
| P2 | 5 | Monitor: four existing navigation gaps and one transient Performance exception |
| P3 | 0 | PASS |

## Rollback and environment preservation

- Legacy rollback deployment remains available.
- Legacy sync remains disabled.
- No legacy environment was decommissioned.
- No production or V2 migration was applied.
- No Oracle write was performed.
- Maintenance UX worktree was not merged or modified.

## Final gate

`C5.15 POST-CUTOVER STABILIZATION: PASS`

`CANONICAL V2 PRODUCTION BASELINE STABLE`

`READY TO RESUME NORMAL ERP DEVELOPMENT`
