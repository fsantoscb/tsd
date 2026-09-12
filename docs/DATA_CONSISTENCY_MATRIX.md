# Data Consistency Matrix

`UNVERIFIABLE` means the deployed page exists but its source is absent from this repository.

| Information | Dashboard | Operational page | Planning/Capacity | Reports | Canonical source | Consistent? |
|---|---|---|---|---|---|---|
| Current orders | Latest completed snapshot count | Source explorer view | Absent | Absent | `v_current_orders` | Partial |
| DTG picking backlog | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Should be SP11 classified rows/units | Unknown |
| DTG printing backlog | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Should be PCOR classified rows/units | Unknown |
| DTG putwall | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Stock zone PWL1 | Unknown; zone discarded |
| DTG dispatch | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | DTGMOVE events | No implementation |
| UP picking | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Stock UNDERPRINT | Unknown |
| UP printed | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Name + UP event | No exact implementation |
| UP dispatched | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UPMOVE event | No implementation |
| Production units | Snapshot counts rows, not units | Raw `production_units` | UNVERIFIABLE | UNVERIFIABLE | Not yet approved | No |
| Client | Raw customer name | Source explorer uses customer name | UNVERIFIABLE | UNVERIFIABLE | Business UI expects ship-to under Client label | No evidence of canonical use |
| Due date | Not shown | Source order due date | UNVERIFIABLE | UNVERIFIABLE | Oracle order due date | Partial |
| Priority | Not shown | Source priority | UNVERIFIABLE | UNVERIFIABLE | Source + planner override fields | Planner/effective missing |
| Days old/SLA | Absent | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Explicit approved timestamp, Brisbane | Unknown |
| Capacity | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Configured resources x hours x rate x efficiency | Unknown |
| Actual production | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Canonical accepted production events | Unknown |
| Target | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | Approved plan/configuration | Unknown |
| Product mix | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | UNVERIFIABLE | SUM quantity after canonical classification | Unknown |
| Data freshness | Batch completed_at | Batch completed_at | UNVERIFIABLE | UNVERIFIABLE | Batch + heartbeat + source timestamps | Partial |
| Organization | First/only record implicitly | Service-role unscoped queries | Absent | Absent | Auth membership organization | No |

