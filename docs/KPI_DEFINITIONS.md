# Production Flow KPI Definitions
- Stage WIP Units: sum of `production_units` currently assigned to one configured stage.
- Remaining Production Units: current-stage WIP only; stages are not added when they may represent the same physical unit.
- Load: stage demand divided by available capacity. Null when capacity is zero or unavailable.
- Capacity Gap: available capacity minus demand.
- Expected Clearance: remaining units divided by effective daily capacity.
- Age: elapsed calendar days from source due/movement timestamp; SLA default is 4 days.
- Screen Print remaining: planned quantity minus completed quantity. Source is explicitly manual.
- Target, capacity and actual are independent measures and must never be substituted for one another.

## Production Performance Dashboard

All `/kpis` calculations use one `KpiFilter` containing Brisbane date range, granularity, process, shift, machine and product group. Missing denominators produce `null`, displayed as `Unavailable` or `Not configured`, never zero.

| KPI | Canonical formula | Current source |
|---|---|---|
| Actual Production | accepted process output in period | `erpKpis` / `production_events` |
| Target | sum of published production plan units | `production_plans` and `production_plan_items` |
| Plan Attainment | actual / target | server KPI domain; null when target is absent or non-positive |
| Variance | actual - target | server KPI domain |
| Backlog | current non-dispatch/non-completed process demand | `productionFlowKpis` canonical stage summaries |
| Capacity | configured available process capacity | ERP KPI period aggregation and capacity profiles |
| Capacity Load | backlog demand / capacity | server KPI domain; null when capacity is absent or non-positive |
| Capacity Gap | capacity - backlog demand | server KPI domain |
| Expected Clearance | backlog / effective capacity | server KPI domain; null when capacity is unavailable |
| Orders over SLA | current orders with age greater than four calendar days | canonical DTG/UP operational-order views |
| Units / Labour Hour | accepted output / productive labour hours | ERP production events plus accepted Deputy labour |
| Orders At Risk | deterministic age, due-date and source-priority rule | canonical DTG/UP operational-order views |
| Product Mix | current SP11 and PCOR garments by configured product mapping | `machineLoad` / production mix classifier |

Machine-level actual output, runtime, efficiency, downtime and estimated lost production remain explicitly unavailable until validated event-to-machine mapping exists. Shift target, operator count and running-machine count also remain unavailable rather than inferred.
