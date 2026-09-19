# Canonical V2 - C5.11.2B Preview Browser Functional Regression

## Test target

- Preview: `https://tsd-production-control-v2-preview-d3v3eup7c-tsd7.vercel.app`
- Application commit: `5e2bb18c7c87f4a23a6a1615750a0aa0db16f45a`
- Supabase V2 project: `saecycamkyvzzppxudzq`
- Test identities: `felipe.s@tankstreamdesign.com` and `fsantos_cb@hotmail.com`
- Final role for both identities: `ADMIN`
- Credentials are intentionally excluded from this report and must be rotated before cutover.

## Functional page matrix

| Identity | Page | Route | Result |
| --- | --- | --- | --- |
| Felipe | Login | `/login` | PASS |
| Felipe | Dashboard | `/` | PASS |
| Felipe | Orders / DTG | `/production/dtg` | PASS |
| Felipe | Planning | `/production/planning` | PASS |
| Felipe | Machine Load | `/production/machine-load` | PASS |
| Felipe | Release Queue | `/release-queue` | PASS |
| Felipe | Scanner | `/scanner` | PASS |
| Felipe | Source Data | `/admin/source-data` | PASS |
| Felipe | Performance | `/production/performance` | PASS |
| Felipe | Production Flow | `/production/flow` | PASS |
| Felipe | DTG | `/production/flow` | PASS |
| Felipe | Underprint | `/production/flow` | PASS |
| Felipe | Screen Print | `/production/flow#screen-jobs` | PASS |
| Felipe | Maintenance | `/maintenance` | PASS |
| Felipe | Assets | `/maintenance/assets` | PASS |
| Felipe | Preventive | `/maintenance/preventive` | PASS |
| Felipe | Capacity | `/production/capacity` | PASS |
| fsantos | Login | `/login` | PASS |
| fsantos | Dashboard | `/` | PASS |
| fsantos | Planning | `/production/planning` | PASS |
| fsantos | Machine Load | `/production/machine-load` | PASS |
| fsantos | Release Queue | `/release-queue` | PASS |
| fsantos | Maintenance | `/maintenance` | PASS |
| fsantos | Source Data | `/admin/source-data` | PASS |

All tested routes returned HTTP 200 after authentication. No authorization failure, login loop, redirect loop, page exception, or application HTTP 4xx/5xx response was observed.

## Data and business-rule checks

- Dashboard rendered seven operational cards with Production and Oracle status present.
- Machine Load rendered 8,268 rows and exposed DTG, Underprint, and Screen Print data.
- Release Queue rendered 184 rows. Its visible title is `Orders to be released`; the absence of the literal word `Queue` is not a defect.
- Source Data rendered 25 rows.
- Performance rendered 19 rows with DTG and Underprint content.
- Production Flow rendered four operational cards with DTG, Underprint, and Screen Print content.
- Preventive Maintenance rendered four cards.
- Maintenance displayed six migrated work-order detail links.
- Work-order detail displayed history, comments, downtime, and asset information.
- Direct query of `v_release_queue` for `route_id = PAK7` returned zero rows. Screen Print remains excluded from Release Queue as required.

## Authorization and security

- `felipe.s@tankstreamdesign.com`: authentication PASS; ADMIN authorization PASS.
- `fsantos_cb@hotmail.com`: authentication PASS; ADMIN authorization PASS.
- Sequential Felipe role validation: OPERATOR PASS, SUPERVISOR PASS, MANAGER PASS, ADMIN PASS, with a fresh authentication session after each transition.
- Direct client/API writes to service-only `source_orders` returned HTTP 403 for every tested role and both master identities.
- Final Felipe membership was restored to ADMIN.
- Production, legacy DEV, Oracle, and scheduler state were not changed. Oracle remained READ-ONLY and the scheduler remained OFF.

## Internal navigation

| Journey | Result | Classification |
| --- | --- | --- |
| Dashboard to Machine Load | PASS | - |
| Maintenance to Work Orders | PASS | - |
| Work Orders to Work Order detail | PASS | - |
| Assets to Asset detail | PASS | - |
| Performance to Order detail | PASS | - |
| Machine Load to detail | NOT AVAILABLE | P2 navigation gap |
| Release Queue to Order detail | NOT AVAILABLE | P2 navigation gap |
| Planning to Order detail | NOT AVAILABLE | P2 navigation gap |
| Work Order to Asset detail | NOT AVAILABLE | P2 navigation gap |

The four P2 findings reflect links not exposed by the current page implementation. They do not represent authentication failures, data loss, runtime failures, or P0/P1 cutover blockers. No architecture or business logic was changed during this regression phase.

## Runtime observations

- Browser page exceptions: 0.
- Application console exceptions: 0.
- Page HTTP 4xx/5xx responses: 0.
- Expected Next.js RSC prefetch cancellations (`net::ERR_ABORTED`) were observed during navigation and classified as non-defects.

## Automated regression evidence

- Lint: PASS.
- Typecheck: PASS.
- Shared tests: 49 PASS.
- Oracle sync tests: 16 PASS.
- Web tests: 133 PASS.
- Total application tests: 198/198 PASS.
- Production build: PASS.

## Severity and gate

- P0: 0.
- P1: 0.
- P2: 4 navigation gaps.
- Code fixes introduced by C5.11.2B: none.

**C5.11.2B PREVIEW BROWSER REGRESSION: PASS**

**C5.11 SECURITY GATE: PASS**
