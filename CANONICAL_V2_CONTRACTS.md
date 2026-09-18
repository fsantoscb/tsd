# Canonical V2 Frozen Contracts

## Authority and scope

This contract was harvested from validated tests, current application code, final E5/E6 SQL functions and published module reports. Historical migrations are provenance, not architecture. Oracle remains read-only.

## Implementation source map

| Canonical feature | Source worktree | Principal source | Validating tests | Status |
| --- | --- | --- | --- | --- |
| Product/Routing Master | `C:\Projects\tsd` | Phase A-E SQL; `docs/PRODUCT_MASTER.md` | routing phase tests | CONTRACT_FOUND |
| MO grouping | `C:\Projects\tsd` | `202609130012_mo_grouping_correction.sql` and hardening | `mo_grouping_correction.sql` | CONTRACT_FOUND |
| Release authority/lifecycle | `C:\Projects\tsd` | final E5/E6 release functions 021, 023, 039, 041, 042 | `release_lifecycle.sql`, `routing_phase_e6_5.sql`, `routing_phase_e6_8.sql`, `routing_phase_e6_8_1.sql` | CONTRACT_FOUND |
| Release Queue | `C:\Projects\tsd-dtg-release` | published service and 170001/170002 views | `release-queue-rules.test.ts` | CONTRACT_FOUND |
| Machine Load / Not Approved | `C:\Projects\tsd-dtg-release` | published service, rules and 170003 view | `machine-load.test.ts` | CONTRACT_FOUND |
| Product Mix | `C:\Projects\tsd-dtg-release` | `product-mix-rules.ts` | product-mix tests | CONTRACT_FOUND |
| Performance/KPI | `C:\Projects\tsd-dtg-release` | production events, KPI services, KPI definitions | KPI/performance tests | CONTRACT_FOUND |
| Maintenance | `C:\Projects\tsd-dtg-release` | maintenance services/actions | maintenance/operator tests | CONTRACT_DERIVABLE_FROM_VALIDATED_TESTS |

## Release authority

- Authority: Oracle `IS_ORDER_LINE.RELEASED` ingested without writes to Oracle.
- Grain: organization + source system + Sales Order + Sales Order Line.
- Source key: `source_order_no` + Oracle line number (`source_line_id`).
- `Y`: line is source-confirmed released and may enter eligible Production Demand.
- `N`: line is explicitly unreleased; existing mapped demand is revoked according to lifecycle protection.
- Other/null: `UNKNOWN_RELEASE_STATUS`; never treated as released.
- Partial release: an order is `PARTIALLY_RELEASED` when it contains both Y and N lines. Quantities remain line-level; only Y lines contribute.
- Snapshot: each COMPLETE ingestion run is authoritative for the lines included in that snapshot. Distinct transitions use distinct ingestion run IDs.
- Provenance retained: raw release value, source line status, quantity processed, weight, stock reservation, source timestamp, sync batch/run.
- Sync is idempotent at organization + source system + order + line; a rerun must not duplicate line identity or lifecycle events.

## Release lifecycle

| Transition | Contract |
| --- | --- |
| N to Y | Create/activate one canonical demand when product, process, routing and eligibility resolve. Create/reuse one MO line. |
| Y to N | Mark mapped demand `CANCELLED`/inactive; retain demand, mapping, MO line and audits. Recompute MO header from canonical active mappings. |
| Y to N to Y, PLANNED | Reactivate the same demand and same MO line; reuse compatible PLANNED MO; restore canonical quantity. No inserts of duplicate demand or MO line. |
| Y to N to Y, IN_PROGRESS | Do not rewrite execution; keep demand inactive and create one controlled reconciliation event. |
| Y to N to Y, COMPLETED | Do not reopen history; keep demand inactive and create one controlled reconciliation event. |
| Y to N to Y, CANCELLED MO | Do not reopen MO automatically. |
| Eligibility blocked | Demand remains inactive; controlled exception/audit only. |

Lifecycle events are immutable and unique by demand + event type + snapshot run. Re-executing the same snapshot creates zero additional events or quantities. The validated repeated chain Y-N-Y-N-Y preserves identities and produces exactly two revocation and two reactivation events.

## Production Demand

- Table: `production_demand_lines`.
- Grain/key: one source Sales Order Line plus canonical Routing identity within one organization/source system.
- Required links for `RESOLVED`: Product, Routing and Routing Revision.
- Relevant statuses: `READY`, `GROUPED`, `CANCELLED`; unresolved records remain non-contributing with explicit resolution status.
- Quantity is source line production quantity, never an order-level inferred quantity.
- Active contribution: only resolved, released, eligible demand in active canonical status.
- Provenance: source system/order/line/product code, source snapshot/run, resolution method/status and timestamps.
- No duplicate active demand: enforced by the source-line/routing natural key and reconciliation functions updating/reusing existing identity rather than inserting on rerelease.

## Active demand mapping

- Canonical equivalent: `manufacturing_order_lines` linking exactly one `production_demand_line_id` to one MO.
- Grain: one Production Demand line per MO line.
- Uniqueness: a demand line cannot map to multiple MO lines; Sales Order and Routing boundaries are trigger-enforced.
- Creation source: controlled MO creation from resolved eligible demand.
- Revocation: mapping remains for provenance but contributes zero when demand is cancelled/inactive.
- Rerelease: same mapping and MO line are reused only when lifecycle compatibility permits.

## Manufacturing Orders

- Header: `production_orders`; line: `manufacturing_order_lines`; immutable operation snapshot: production order operations.
- Authoritative grouping: **one Sales Order + one Routing = one Manufacturing Order**. Different Sales Orders never merge.
- Product mix may contain multiple products/lines while preserving every demand and Sales Order Line identity.
- Statuses include `PLANNED`, `READY`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`.
- Creation occurs only from released, eligible, fully resolved demand.
- PLANNED compatible MOs may be reused. IN_PROGRESS/COMPLETED/CANCELLED are protected from silent lifecycle rewrite.
- Routing revision and operations are snapshotted at MO creation; later Routing Master changes do not mutate historical MOs.

## Canonical MO quantity

| Item | Frozen contract |
| --- | --- |
| Source | MO lines joined to their Production Demand lines |
| Formula | sum of mapped line quantity where the demand remains active/canonical |
| Status filter | demand not `CANCELLED`, release remains active, and no effective revocation excludes the mapping |
| Inactive demand | contributes zero |
| Mixed MO | only the revoked contribution is removed/restored |
| Execution edge | actual execution is never silently reduced/reopened |
| Header | `production_orders.planned_quantity` is derived/cache and is recomputed with `canonical_mo_planned_quantity(mo_id)` |

The header is not an independent quantity authority.

## Product Mapping

- Canonical Product is the finished product identity; blank/garment material is a separate identity and role.
- `BLANK PRODUCT != FINISHED PRODUCT`.
- Source mapping natural key: organization + source system + exact source product code.
- Mapping records retain method/confidence/provenance and active state.
- Automatic mapping requires exact deterministic evidence with zero conflicts. Fuzzy/majority inference is forbidden.
- Unresolved or ambiguous source products stay visible and non-contributing.

## Routing and process resolution

Keep distinct: Product, Product Mapping, Operational Code, Manufacturing Process, Routing and Operational Stage.

Resolution precedence:

1. authoritative source operational/process evidence;
2. exact source task/operational-code mapping with optional context;
3. exact finished Product + canonical Process assignment;
4. released Routing Revision;
5. explicit override where audited;
6. unresolved.

Blank SKU alone never determines Routing. Unknown evidence never falls through to a guessed routing.

Validated operation groups include:

| Source code | Canonical interpretation | Scope |
| --- | --- | --- |
| `SP11` | DTG / PICKING | supported |
| `PAK7` | SCREEN_PRINT / PICKING | supported, user-confirmed |
| `PAK9` | EYEWEAR / PICKING | process not yet supported |
| `DTGMOVE`, `CONSBELT` | dispatch consolidation | non-production / not applicable |
| `CONSHOLD` | dispatch consolidation hold | non-production / not applicable |
| `UNRELEASED` | unreleased state | not applicable |
| `NOT APPROVED` | not-approved state | not applicable |

Other PAK mappings must be loaded only from the recovered operational-code mapping dataset; absence is not a fallback permission.

## Release Queue

- Candidate grain: one current Oracle Sales Order Line; operational summaries may aggregate by Sales Order while retaining line drilldown.
- Release authority is line-level Y/N/unknown.
- Zero/non-positive production demand is `NO_PRODUCTION_DEMAND`/not applicable, not releasable output.
- States exposed by the published resolver: `ELIGIBLE`, `NOT_APPROVED`, `BLOCKED`, `FUTURE_DUE`, `UNKNOWN`.
- Precedence: invalid/unknown evidence remains `UNKNOWN`; hard blockers produce `BLOCKED`; Not Approved remains separately visible; future due remains future; only otherwise valid candidates are eligible.
- Blockers are preserved as a collection, not collapsed. Validated blockers include route blocked/`ROUTE_ID_NO`, `STOP_SHIP`, `CUSTOM_EMB`, Not Approved, no production demand and invalid/unknown source state.
- Quantity is process/source-line quantity. Product + Client presentation does not merge source-line identity.

## Machine Load

- Active load uses active approved/released workbank evidence only.
- DTG waiting for pick: SP11 physical source quantity with forecast prints.
- DTG ready to print: PCOR physical source quantity with confirmed prints.
- Underprint uses its deterministic stock/workbank sources.
- Open load/backlog are current active process demand; stages representing the same physical units are not added together.
- Aging derives from source due/movement timestamps.
- Capacity comes from configured capacity profiles/rules; utilisation = demand/capacity; null when capacity is unavailable or non-positive.
- Machine/process assignment requires deterministic evidence.
- `NOT_APPROVED_INFORMATIONAL` is opt-in, line-grain, read-only and isolated. It never changes active load, backlog, capacity, utilisation, productivity, targets, scheduling, Production Demand or MO creation.

## Product Mix

- Family classification reuses exact product-type extraction/classification; unknown remains `Unclassified / Other`.
- `WAITING_FOR_PICKING`: active SP11 rows, physical `source_qty`.
- `READY_TO_PRINT`: active PCOR rows, physical `source_qty`.
- `NOT_APPROVED_INFORMATIONAL`: Release Queue rows, `process_quantity`, displayed only when enabled.
- Active SO + SKU suppresses matching potential presentation to prevent overlap/double display.
- Drilldown retains record key, SO, line, SKU/product, state, due date and quantity semantics.
- Physical quantity and process quantity remain distinct unless explicitly proven equivalent.

## Production and Performance

- Production event grain: accepted event identity/source record + operational date + shift + process/area + metric; source provenance is retained.
- Current output is accepted `production_events`; Oracle audit-derived events and manual Screen Print events remain distinguishable.
- Shifts are Brisbane-time configured templates/rules, not inferred from display time.
- Targets, capacity and actual are independent. Missing denominator/configuration yields null/unavailable, never zero.
- Validated formulas: plan attainment = actual/target; variance = actual-target; capacity load = backlog/capacity; gap = capacity-backlog; clearance = backlog/effective capacity; units per labour hour = accepted output/productive Deputy labour hours.
- Machine-level performance remains unavailable where validated event-to-machine mapping does not exist. ML-MIX3A is outside this frozen contract.

## Maintenance minimum contract

- Identity/access: maintenance members and roles by organization.
- Assets: category, prefixes, components, parent/host relationships, operational role, active/retired state and movable installations.
- Work Orders: type/request type, priority, status, asset, requester, assignment, timestamps, description/cause/resolution, no-parts confirmation and immutable history/comments.
- Operator Fix and corrective-now create auditable work/downtime records; scheduled corrective retains planned timing.
- Preventive plans own frequency, next due, estimated minutes and ordered checklist tasks; due generation is idempotent.
- Parts usage posts inventory transactions tied to part/location/work order with quantity and cost snapshots.
- Downtime/timers retain start/end and derived minutes; failure/downtime flags are explicit.
- Closure requires lifecycle transition rules, required checklist completion, resolution data and parts/no-parts evidence where configured.
- Attachments live in private storage and retain organization/work-order references.

## Staff, shift and configuration classification

| Configuration | Class |
| --- | --- |
| organization, memberships/roles | MUST_SEED |
| Product Families/Types/Products and exact source mappings | MUST_SEED |
| operations, work centres, resources, process definitions | MUST_SEED |
| Routings, released revisions, operations and product assignments | MUST_SEED |
| source task/operational-code mappings | MUST_SEED |
| shifts and shift rules | MUST_SEED |
| capacity profiles, resources, targets and staffing layouts | MUST_SEED |
| maintenance asset/config master and PM cycles | MUST_SEED |
| source snapshots, demand, MOs and calculated KPIs | CAN_REBUILD |
| historical sync runs and caches | OPTIONAL |
| active plans, maintenance history and attachments | migration decision required; see gaps |

## Required database object contract

All organization-owned tables require an organization key, indexed tenant access, RLS membership read and role-restricted writes. Service functions use `security definer`, fixed `search_path`, revoked public execution and explicit service-role grants.

| Object family | Type / grain | Key and idempotency | Written by / read by | Lifecycle |
| --- | --- | --- | --- | --- |
| organizations, organization_members | tables / tenant and user membership | UUID; unique org code and org+user | admin/Auth / all domains | master |
| sync batches/runs/heartbeat/requests | tables / ingestion run or agent | run ID, request ID | sync agent / health UI | derived/transient |
| source orders/workbank/stock/audit/release lines | tables / source snapshot record | batch+source key; audit source ID; order+line | read-only Oracle agent / operational modules | immutable snapshots/current projection |
| current/reconciliation views | views / latest complete snapshot | latest pointer | none / app | derived |
| product families/types/products/source mappings | tables / canonical identity or exact source mapping | org+code; org+source+source code | admins / routing and mix | master |
| work centers/operations/resources/processes | tables / canonical operation resource | org+code | admins / routing/capacity | master |
| routings/revisions/operations/assignments | tables / routing revision step | org+code; routing+revision; revision+sequence | admins / MO creation | master; released revision immutable |
| task/operational-code mappings | tables / exact contextual rule | source+dataset+code+context | admins / resolver | master |
| release history/events | tables / transition | demand/event/snapshot uniqueness | reconciliation / audit UI | immutable |
| production demand | table / SO line + routing | natural key prevents active duplicate | reconciliation / MO engine | reusable identity |
| production orders/MO lines/operations | tables / SO+routing, demand mapping, operation snapshot | unique org+SO+routing; unique demand mapping; MO+sequence | MO engine / execution/planning | protected execution |
| canonical quantity/current operation/progress | functions/views | deterministic from active mappings/operations | none / application | derived |
| Release Queue | view / line with SO summary | current source line | none / queue UI | derived |
| Machine Load/Not Approved | views/services / active or informational source line | source record key | none / machine load UI | derived and isolated |
| production events | table / accepted event | source record key+metric+date/shift | sync/manual screen / KPI | immutable/idempotent |
| labour/KPI/capacity/planning | tables/views/functions / configured rule or operational plan | effective-date/config keys; plan version | admin/import/planner / dashboards | master plus derived |
| maintenance domain | tables/views/functions/storage / asset, WO, PM, transaction | org natural keys; append-only history/transactions | authorized maintenance roles / maintenance UI | master and audited operations |

## Contract tests to carry into V2

- Release: N-Y, Y-N, Y-N-Y, unknown source, partial release and transition idempotency.
- Demand: natural-key duplicate prevention, revocation, identity-preserving reactivation and inactive-zero contribution.
- MO: SO+routing grouping, cross-SO isolation, MO/MO-line reuse, canonical quantity, mixed MO, IN_PROGRESS/COMPLETED/CANCELLED protection.
- Routing: deterministic resolved case, unresolved case, conflicting case and explicit proof that blank SKU cannot resolve Routing.
- Release Queue: every state, precedence, multiple blockers, zero-production handling and line identity.
- Machine Load: active calculations unchanged when informational rows toggle on/off.
- Product Mix: state separation, SO+SKU overlap suppression, record dedupe, unclassified visibility and quantity semantics.
- Maintenance: permissions, lifecycle transition, checklist closure, no-parts evidence, inventory posting and PM idempotency.

Validated E6.8.1 fixtures A-G remain the normative lifecycle suite and must execute in `BEGIN`/`ROLLBACK` with zero residue.

## Baseline gap matrix

| Object/domain | Current 001 status | Contract status | Action required |
| --- | --- | --- | --- |
| tenancy/RLS helpers | COMPLETE, role vocabulary requires alignment check | CONTRACT_FOUND | align memberships and maintenance role bridge |
| source snapshots | INCORRECT/incomplete columns and lifecycle | CONTRACT_FOUND | align authoritative line snapshot and current views |
| Product Master | INCORRECT field/natural-key differences | CONTRACT_FOUND | align exact source-code/product semantics |
| process/task/operational-code mapping | MISSING/partial | CONTRACT_FOUND | add process and contextual resolvers |
| Routing revisions/operations | INCORRECT shape vs validated implementation | CONTRACT_FOUND | implement released revision contract |
| release lifecycle/history | MISSING/incorrect simplified model | CONTRACT_FOUND | replace with line authority and lifecycle functions |
| Production Demand | INCORRECT simplified statuses/provenance | CONTRACT_FOUND | implement validated natural keys/statuses |
| MO lines and quantity authority | INCORRECT table/function shape | CONTRACT_FOUND | add manufacturing lines and canonical quantity functions |
| E6 revocation/reactivation | MISSING | CONTRACT_FOUND | implement final functions and fixtures A-G |
| current source/sync projections | MISSING | CONTRACT_FOUND | add views/RPCs used by app |
| Release Queue | MISSING | CONTRACT_FOUND | add canonical line resolver/view |
| Machine Load/Not Approved | MISSING | CONTRACT_FOUND | add derived isolated projection |
| Product Mix | MISSING DB classification projection; service rules exist | CONTRACT_FOUND | add only required canonical projection/config |
| production events/performance | MISSING | CONTRACT_FOUND | add event and KPI contracts |
| planning/capacity/labour | MISSING | CONTRACT_FOUND | add current validated contracts |
| maintenance | MISSING | CONTRACT_DERIVABLE_FROM_VALIDATED_TESTS | add minimum current contract |
| legacy migration objects not read by current app | UNNEEDED | not canonical | do not add |

