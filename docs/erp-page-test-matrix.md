# ERP page test matrix

PASS means rendered in the authenticated sweep. RETEST means the result was invalidated by the later HTTP 413. STATIC means a valid record or token is required.

| Page | Route | Role | Status | Issue |
|---|---|---|---|---|
| Control tower | / | authenticated | FIXED | Initial server exception |
| Reconciliation | /admin/reconciliation | admin | PASS | Role boundary pending |
| Source data | /admin/source-data | admin | PASS | Role boundary pending |
| Sync status | /admin/sync-status | admin | PASS | Role boundary pending |
| KPI dashboard | /kpis | manager | PASS | Filter matrix pending |
| KPI detail | /kpis/[code] | manager | STATIC | Valid KPI required |
| Maintenance | /maintenance | manager | PASS | Export matrix pending |
| Assets | /maintenance/assets | maintenance | PASS | Mutations need fixture |
| Asset detail | /maintenance/assets/[id] | maintenance | STATIC | Test asset required |
| Inventory | /maintenance/inventory | maintenance | PASS | Mutations need fixture |
| Operator terminal | /maintenance/operator | operator | RETEST | Slow marker in short sweep |
| Preventive | /maintenance/preventive | maintenance | PASS | Golden path needs fixture |
| Maintenance reports | /maintenance/reports | manager | PASS | Export contents pending |
| Work orders | /maintenance/work-orders | maintenance | PASS | Lifecycle needs fixture |
| Work order detail | /maintenance/work-orders/[id] | maintenance | STATIC | Test order required |
| Asset QR | /maintenance/scan/[token] | operator | STATIC | Token fixtures required |
| Capacity | /production/capacity | planner | PASS | Combination tests pending |
| Close order | /production/close-order | operator | PASS | Mutation not exercised |
| Deputy | /production/deputy | admin | PASS | File fixture required |
| DTG | /production/dtg | production | PASS | Filter matrix pending |
| Flow | /production/flow | production | PASS | Reconciliation pending |
| Hold orders | /production/hold-orders | production | PASS | Reconciliation pending |
| Labour | /production/labour | manager | PASS | Date matrix pending |
| Labour detail | /production/labour/detail | manager | PASS | Date matrix pending |
| Machine load | /production/machine-load | planner | PASS | Capacity audit pending |
| Order detail | /production/orders/[orderNo] | production | STATIC | Valid order required |
| Performance | /production/performance | manager | PASS | Cross-component parity pending |
| Planning | /production/planning | planner | PASS | Mutations need fixture |
| Plans | /production/plans | planner | RETEST | Short sweep inconclusive |
| Plan detail | /production/plans/[id] | planner | STATIC | Test plan required |
| Ready to lift | /production/ready-to-lift | production | RETEST | HTTP 413 in sweep |
| Screen events | /production/screen-events | production | RETEST | HTTP 400/413 in sweep |
| Stages | /production/stages | production | RETEST | HTTP 413 in sweep |
| UP | /production/up | production | RETEST | HTTP 413 in sweep |
| Scan | /scan | operator | RETEST | HTTP 413 in sweep |
| KPI settings | /settings/kpis | admin | RETEST | HTTP 413 in sweep |
| Login | /login | public | STATIC | Authentication route |
| Auth confirmation | /auth/confirm | public | STATIC | Callback token required |
| Offline | /offline | public | STATIC | Offline simulation pending |

