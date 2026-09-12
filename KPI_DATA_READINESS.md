# KPI Data Readiness

Assessment date: 2026-09-08

This document is the mandatory gate before Phase 8 calculation work. `ACTIVE_FROM_EXISTING_DATA` means the current Oracle snapshot/application model can support a reproducible calculation. It does not activate the KPI automatically. Conservative classification prevents misleading values.

| KPI | Readiness | Basis / missing requirement |
|---|---|---|
| PRODUCTION_ACTUAL | REQUIRES_NEW_MODULE | Production-event history must accumulate and be semantically validated. |
| PRODUCTION_TARGET | REQUIRES_NEW_MODULE | Production planning and target configuration. |
| TARGET_ATTAINMENT | REQUIRES_NEW_MODULE | Valid target plus production actual. |
| UNITS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | Reliable operating/labour time. |
| PRODUCTION_BY_MACHINE | REQUIRES_NEW_DATA_SOURCE | Machine attribution. |
| PRODUCTION_BY_OPERATOR | REQUIRES_NEW_DATA_SOURCE | Operator attribution. |
| OUTPUT_BY_LINE | REQUIRES_NEW_DATA_SOURCE | Production-line attribution. |
| PRODUCTION_EFFICIENCY | REQUIRES_NEW_DATA_SOURCE | Standard time and actual time. |
| CAPACITY_UTILISATION | REQUIRES_NEW_MODULE | Capacity profiles and actual output. |
| CYCLE_TIME | REQUIRES_NEW_DATA_SOURCE | Start/finish production events. |
| THROUGHPUT | REQUIRES_NEW_MODULE | Validated historical completion events. |
| TOTAL_BACKLOG | ACTIVE_FROM_EXISTING_DATA | Current workbank production units. |
| BACKLOG_ORDERS | ACTIVE_FROM_EXISTING_DATA | Current workbank distinct orders. |
| BACKLOG_DAYS | ACTIVE_FROM_EXISTING_DATA | Workbank and due dates. |
| WIP | ACTIVE_FROM_EXISTING_DATA | Current staged workbank. |
| WORKBANK_BY_DEPARTMENT | ACTIVE_FROM_EXISTING_DATA | Current stage/location mapping. |
| PLANNED_VS_ACTUAL | REQUIRES_NEW_MODULE | Production plans and actual history. |
| SCHEDULE_ADHERENCE | REQUIRES_NEW_MODULE | Published schedule and completion history. |
| LATE_ORDERS | ACTIVE_FROM_EXISTING_DATA | Current workbank and due dates. |
| LATE_ORDER_PERCENTAGE | ACTIVE_FROM_EXISTING_DATA | Late and total current orders. |
| BACKLOG_AGING | ACTIVE_FROM_EXISTING_DATA | Workbank due dates; buckets configurable. |
| AVAILABLE_CAPACITY | ACTIVE_FROM_EXISTING_DATA | Capacity profiles and shifts are implemented; a configured active profile is required. |
| CAPACITY_LOAD | ACTIVE_FROM_EXISTING_DATA | Central calculation is implemented; returns no value when capacity is absent or zero. |
| CAPACITY_GAP | ACTIVE_FROM_EXISTING_DATA | Central calculation is implemented from validated demand and configured capacity. |
| RELATIVE_LEAD | ACTIVE_FROM_EXISTING_DATA | Received/due dates and backlog. |
| AGED_ORDERS | ACTIVE_FROM_EXISTING_DATA | Current stage engine and due dates. |
| PLAN_ATTAINMENT | REQUIRES_NEW_MODULE | Published plan and actual history. |
| ON_TIME_PLAN_COMPLETION | REQUIRES_NEW_MODULE | Plan completion events. |
| LEAD_TIME | REQUIRES_NEW_DATA_SOURCE | Reliable dispatch/completion timestamp. |
| SLA_COMPLIANCE | REQUIRES_NEW_MODULE | Configurable SLA and completion outcome. |
| OTIF | REQUIRES_NEW_DATA_SOURCE | Dispatch delivery completeness/timeliness. |
| ORDERS_DISPATCHED | REQUIRES_NEW_DATA_SOURCE | Authoritative dispatch event. |
| ORDERS_PENDING_DISPATCH | REQUIRES_NEW_DATA_SOURCE | Authoritative dispatch state. |
| REWORK_PERCENTAGE | REQUIRES_NEW_MODULE | Quality-event capture. |
| REJECT_PERCENTAGE | REQUIRES_NEW_MODULE | Quality-event capture. |
| FIRST_PASS_YIELD | REQUIRES_NEW_MODULE | First-pass quality outcomes. |
| DEFECTS_PER_1000 | REQUIRES_NEW_MODULE | Defect events. |
| CUSTOMER_COMPLAINTS | REQUIRES_NEW_DATA_SOURCE | CRM/quality complaints. |
| CUSTOMER_RETURN_RATE | REQUIRES_NEW_DATA_SOURCE | Returns data. |
| COST_OF_POOR_QUALITY | REQUIRES_NEW_DATA_SOURCE | Authoritative quality costs. |
| TOP_DEFECT_REASONS | REQUIRES_NEW_MODULE | Coded defect reasons. |
| TOTAL_DOWNTIME | REQUIRES_NEW_DATA_SOURCE | Maintenance/equipment events. |
| DOWNTIME_PERCENTAGE | REQUIRES_NEW_DATA_SOURCE | Downtime and planned production time. |
| AVAILABILITY | REQUIRES_NEW_DATA_SOURCE | Planned time and downtime. |
| PERFORMANCE_RATE | REQUIRES_NEW_DATA_SOURCE | Machine runtime and theoretical rate. |
| OEE | REQUIRES_NEW_DATA_SOURCE | Valid availability, performance and quality. |
| MTBF | REQUIRES_NEW_DATA_SOURCE | Maintenance failure history. |
| MTTR | REQUIRES_NEW_DATA_SOURCE | Maintenance repair history. |
| BREAKDOWN_COUNT | REQUIRES_NEW_DATA_SOURCE | Maintenance events. |
| MICRO_STOP_COUNT | REQUIRES_NEW_DATA_SOURCE | Machine stop telemetry. |
| SETUP_TIME | REQUIRES_NEW_DATA_SOURCE | Setup start/finish events. |
| PM_COMPLIANCE | REQUIRES_NEW_DATA_SOURCE | TSD Maintenance Manager integration. |
| PM_OVERDUE | REQUIRES_NEW_DATA_SOURCE | TSD Maintenance Manager integration. |
| HEADCOUNT | REQUIRES_NEW_DATA_SOURCE | Workforce system. |
| LABOUR_HOURS | REQUIRES_NEW_DATA_SOURCE | Time attendance. |
| LABOUR_HOURS_PER_UNIT | REQUIRES_NEW_DATA_SOURCE | Labour hours plus actual output. |
| UNITS_PER_LABOUR_HOUR | REQUIRES_NEW_DATA_SOURCE | Labour hours plus actual output. |
| ABSENTEEISM | REQUIRES_NEW_DATA_SOURCE | Attendance and scheduled hours. |
| OVERTIME_HOURS | REQUIRES_NEW_DATA_SOURCE | Time attendance. |
| OVERTIME_PERCENTAGE | REQUIRES_NEW_DATA_SOURCE | Overtime and total labour hours. |
| LABOUR_UTILISATION | REQUIRES_NEW_DATA_SOURCE | Paid and productive time. |
| TRAINING_COMPLIANCE | REQUIRES_NEW_DATA_SOURCE | Training records. |
| MULTISKILLING_INDEX | REQUIRES_NEW_DATA_SOURCE | Skills matrix. |
| LABOUR_COST | REQUIRES_NEW_DATA_SOURCE | Authoritative payroll/finance data. |
| LABOUR_COST_PER_UNIT | REQUIRES_NEW_DATA_SOURCE | Labour cost plus actual output. |
| MANUFACTURING_COST_PER_UNIT | REQUIRES_NEW_DATA_SOURCE | Authoritative manufacturing cost. |
| MATERIAL_COST_PER_UNIT | REQUIRES_NEW_DATA_SOURCE | Authoritative material valuation. |
| REWORK_COST | REQUIRES_NEW_DATA_SOURCE | Quality events and authoritative cost. |
| SCRAP_COST | REQUIRES_NEW_DATA_SOURCE | Scrap events and authoritative cost. |
| MAINTENANCE_COST | REQUIRES_NEW_DATA_SOURCE | Maintenance/finance integration. |
| COST_VS_BUDGET | REQUIRES_NEW_DATA_SOURCE | Finance budget and actuals. |
| CURRENT_STOCK | ACTIVE_FROM_EXISTING_DATA | Current Oracle/WMS stock snapshot. |
| DAYS_OF_STOCK | REQUIRES_NEW_DATA_SOURCE | Historical consumption rate. |
| CONSUMPTION_PER_1000_UNITS | REQUIRES_NEW_DATA_SOURCE | Consumption events and actual output. |
| STOCKOUT_COUNT | REQUIRES_NEW_DATA_SOURCE | Historical stockout events. |
| CRITICAL_STOCK_ITEMS | REQUIRES_NEW_MODULE | Configurable critical levels. |
| INVENTORY_ACCURACY | REQUIRES_NEW_DATA_SOURCE | Physical count adjustments. |
| OBSOLETE_STOCK | REQUIRES_NEW_DATA_SOURCE | Movement/age and obsolescence policy. |
| SUPPLIER_LEAD_TIME | REQUIRES_NEW_DATA_SOURCE | Purchase order receipt history. |
| SAFETY_INCIDENTS | REQUIRES_NEW_MODULE | Safety-event capture. |
| NEAR_MISSES | REQUIRES_NEW_MODULE | Safety-event capture. |
| LOST_TIME_INJURIES | REQUIRES_NEW_MODULE | Safety-event capture. |
| OVERDUE_SAFETY_ACTIONS | REQUIRES_NEW_MODULE | Safety actions. |
| TOP_OPERATIONAL_PROBLEMS | REQUIRES_NEW_MODULE | Structured problem capture. |
| ACTION_COMPLETION_PERCENTAGE | REQUIRES_NEW_MODULE | Operational actions. |
| OPEN_ACTION_AGING | REQUIRES_NEW_MODULE | Operational actions. |
| IMPROVEMENT_SAVINGS | REQUIRES_NEW_DATA_SOURCE | Approved improvement and finance data. |
| DTG_PRINTS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | DTG print events and runtime. |
| DTG_GARMENTS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | Garment completion and runtime. |
| DTG_PRINTS_BY_MACHINE | REQUIRES_NEW_DATA_SOURCE | Machine-attributed print events. |
| DTG1_VS_DTG2_PERFORMANCE | REQUIRES_NEW_DATA_SOURCE | Historical machine configuration/events. |
| DTG_PRINTHEAD_DOWNTIME | REQUIRES_NEW_DATA_SOURCE | Machine/maintenance events. |
| DTG_PRINTHEAD_FAILURES | REQUIRES_NEW_DATA_SOURCE | Failure events. |
| DTG_NOZZLE_FAILURES | REQUIRES_NEW_DATA_SOURCE | Failure events. |
| DTG_INK_CONSUMPTION_PER_1000_PRINTS | REQUIRES_NEW_DATA_SOURCE | Historical ink consumption and prints. |
| DTG_WHITE_INK_CONSUMPTION | REQUIRES_NEW_DATA_SOURCE | Consumable issue/usage events. |
| DTG_CMYK_INK_CONSUMPTION | REQUIRES_NEW_DATA_SOURCE | Consumable issue/usage events. |
| DTG_CP600_CONSUMPTION | REQUIRES_NEW_DATA_SOURCE | Consumable issue/usage events. |
| DTG_PRETREATMENT_CONSUMPTION_PER_1000 | REQUIRES_NEW_DATA_SOURCE | Pretreatment events and output. |
| DTG_INK_COST_PER_GARMENT | REQUIRES_NEW_DATA_SOURCE | Authoritative ink cost and usage. |
| DTG_PRINT_REJECT_PERCENTAGE | REQUIRES_NEW_MODULE | DTG quality events. |
| DTG_REPRINT_PERCENTAGE | REQUIRES_NEW_MODULE | Reprint events. |
| UP_UNITS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | UP output events and runtime. |
| UP_OUTPUT_BY_STATION | REQUIRES_NEW_DATA_SOURCE | Station attribution. |
| UP_OUTPUT_BY_OPERATOR | REQUIRES_NEW_DATA_SOURCE | Operator attribution. |
| UP_STATION_UTILISATION | REQUIRES_NEW_DATA_SOURCE | Station availability/runtime. |
| UP_BACKLOG | ACTIVE_FROM_EXISTING_DATA | Current PWL1/UP workbank. |
| DTG_TO_UP_WAIT_TIME | REQUIRES_NEW_DATA_SOURCE | Reliable stage transition history. |
| TUNNEL_UTILISATION | REQUIRES_NEW_DATA_SOURCE | Tunnel runtime/configuration history. |
| TUNNEL_DOWNTIME | REQUIRES_NEW_DATA_SOURCE | Tunnel downtime events. |
| TUNNEL_TEMPERATURE_VARIANCE | REQUIRES_NEW_DATA_SOURCE | Temperature telemetry. |
| TUNNEL_BELT_SPEED | REQUIRES_NEW_DATA_SOURCE | Belt-speed telemetry. |
| TUNNEL_BURNER_FAILURES | REQUIRES_NEW_DATA_SOURCE | Failure events. |
| UV_UNITS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | UV output and runtime. |
| UV_OUTPUT_BY_MACHINE | REQUIRES_NEW_DATA_SOURCE | UV machine events. |
| UV_MATERIAL_WASTE_PERCENTAGE | REQUIRES_NEW_MODULE | UV material/quality events. |
| UV_SETUP_TIME | REQUIRES_NEW_DATA_SOURCE | UV setup events. |
| UV_REWORK_PERCENTAGE | REQUIRES_NEW_MODULE | UV quality events. |
| UV_MACHINE_UTILISATION | REQUIRES_NEW_DATA_SOURCE | UV runtime/capacity. |
| SCREEN_PRINTS_PER_HOUR | REQUIRES_NEW_DATA_SOURCE | Screen-print output/runtime. |
| SCREEN_SETUP_TIME | REQUIRES_NEW_DATA_SOURCE | Setup events. |
| SCREEN_CHANGEOVER_TIME | REQUIRES_NEW_DATA_SOURCE | Changeover events. |
| SCREEN_REJECT_PERCENTAGE | REQUIRES_NEW_MODULE | Screen-print quality events. |
| SCREEN_COLOUR_CHANGES | REQUIRES_NEW_DATA_SOURCE | Colour-change events. |
| SCREEN_LABOUR_HOURS_PER_ORDER | REQUIRES_NEW_DATA_SOURCE | Order-attributed labour time. |

## Existing-data candidates

The current trustworthy first tranche is: TOTAL_BACKLOG, BACKLOG_ORDERS, BACKLOG_DAYS, WIP, WORKBANK_BY_DEPARTMENT, LATE_ORDERS, LATE_ORDER_PERCENTAGE, BACKLOG_AGING, RELATIVE_LEAD, AGED_ORDERS, CURRENT_STOCK and UP_BACKLOG. Each still requires formula definition, tolerance, tests and Excel reconciliation before activation.
