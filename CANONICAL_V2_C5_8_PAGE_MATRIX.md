# Canonical V2 C5.8 Page Matrix

Validation date: 2026-09-19 (Australia/Brisbane)

Preview deployment: `https://tsd-production-control-v2-preview-i2hscj6co-tsd7.vercel.app`

Target Supabase project: `saecycamkyvzzppxudzq` (Canonical V2)

## Authentication and shell

| Area | Route | Result | Evidence |
| --- | --- | --- | --- |
| Login | `/login` | PASS | Password authentication completed against V2 Auth. |
| Unauthorized protection | `/production/dtg` | PASS | Anonymous request redirected to `/login`. |
| Control Tower | `/` | PASS | Loaded V2 operational KPIs and navigation. |
| Health | `/api/health` | PASS | HTTP 200 on Preview deployment. |

## Production and planning

| Page | Route | Result | Evidence |
| --- | --- | --- | --- |
| Machine Load | `/production/machine-load` | PASS | Loaded after server render; no application or console error. |
| Operational Performance | `/production/performance` | PASS | Loaded production, labour and Oracle freshness state; no console error. |
| DTG | `/production/dtg` | PASS | 90 orders and 6,630 garments loaded from the V2 snapshot. |
| Underprint | `/production/up` | PASS | 29 orders and 2,318.019 units represented by the current source contract. |
| Dispatch / Ready to Lift | `/production/ready-to-lift` | PASS | Page rendered from V2 without fallback or error state. |
| Hold Orders | `/production/hold-orders` | PASS | Page rendered and navigation remained authenticated. |
| Release Queue | `/production/release-queue` | PASS | 184 rows / 101,839 units in database; route loaded successfully. |
| Order Planning | `/production/planning` | PASS | Canonical planning list loaded. |
| Shift Plans | `/production/plans` | PASS | Plan list and controls loaded. |
| Capacity | `/production/capacity` | PASS | Capacity profiles and scenario UI loaded. |
| Labour | `/production/labour` | PASS | Area / shift labour matrix loaded. |
| Flow | `/production/flow` | PASS | DTG, Underprint and Workbank-authority Screen Print lanes loaded. |
| KPIs | `/kpis` | PASS | Performance, target and risk dashboard loaded. |
| Scan | `/scan` | PASS | Scanner/manual lookup interface loaded. |
| Deputy Imports | `/production/deputy` | PASS | Import history and controls loaded. |

## Maintenance

| Page | Route | Result | Evidence |
| --- | --- | --- | --- |
| Overview | `/maintenance` | PASS | Reliability overview loaded after normal client hydration. |
| Operator Terminal | `/maintenance/operator` | PASS | Equipment selection interface loaded. |
| Work Orders | `/maintenance/work-orders` | PASS | Work-order list loaded. |
| Assets | `/maintenance/assets` | PASS | Asset/component register loaded. |
| Preventive | `/maintenance/preventive` | PASS | Preventive plan page loaded. |
| Inventory | `/maintenance/inventory` | PASS | Inventory page loaded; empty-state totals are valid for V2. |

## Administration and source visibility

| Page | Route | Result | Evidence |
| --- | --- | --- | --- |
| Source Health | `/admin/sync-status` | PASS | Latest completed snapshot and offline agent state displayed. |
| Reconciliation | `/admin/reconciliation` | PASS | Source reconciliation page loaded. |
| Source Data | `/admin/source-data` | PASS | Current Orders dataset loaded. |

## Interaction and responsive checks

| Check | Result | Notes |
| --- | --- | --- |
| Sidebar navigation | PASS | Production, planning, maintenance and admin destinations resolved. |
| DTG search/sort query handling | PASS | Query-string variants rendered without server/application error. |
| Release Queue filtering route | PASS | Filtered route remained valid and data-backed. |
| Desktop 1440x900 | PASS | Primary command-centre and data-grid layouts rendered normally. |
| Mobile 390x844 | PASS WITH P2 NOTE | KPI cards reflow correctly. Dense navigation and wide operational tables intentionally use horizontal scrolling; no clipped action or application error was found. |

## Severity summary

| Severity | Count |
| --- | ---: |
| P0 | 0 |
| P1 | 0 |
| P2 | 1 |
| P3 | 0 |

The P2 item is the broad horizontal scroll surface on narrow screens. It does not block Preview validation or operational use and does not affect data correctness.
