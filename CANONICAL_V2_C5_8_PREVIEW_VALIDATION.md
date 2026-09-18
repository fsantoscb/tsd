# Canonical V2 C5.8 Preview Validation

## Scope and isolation

- Branch/worktree: `canonical-v2` / `C:\Projects\tsd-canonical-v2`
- V2 Supabase project: `saecycamkyvzzppxudzq`
- Isolated Vercel project: `tsd-production-control-v2-preview`
- Vercel project ID: `prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`
- Preview deployment: `https://tsd-production-control-v2-preview-i2hscj6co-tsd7.vercel.app`
- Deployment ID: `dpl_13mTxAW5QEFP2CEpu7zWXEqWpMan`
- Deployment target: Preview; no promotion was performed.
- DEV was untouched.
- Production Supabase and production Vercel were untouched.
- Oracle remained read-only.
- Production scheduler/cutover remains off.

## C5.3 1,149 to C5.7 1,147 order delta

The two figures belong to different complete Oracle snapshots:

| Snapshot | Completed at | Orders |
| --- | --- | ---: |
| C5.3 comparison snapshot | 2026-09-18 21:11:59 +10:00 | 1,149 |
| C5.7/latest stable snapshot | 2026-09-19 00:44:24 +10:00 | 1,147 |

Classification: `SOURCE_TIMING_DIFFERENCE`.

The V2 database keeps the historical batch header and its `orders_count`, but `source_orders` is the current-state store populated by the latest complete snapshot. Rows from the earlier batch are no longer retained there. Consequently, the net removal of two source orders is proven by the two complete snapshot headers, while their individual order numbers cannot be reconstructed from the retained V2 tables. This is a source-snapshot retention limitation, not an application aggregation defect. The latest V2 UI, latest V2 batch and the C5.7 parity gate all consistently use 1,147.

## Preview activation

The first deployment attempt correctly failed because it was classified into the new project's Production environment while all V2 credentials were restricted to Preview. No output was promoted. The deployment was repeated with an explicit Preview target and completed successfully with all 44 Next.js routes generated.

Vercel team SSO protection was disabled only for the isolated Preview project so that application authentication and automated HTTP checks could run. ERP/Supabase authentication remained enforced: anonymous protected-route access redirected to `/login`.

## Data evidence

Latest completed V2 snapshot:

| Metric | Value |
| --- | ---: |
| Orders | 1,147 |
| Workbank rows | 8,323 |
| Stock rows | 57 |
| Release Queue rows | 184 |
| Release Queue quantity | 101,839 |
| Not Approved rows | 560 |
| Not Approved quantity | 2,536 |
| Duplicate active production demand | 0 |
| Negative production demand quantity | 0 |

Screen Print remained Workbank-authoritative and is not treated as missing release demand. The dedicated regression tests for Screen Print exclusion from Release Queue passed.

## Page validation

All pages listed in `CANONICAL_V2_C5_8_PAGE_MATRIX.md` were opened against the remote Preview using an authenticated V2-only test session. No P0 or P1 functional defect was found. Heavy server-rendered pages (`Machine Load`, `Operational Performance`) required additional load time but completed without application or browser-console errors.

## Automated validation

| Gate | Result |
| --- | --- |
| Preview HTTP health | PASS (200) |
| Remote Vercel build | PASS (44 routes) |
| Lint | PASS |
| Typecheck | PASS |
| Shared tests | 49/49 PASS |
| Oracle sync tests | 15/15 PASS |
| Web tests | 132/132 PASS |
| Total tests | 196/196 PASS |
| Local production build | PASS (44 routes) |

The initial parallel typecheck collided with `next build` while `.next/types` was being regenerated and reported missing generated files. After the build completed, the isolated typecheck passed. This was a validation-process race, not an implementation failure.

## Findings

- P0: 0
- P1: 0
- P2: 1 (wide-table/navigation horizontal scrolling on 390px mobile viewport)
- Data parity/integrity blocker: 0
- Cutover performed: no

## Gate

Canonical V2 Preview is operational and data-backed. This report authorizes only the next readiness review; it does not authorize production cutover, scheduler activation, production migration, or Oracle writes.

READY FOR CUTOVER READINESS REVIEW
