# MO Architecture Impact Matrix

Authoritative rule: ONE SO + ONE ROUTING = ONE MO. DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.

| Module | Dependency on MO | Impact | Conflict | Required Future Change | Blocking Phase F? |
|---|---|---|---|---|---|
| Dashboard | Legacy source aggregates | UNAFFECTED | No canonical MO dependency today | Adopt MO facts only after parity | No |
| Flow | Legacy source stages plus parallel canonical MO view | COMPATIBLE | Canonical totals can aggregate separate MOs; drilldown is not MO-aware | Drill down stage to MO, SO and lines | Yes, before canonical cutover |
| KPIs | Production events and legacy workbanks | UNAFFECTED | No new MO joins currently | Define one fact grain and MO drilldown before migration | No today; yes for KPI KPI migration |
| Planning | production_orders keyed and selected by order_no | REQUIRES UPDATE | Assumes one Production Order equals one Sales Order | Plan MO IDs while preserving SO grouping | Yes for Planning migration |
| Capacity Capacity | Legacy v_production_planning demand | COMPATIBLE | Can sum separate MOs, but current source is legacy SO demand | Aggregate MO demand by operation/work center/date without merging identities | Yes for Capacity migration |
| Oracle Validation | Evidence resolved by SO plus canonical operation | BROKEN | Shared operations can cause one SO event to affect multiple same-SO MOs | Add stable source-line/product/routing discriminator and deterministic allocation | Yes |
| Routing Product Mix | manufacturing_order_lines view | COMPATIBLE | Planned composition is preserved; actual composition is not rolled up | Add governed actual line attribution | Yes for actual-mix reporting |
| Orders At Risk | Legacy operational-order views | UNAFFECTED | Still SO-grain, not MO-grain | Define MO risk with SO rollup | No today |
| Aged Orders | Legacy Oracle order views | UNAFFECTED | Still SO-grain | Preserve SO page and add MO drilldown when migrated | No today |
| Ready To Lift | Stock/WMS source | UNAFFECTED | WMS remains authority | Link stock result to MO only with deterministic evidence | No today |
| DTG Workbank | Oracle/WMS source | UNAFFECTED | No MO dependency | Add MO link after source-line mapping | No today |
| UP Workbank | Oracle/WMS source | UNAFFECTED | No MO dependency | Add MO link after source-line mapping | No today |
| Reports | Mixed legacy sources | UNKNOWN | No governed MO reporting grain exists | Inventory reports and define fact grain before migration | Yes for report migration |
| Production Order list | production_orders header | REQUIRES UPDATE | Shows one header product and searches order_no only | Use MO terminology; show MO and SO; support multiproduct summary | Yes |
| Production Order detail | header product, operations, evidence | BROKEN | Valid multiproduct MO appears Unmapped and has no lines | Load manufacturing_order_lines and provide MO to SO to lines/products drilldown | Yes |
| Sales Order detail | Legacy source order detail | REQUIRES UPDATE | Does not list multiple MOs under one SO | Add SO to MO relationship view | Yes |
| Routing deviations | MO operation plus SO evidence | REQUIRES UPDATE | Same-SO/shared-operation attribution is ambiguous | Do not resolve until evidence identifies the MO | Yes |

## Aggregation safety

- Flow canonical aggregation counts each MO once at its current operation and does not join MO lines or all operation rows.
- Capacity can add MO1 DTG 850 and MO2 DTG 400 as 1,250 while retaining two MO identities.
- KPI migration must select exactly one fact grain. SO headers, MO headers, MO lines and MO operations must never be summed together.
- Product Mix planned quantity is safely grouped from MO lines. Actual product mix is unavailable until actual quantities are attributed at line level.

