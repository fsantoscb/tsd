# System Rule Map

## Audit scope warning

The local repository linked to Vercel contains only ingestion/reconciliation phases 0-2. The deployed ERP pages (Production, DTG, UP, Flow, Performance, Planning, Capacity, Reports, Maintenance) are absent. Rules marked `UNVERIFIABLE` require recovery of the deployed source before approval.

| Rule ID | Rule | Business definition | Authority | Database | Backend/source | Frontend/pages | Tests | Conflict | Canonical recommendation |
|---|---|---|---|---|---|---|---|---|---|
| RULE-001 | DTG Picking | Queue `SP11` | Approved audit request | Raw workbank only | `ATOC + SP11` filter | Deployed pages absent | None | Task restriction is not in approved definition | Central stage mapping table/function |
| RULE-002 | DTG Printing | Queue `PCOR` | Approved audit request | Raw workbank/audit | `PCOR + PCOR`; audit uses broad `QUEUE or ISIS_TASK` | Absent | Mapping test partial | Source query can include unrelated PCOR events | Canonical event classifier with exact precedence |
| RULE-003 | DTG Putwall | `PWL1` | Approved audit request | Stock omits zone | Stock query filters zone but discards it | Absent | None | Stage cannot be re-audited after ingestion | Persist zone and derive stage server-side |
| RULE-004 | DTG Dispatch | `DTGMOVE` | Approved audit request | No canonical stage field | Not explicitly extracted | Absent | None | Flow endpoint is missing | Exact DTGMOVE classifier |
| RULE-005 | UP Picking | Stock `UNDERPRINT` | Approved audit request | Current stock | Location filter | Absent | Partial mapping | Mixed with PWL1 in same source table | Typed canonical stage view |
| RULE-006 | UP Printing | Name/location ending `UP` | Approved audit request | No derived stage | Audit heuristic only | Absent | None | Approved rule not implemented | Exact normalized suffix classifier, excluding UPMOVE |
| RULE-007 | UP Dispatch | `UPMOVE` | Approved audit request | No derived stage | Not explicit | Absent | None | Missing | Exact UPMOVE classifier |
| RULE-008 | Screen Print flow | Manual TODO -> IN PRODUCTION -> COMPLETED | Approved audit request | No tables/statuses | None | Absent | None | Not represented | Separate manual workflow, never inferred from Oracle |
| RULE-009 | Production units | Physical garments; retain qty/weight separately | DECISIONS.md plus business request | `production_units` numeric | Stock/audit use weight then qty; workbank uses qty except CARTON | Source explorer | Mapping tests partial | Two formulas exist | Versioned unit policy; garments must use approved quantity field |
| RULE-010 | Snapshot authority | Only latest completed batch | Architecture decision | `v_latest_completed_batch` | Server queries current views | Overview/source pages | Reconciliation helper only | Correct concept, weak integrity constraints | Organization-scoped completed-batch function/view |
| RULE-011 | Audit deduplication | Each physical source event once | Data integrity | Unique audit ID and raw hash | Hash omits qty, weight, product, user and zones | None | Hash test absent | Distinct events can collide | Hash complete immutable source identity/payload |
| RULE-012 | External identifiers | Always strings | DECISIONS.md | Text columns | Mapping calls `String` | Source explorer | Large pack ID test | Compliant in available code | Keep branded ID types end-to-end |
| RULE-013 | Source priority | Preserve Oracle priority | Audit request | `source_priority` | Mapped directly | Source explorer | None | Planner/effective priority absent | Separate source/planner/effective fields |
| RULE-014 | Status vocabulary | Canonical lower-case enum | Shared schema | No DB production-status enum | Enum is unused | Absent | None | Source statuses and canonical statuses are disconnected | DB enum/mapping plus shared generated types |
| RULE-015 | Timezone | Brisbane business time; UTC/timestamptz storage | DECISIONS.md/audit request | timestamptz | `SYNC_TIMEZONE` is unused; JS parses Oracle dates | Formatting uses Brisbane | None | Source timezone attribution is nondeterministic | Parse source wall time explicitly in Brisbane, store UTC |
| RULE-016 | Freshness | Completed snapshot older than 5 minutes is stale | Current implementation only | completed_at | Fixed 300 seconds | Badge | One boundary test | Threshold not configurable/spec-approved | Operational configuration and heartbeat/batch state |
| RULE-017 | Authorization | Role and organization isolation | Security requirement | RLS enabled, no user policies | Service role after optional email guard | Admin pages | Basic password tests only | Any user is admin if ADMIN_EMAIL missing | Membership/role tables and org-scoped server queries |
| RULE-018 | Capacity | Resources x hours x rate x efficiency | Approved audit request | Absent | Absent | Deployed page absent | None | `UNVERIFIABLE` | One configuration table and domain function |
| RULE-019 | KPI definitions | One formula/source/filter contract per KPI | Approved audit request | Absent | Absent | Deployed KPI pages absent | None | `UNVERIFIABLE` | KPI registry plus canonical SQL/domain queries |
| RULE-020 | Age/SLA | SLA <= 4 days unless configured | Approved audit request | Absent | Absent | Deployed pages absent | None | `UNVERIFIABLE` | Explicit timestamp basis and Brisbane calendar rule |
| RULE-021 | Product mix | Approved product groups; volume is SUM quantity | Approved business rules | Raw descriptions only | No classifier | Deployed page absent | None | `UNVERIFIABLE` | Versioned product classification table with OTHER fallback |

## Canonical status map proposal

| Canonical status | Accepted presentation aliases | Meaning |
|---|---|---|
| `unplanned` | Unplanned | No approved plan |
| `planned` | Planned | Scheduled but not released |
| `ready` | Ready, Ready to Lift | Preconditions complete |
| `in_progress` | In Progress, On Process, Production | Work has started and remains incomplete |
| `blocked` | Blocked, Hold | Work cannot proceed |
| `waiting` | Waiting, Awaiting Picking | Waiting for predecessor/resource |
| `completed` | Completed, Complete | Terminal successful state |
| `cancelled` | Cancelled, Canceled | Terminal cancelled state |

