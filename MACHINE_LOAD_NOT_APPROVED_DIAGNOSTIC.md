# Machine Load / Not Approved Diagnostic

Date: 2026-09-17 (Australia/Brisbane)

Scope: PHASE ML-NA1, read-only diagnostic. No UI, Oracle, database, production-demand, Manufacturing Order, scheduling, capacity, or business-rule change was made.

## Executive conclusion

`NOT_APPROVED` can be added to Machine Load safely only as a second, explicitly informational dataset. It must not be appended to the current workbank-derived rows or to any dataset used by active-load, capacity, backlog, productivity, scheduling, Production Demand, or Manufacturing Order calculations.

The current Release Queue is canonical for release classification and process quantities. Its order-level output is not sufficient to assign one routing or one machine bucket to a multi-process order. The line-level source is available and must be used to split informational demand by source line and canonical process. Routing and physical-machine assignment must remain `NULL` where no approved canonical mapping exists.

## 1. Current data-flow diagram

```text
Oracle (READ ONLY)
  IS_ORDER_VIEW_SALE_V + IS_ORDER_HEAD
  IS_WORKBANK_V
  IS_STOCK_V
  IS_PRODUCT
  ISIS_AUDIT
        |
        v
apps/oracle-sync/src/source-reader.ts
  orders / workbank / stock / audit queries
        |
        v
apps/oracle-sync/src/mapping.ts
  productionUnits, printsPerGarment, queue, task
        |
        v
POST /api/ingest/oracle/sync -> ingest_sync_batch(jsonb)
        |
        +--> source_orders
        +--> source_workbank_items
        +--> source_stock_items
        +--> source_audit_events
        +--> sync_batches
        |
        v
v_latest_completed_batch
  +--> v_current_orders
  +--> v_current_workbank
  +--> v_current_stock
        |
        +------------------------------+
                                       v
capacity profiles/legacy override -> v_capacity_load
screen_print_jobs ------------------> apps/web/lib/machine-load.ts
                                       |
                                       +--> hard-coded zone/state aggregation
                                       +--> forecast print ratio
                                       +--> production mix/filter model
                                       |
                                       v
                         /production/machine-load/page.tsx
                                       |
                                       +--> Machine Load cards
                                       +--> load/capacity KPIs
                                       +--> production runway
                                       +--> Production Mix

Other consumers of machineLoad():
  /                       Control Tower ready-to-lift summary
  /production/performance Production Mix input
```

The current Machine Load path does **not** read `production_demand`, Manufacturing Orders, `v_release_queue`, or `v_release_queue_all`.

## 2. Current structures and responsibilities

| Layer | Structure | Responsibility |
| --- | --- | --- |
| Oracle reader | `apps/oracle-sync/src/source-reader.ts` | Reads incomplete orders, selected workbank zones, selected stock locations, product print factor, and audit events. |
| Mapping | `apps/oracle-sync/src/mapping.ts` | Converts Oracle `QTY`/`WEIGHT` to `productionUnits`; maps `PROD_X_5` to prints per garment for DTGS. |
| Snapshot tables | `source_orders`, `source_workbank_items`, `source_stock_items`, `sync_batches` | Stores the current imported source snapshot and batch provenance. |
| Current views | `v_latest_completed_batch`, `v_current_orders`, `v_current_workbank`, `v_current_stock` | Restricts reads to the latest completed batch. |
| Capacity | `v_capacity_load` | Returns capacity from active profiles or legacy override. It also has planning demand fields, but Machine Load reads only daily/weekly capacity. |
| Manual Screen Print | `screen_print_jobs` | Provides planned/completed quantities and status for Screen Print cards. |
| Server service | `apps/web/lib/machine-load.ts` | Authenticates an admin, reads all source rows in pages, applies current classification and aggregation rules. |
| State rule | `apps/web/lib/machine-load-rules.ts` | Classifies `NOT_STARTED`, `ON_GOING`, `READY_TO_LIFT`, and `OUTSIDE`. |
| Product Mix | `apps/web/lib/product-mix-rules.ts`, `apps/web/lib/production-mix.ts` | Classifies audience/garment type and reconciles pick status. |
| Page | `apps/web/app/production/machine-load/page.tsx` | Computes load/capacity/runway presentation from the server-service result. |
| Test | `apps/web/__tests__/machine-load.test.ts` | Tests production-state classification only. |

## 3. Exact source of each Machine Load metric

| Metric | Current source and rule | Notes |
| --- | --- | --- |
| Active DTG pick load | `v_current_workbank.production_units`, `from_zone = PG11` | Garments. |
| Active DTG print load | `v_current_workbank.production_units * prints_per_garment`, `from_zone = DTGS` | Confirmed prints. |
| Forecast DTG prints | PG11 garments multiplied by observed DTGS product ratio, then product-group ratio, then global ratio | Forecast, not an Oracle physical print count. |
| Total DTG quantity | confirmed DTGS prints + forecast PG11 prints | Page-computed, in prints. |
| Underprint to pick | Sum of `production_units` in PG01, PG1H, PG1A, PG1D | Garments. |
| Underprint ready to print | `v_current_stock.production_units` where location contains `UNDERPRINT` | Garments. |
| DTG order state | Per-order PWL1 printed quantity versus PG11+DTGS remaining quantity | Uses `productionState()`. |
| Ready to Lift | PWL1 stock with `product` beginning `#`, no remaining PG11/DTGS quantity, and order status not matching cancel/hold/invalid/unreleased | Orders, garments, locations, and boxes. |
| Screen Print load/state | `screen_print_jobs.planned_quantity`, `completed_quantity`, `status` | Manual source. Cancelled rows excluded. |
| Production Mix | Workbank rows whose `queue` is SP11 or PCOR; sums `source_qty` | Garment/process workload; filters apply only to Production Mix. |
| Routing/process allocation | Hard-coded source-zone/queue interpretation in `machine-load.ts` | No canonical Routing Master or MO routing is consulted. |
| Daily capacity | `v_capacity_load.daily_capacity` for DTG and UP | Current live DTG value is 3,952; UP is inferred by live lead/load as 2,907. |
| Weekly capacity | `v_capacity_load.weekly_capacity`, but page recomputes DTG weekly capacity as daily capacity x selected production days | Live five-day DTG capacity is 19,760. |
| Available capacity/gap | capacity minus page-computed demand | Computed in React server page. |
| Utilisation/load | page-computed demand divided by daily/weekly capacity | `v_capacity_load.load_percent` is not used by this page. |
| Relative lead | page-computed demand divided by daily capacity | DTG in prints; UP in garments. |
| Runway | Current Brisbane date, selected weekdays, fixed daily capacity, confirmed-first depletion | Does not group source demand by due date. |
| Backlog | Not calculated by Machine Load | The word `backlog` in the runway is presentation wording for remaining load, not the ERP backlog definition. |
| Age | Not calculated by Machine Load | No age KPI or aging bucket exists on this page. |
| Productivity | Not calculated by Machine Load | Performance owns productivity calculations. |
| Targets | Not calculated by Machine Load | No production target is changed or consumed here. |
| Ready/released work | Physical workbank/stock evidence plus order eligibility regex | Release Queue approval state is not used. |

## 4. Contamination-risk matrix

| Point | Classification | Risk and required control |
| --- | --- | --- |
| Append NOT_APPROVED rows to `v_current_workbank` or `source_workbank_items` | BLOCKER | Would make informational demand indistinguishable from physically active WIP and alter DTG/UP load, order states, mix, and dispatch logic. |
| Append NOT_APPROVED to the current `orders` object returned by `machineLoad()` | BLOCKER | Page reductions would immediately change active totals, utilisation, lead time, gaps, and runway. |
| Add process quantity to `confirmedDemand`, `forecastDemand`, or `demand` | BLOCKER | Would consume capacity and change operational scheduling signals. |
| Insert NOT_APPROVED into Production Demand or MO tables | BLOCKER | Violates the release lifecycle and could create or change MOs. |
| Reuse `v_capacity_load.demand_units` for informational demand | BLOCKER | That view is an operational capacity/planning contract. |
| Mix informational rows into Production Mix SP11/PCOR input | RISK | Would change mix totals used by Machine Load and Performance. |
| Change `machineLoad()` active fields | RISK | The function is also consumed by the Control Tower and Performance page. |
| Use order-level `v_release_queue` row as one machine assignment | RISK | One order may contain multiple process groups; 9 current NOT_APPROVED orders visibly contain both DTG and Underprint. |
| Treat `route_id = YES` as canonical routing | RISK | It is release-route evidence, not a Routing Master/revision identifier. |
| Convert `qty_lcd` to garments or prints | BLOCKER | The Release Queue contract is process quantity; physical garment count is unresolved. |
| Read `v_release_queue` separately and return a new `potentialLoad` object | SAFE | Preserves active calculations if no existing field is modified. |
| Build a dedicated read-only line/process informational view | SAFE | Supports deterministic split and explicit unresolved routing/machine fields. |
| Render an overlay with separate subtotal and explicit state | SAFE | Safe when OFF by default and excluded from all active KPI reducers. |

## 5. Canonical NOT_APPROVED source

### Oracle and ingestion

- Candidate orders: `IS_ORDER_VIEW_SALE_V` joined to `IS_ORDER_HEAD`.
- Release lines: `IS_ORDER_LINE` joined to `IS_ORDER_HEAD`, with `IS_PRODUCT.GROUP_CODE` and product name.
- Order release evidence: `IS_ORDER_HEAD.STATUS AS HEAD_STATUS`, `ROUTE_ID`, `COST_CENTRE`, `STOP_SHIP_FLAG`.
- Oracle remains READ ONLY.

### Snapshot and resolver

- Line table: `source_release_order_lines`.
- Current line view: `v_current_release_order_lines`.
- Grain: `(sync_batch_id, order_no, line_number)`.
- Line fields: order, line, product, client, `qty_lcd`, `orig_ref3`, `group_code`, product name, source timestamp.
- Canonical order resolver: `v_release_queue_all`.
- Operational resolver: `v_release_queue`, which excludes `total_process_qty <= 0`.
- `NOT_APPROVED` rule: normalized `cost_centre = NOTAPPRO` after required evidence validation and before general blockers.
- Blockers are retained independently: `ROUTE_BLOCKED`, `STOP_SHIP`, `CUSTOM_EMB`.
- Zero production remains diagnostic as `ZERO_PRODUCTION_QTY` in `v_release_queue_all` and is excluded from `v_release_queue`.

Machine Load must consume these views or a view derived directly from them. It must not reimplement the status precedence in TypeScript or React.

## 6. Routing and machine resolution

### Live snapshot observed at 2026-09-17 11:49 Brisbane

- Operational Release Queue orders: 150.
- NOT_APPROVED orders: 15.
- UNKNOWN: 0.
- Nine NOT_APPROVED orders visibly contain both DTG and Underprint quantities.
- Six NOT_APPROVED orders have no visible DTG or Underprint quantity; their positive operational quantity belongs to other process columns.
- Visible NOT_APPROVED process subtotals: DTG 1,357, Underprint 818, UV 1,017, Hats 50, Custom Embroidery 480 process units.

The browser table does not expose every process column or line in its collapsed state, so these subtotals are intentionally not presented as the complete NOT_APPROVED total.

| Classification at current order grain | Orders | Meaning |
| --- | ---: | --- |
| RESOLVED to one Machine Load bucket | 0 | No observed NOT_APPROVED order can safely be treated as one single DTG/UP bucket at order grain. |
| AMBIGUOUS | 9 | Contains both DTG and Underprint. Must be split at release-line/process grain, not assigned wholesale. |
| UNRESOLVED for current DTG/UP buckets | 6 | No DTG/Underprint quantity is visible; do not force into an existing bucket. |

At line grain, these source process mappings are already deterministic in the Release Queue resolver:

| Source `group_code` | Canonical informational process | Machine Load bucket |
| --- | --- | --- |
| DTG_1, DTG_2 | DTG | DTG potential load |
| UNDERPRINT | UNDERPRINT | Underprint potential load |
| UV PRINT | UV | Unresolved / unsupported by current Machine Load |
| HATS | HATS | Unresolved / unsupported by current Machine Load |
| FINISHED | FINISHED | Unresolved / informational only |
| STICKERS | STICKERS | Unresolved / unsupported by current Machine Load |
| VISUAL | VISUAL | Unresolved / unsupported by current Machine Load |
| PROD | PRODUCTION | Unresolved / unsupported by current Machine Load |
| CUSTOM EMB | CUSTOM EMB | Unresolved / blocker context |
| EYEWEAR | EYEWEAR | Unresolved / unsupported by current Machine Load |

No canonical Routing Master ID/revision or production-resource/machine-group ID is present in the Release Queue contract. `route_id` is release evidence (`YES`/`NO`), not a routing assignment. Therefore routing and physical machine group must remain `NULL` until an approved canonical mapping exists.

## 7. Quantity semantics

The only approved quantity for a NOT_APPROVED overlay is:

```text
source_release_order_lines.qty_lcd
```

- Source: Oracle `IS_ORDER_LINE.QTY_LCD`.
- Grain: sales-order line within the latest completed sync batch.
- Aggregation: sum by order and normalized `GROUP_CODE` in `v_release_queue_all`.
- Meaning: process quantity for the classified process group.
- It is **not** physical garment count.
- It is **not** automatically print count.
- It must be labelled `process quantity` or `potential process units`.
- Cross-process quantities must not be summed and labelled garments.

`PHYSICAL GARMENT COUNT` remains unresolved.

## 8. Proposed isolated architecture

Keep two immutable concepts:

```text
ACTIVE_LOAD != POTENTIAL_LOAD
```

### A. Existing active load

No change:

```text
v_current_workbank + v_current_stock + screen_print_jobs
  -> machineLoad().orders / capacity / active KPIs
```

### B. Potential NOT_APPROVED load

Add a read-only projection, preferably `v_machine_load_not_approved`, with one row per current release line:

```text
v_current_release_order_lines
  JOIN v_release_queue on organization_id + sync_batch_id + order_no
  WHERE release_status = 'NOT_APPROVED'
  -> normalize existing GROUP_CODE mapping
  -> expose process quantity
  -> routing_id/revision = NULL when unproven
  -> machine_group = NULL when unproven
  -> load_bucket = DTG/UNDERPRINT only for the two approved process mappings
```

The view must have no insert/update trigger and no dependency from Production Demand, MOs, capacity, planning, performance, or scheduling.

Add a separate server function, for example `notApprovedMachineLoad()`, or a separate `potentialLoad` property that is never consumed by existing reducers. Do not add rows to `machineLoad().orders`.

Recommended response shape:

```ts
type PotentialLoadItem = {
  demandState: "NOT_APPROVED_INFORMATIONAL";
  salesOrder: string;
  salesOrderLine: string;
  customer: string | null;
  product: string | null;
  process: string;
  routingId: string | null;
  routingCode: string | null;
  routingRevision: number | null;
  machineGroup: string | null;
  loadBucket: "DTG" | "UNDERPRINT" | null;
  dueDate: string | null;
  processQuantity: number;
  quantitySemantics: "PROCESS_QUANTITY";
  releaseStatus: "NOT_APPROVED";
  blockers: string[];
  snapshotCompletedAt: string;
};
```

## 9. Proposed UI contract

- Control: `Show Not Approved`, OFF by default.
- OFF: do not fetch/render potential rows where avoidable; current active totals and layout remain identical.
- ON: render a visually distinct informational overlay or separate subsection.
- Every informational record carries `demandState = NOT_APPROVED_INFORMATIONAL` from the server contract.
- Existing active rows carry `demandState = ACTIVE`; the frontend must not infer state from color, blocker text, or route values.
- Display: SO, line, customer, product, process, routing where proven, machine group where proven, due date, process quantity, release state, blockers, snapshot context.
- Show separate totals such as `Active load` and `Potential not approved`; never display a combined operational total.
- Unsupported processes remain in `Unresolved / other process`, not in DTG or Underprint.
- Multi-process orders appear as separate line/process records while preserving the same sales-order identity.
- Tooltips/labels must say `process units`; never `garments` unless a later authoritative physical quantity is introduced.

## 10. Regression baseline

Source: authenticated production page, Oracle snapshot shown as current at 2026-09-17 11:49 Brisbane.

| Metric | Baseline |
| --- | ---: |
| DTG to pick (PG11) | 6,124 garments |
| DTG ready to print (DTGS) | 6,235 garments |
| DTG confirmed | 8,397 prints |
| DTG forecast | 8,248 prints |
| DTG active total load | 16,645 prints |
| DTG daily capacity | 3,952 prints/day |
| DTG daily load | 421% |
| DTG relative lead | 4.21 working days |
| DTG five-day capacity | 19,760 prints |
| DTG five-day load | 84% |
| DTG five-day gap | +3,115 prints |
| Underprint to pick | 433 garments |
| Underprint ready to print | 4,071 garments |
| Underprint active total load | 4,504 garments |
| Underprint relative lead | 1.55 working days |
| DTG not started orders | 153 |
| DTG ongoing orders | 22 |
| DTG ongoing remaining | 432 garments |
| DTG ready orders | 6 |
| DTG outside | 0 |
| Ready-to-lift garments | 799 |
| Ready-to-lift locations | 10 |
| Ready-to-lift boxes | 10 |
| Screen Print not started / ongoing / ready / outside | 0 / 0 / 0 / 0 |
| Production Mix | 12,359 garments |
| Backlog KPI | Not implemented on Machine Load |
| Productivity KPI | Not implemented on Machine Load |
| Target KPI | Not implemented on Machine Load |

Acceptance for ML-NA2 must prove that every value above is unchanged with `Show Not Approved = OFF`, and that toggling ON changes only the separate potential-load section.

## 11. Blockers and unresolved items

1. Physical garment count is unresolved; only process quantity may be shown.
2. The order-level Release Queue output cannot safely assign multi-process orders to one machine bucket.
3. Canonical routing ID/revision is absent from the Release Queue contract.
4. Canonical production-resource/machine-group mapping is absent.
5. Current Machine Load process classification is hard-coded from workbank zones and must not be reused as proof of a Release Queue routing.
6. Six current NOT_APPROVED orders have no visible DTG/Underprint quantity and must remain outside those buckets.
7. Existing Machine Load tests cover state classification only; ML-NA2 requires explicit isolation and regression tests.

These items do not block an isolated informational implementation because null/unresolved values are permitted and unsupported processes can remain in a separate informational bucket. They do block any attempt to merge potential demand into active machine allocation or capacity.

## 12. Implementation recommendation

Proceed with ML-NA2 only under these controls:

1. Create a line-grain, read-only informational view derived from the canonical Release Queue status and current release lines.
2. Reuse the existing process normalization; do not implement release-status precedence in React or duplicate it in the Machine Load service.
3. Map only `DTG_1`/`DTG_2` to the DTG potential bucket and `UNDERPRINT` to the Underprint potential bucket.
4. Preserve all other processes with a null Machine Load bucket.
5. Keep routing and machine group null until canonical evidence exists.
6. Return potential demand through a separate server contract.
7. Default the UI control OFF.
8. Keep all active KPIs, capacity, utilisation, lead, runway, Production Mix, Control Tower, and Performance reducers unchanged.
9. Add tests proving OFF parity, ON isolation, multi-process line splitting, blocker preservation, zero-production exclusion, and no Production Demand/MO write path.

## Final gate

READY FOR ML-NA2 IMPLEMENTATION
