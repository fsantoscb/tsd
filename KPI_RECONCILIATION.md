# KPI Reconciliation

Reconciliation date: 2026-09-09

Source workbook: `PCP Online.xlsm` (read-only local copy). Application source: latest completed Supabase operational snapshot.

## Formula reconciliation

| KPI | Excel formula observed | Application formula | Result |
|---|---|---|---|
| Available capacity | `SUMIFS(tblScenarios[Capacity_Prints], Scenario, active scenario, Area, selected area)` | Sum of active capacity profiles by area | Equivalent model; application intentionally has no hardcoded active scenario |
| Capacity load | `Demand_Prints / Capacity_Prints` | `demand_units / daily_capacity * 100` | Equivalent after unit display conversion; zero denominator returns `NO DATA` rather than a fabricated zero |
| Capacity gap | `Capacity_Prints - Demand_Prints` | `daily_capacity - demand_units` | Equivalent |
| Weekly capacity | `Capacity_Prints * work_days` | Daily capacity multiplied by configurable `work_days` | Equivalent |
| Weekly load | `Demand_Prints / Capacity_Prints Week` | Demand divided by weekly capacity | Equivalent; protected against zero denominator |
| Total backlog / aged orders | Sums from `AGED_ORDERS` columns | Aggregation from validated current operational views | Formula family confirmed; direct numeric comparison requires the same snapshot timestamp and scope |

## Cached Excel reference values

The workbook's active scenario contained these cached daily capacities when copied:

| Area | Daily capacity |
|---|---:|
| DTG | 3,952 |
| Underprint | 2,907 |
| Dispatch | 10,640 |

These values are evidence of the selected Excel scenario, not approved application defaults. They were not imported automatically because the specification prohibits hardcoded capacity assumptions.

## Live application checks

| Check | Result |
|---|---|
| KPI catalogue | 125 definitions |
| Active with current validated sources | 10 definitions |
| Waiting for source | 115 definitions |
| Fabricated results for waiting KPIs | 0 |
| Workbank by department | UP 3,617.575; DTG 4,563 at test time |
| Data quality | `VALID` for generated current-snapshot results |
| Target lifecycle | Create and cleanup passed |

## Reconciliation status

Formula reconciliation is complete for backlog and capacity KPIs. Numeric capacity reconciliation remains intentionally gated until official capacity profiles are configured in the application using approved resources, hours, rates, efficiency and work days. A missing profile remains `NO DATA`; the system does not substitute the cached Excel scenario.
