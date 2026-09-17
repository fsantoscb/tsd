# MACHINE LOAD PRODUCT MIX DIAGNOSTIC

## 1. Scope and snapshot

Phase: `ML-MIX1` (diagnostic only).

Live synchronized snapshot analysed on 17 September 2026. Oracle remained read-only. No Machine Load rule, database object, Product Mapping, Production Demand, Manufacturing Order, capacity, target or UI was changed.

Environment note: the checkout's local `.env.local` points to a separate Supabase project (`tlflip...`). Live counts were therefore read directly, read-only, from the published ERP database (`gdaj...`) through its authenticated SQL Editor. Results below must not be interpreted as local E5/E6 database results.

## 2. Current product data model

| Dataset | Grain | Product fields actually available | Quantity |
| --- | --- | --- | --- |
| Oracle Workbank / `v_current_workbank` | Oracle workbank row (`source_row_id`) | `product_code`, `product_description`, `product_group`, customer, queue/task, zone/location, due date | `source_qty`, `production_units`, `prints_per_garment` |
| Sales Order header / `v_current_orders` | Sales Order | customer, due date, priority, site, route evidence and release evidence | No product-line quantity |
| Release lines / `v_current_release_order_lines` | Sales Order + source `line_number` | `product`, `product_name`, `group_code`, client | `qty_lcd` |
| Release Queue / `v_release_queue` | Sales Order | process totals (DTG, Underprint and others), release status/blockers, due date | `total_process_qty` and process subtotals |
| ML-NA2 / `v_machine_load_not_approved` | Sales Order + release line | `product`, `product_name`, canonical process label, routing-resolution status | `process_quantity`; explicitly `PROCESS_QUANTITY` |
| Machine Load active mix | Filtered Workbank row | Workbank product code/description and derived product type/family | Physical `source_qty` |
| Product Mapping / Product Master | Canonical architecture exists in later local migration work | Not consumed by the currently published Machine Load mix | Not used here |
| Production Demand / Manufacturing Orders | Later architecture domain | Not a source for the published Machine Load mix; tables were absent in the ML-NA2 published-environment isolation check | Not used here |

The current page therefore classifies the Oracle Workbank description, not canonical Product Master records.

## 3. Existing classification logic

Verdict: `PARTIAL_CLASSIFICATION`.

The application has one deterministic code classifier in `apps/web/lib/production-mix.ts`:

1. Extract text before the first `" - "` in `product_description`.
2. Normalize to uppercase.
3. Match exact approved type sets for adult tees, kids tees, long sleeves and tanks/singlets.
4. Match exact/suffix approved terms for hoodies, sweats, crews and quarter-zips.
5. Match `DRESS`, `TOTE` or `BAG`.
6. Return `OTHER` otherwise.

Audience is separately derived from prefixes (`MENS/WOMENS`, `BOYS/GIRLS/KIDS/CHILDRENS`). A second, narrower audience classifier exists in item mapping. There is no database-backed canonical Product Family assignment in the published Machine Load path.

This is not `EXISTING_CANONICAL_CLASSIFICATION` because the result is derived from description syntax in application code. It is not `NO_CLASSIFICATION` because the active dataset has complete deterministic coverage under the current rules.

## 4. Classification coverage

### Active Workbank scope

| Measure | Count |
| --- | ---: |
| Total distinct products | 1,583 |
| Classified | 1,583 |
| Unclassified (`OTHER`) | 0 |
| Ambiguous product types | 0 |
| Active Sales Orders | 167 |
| Physical quantity | 12,170 |

`OTHER` is treated as unclassified for quality reporting. No active product fell into it in the corrected parity test.

### Product families

The potential column is process quantity and is deliberately not added to active physical quantity.

| Product family | Distinct active products | Active orders | Active physical qty | Potential NOT_APPROVED process qty |
| --- | ---: | ---: | ---: | ---: |
| Adult T-Shirts | 835 | 118 | 7,274 | 511 |
| Kids T-Shirts | 489 | 81 | 3,887 | 894 |
| Hoodies / Sweats | 196 | 41 | 803 | 44 |
| Totes | 2 | 2 | 6 | 0 |
| Long-Sleeve T-Shirts | 13 | 2 | 45 | 0 |
| Tanks / Singlets | 37 | 10 | 122 | 0 |
| Dresses | 11 | 4 | 33 | 4 |
| Other / Unclassified | 0 | 0 | 0 | 8,513 |

Examples observed:

- Adult T-Shirts: `CTL-0525-912-L` / WOMENS T - ACACIA.
- Kids T-Shirts: `CTB-0406-366-0` / BOYS T - HOPPIN ABOUT AUS.
- Hoodies / Sweats: `COB-5692-152-10` / BOYS CREW - FOREVER STOKED.
- Totes: `FVU-2728-302-OS` / UNIVERSAL CARRY TOTE - HAWAII ROOSTER.
- Dresses: `CTG-0507-928-10` / GIRLS DRESS - SCENIC TURTLE.
- Long sleeves: `NTM-2205-141-3XL` / MENS L/S T - EVERYDAY - COTTON.

Potential `OTHER` examples include caps, magnets, keyrings, stickers, bibs, rompers, coolers and metal accessory tags. These are valid source products but are not reliable members of the current garment-family model.

No conflicting active classification was found for a product code in this snapshot.

## 5. Canonical demand states

The safest published names are:

| State | Authoritative source | Definition | Grain | Inclusion | Exclusion | Mutually exclusive in snapshot? |
| --- | --- | --- | --- | --- | --- | --- |
| `WAITING_FOR_PICKING` | Workbank queue `SP11` | Active DTG physical work still in upstream picking | Workbank row | Current batch, queue SP11, positive `source_qty` | PCOR and Release Queue-only records | Yes within active Workbank selection |
| `READY_TO_PRINT` | Workbank queue `PCOR` | Active DTG physical work picked/available at print stage | Workbank row | Current batch, queue PCOR, positive `source_qty` | SP11 and Release Queue-only records | Yes within active Workbank selection |
| `NOT_APPROVED_INFORMATIONAL` | `v_machine_load_not_approved` + canonical `v_release_queue.release_status='NOT_APPROVED'` | Potential source demand not approved for execution | Sales Order line | Current release snapshot, positive `qty_lcd`, canonical NOT_APPROVED | All active execution totals | Yes in the observed Order+SKU test; structurally separate by design |

Other canonical Release Queue statuses exist but are not Machine Load execution states:

| Release status | Orders | Process qty |
| --- | ---: | ---: |
| `BLOCKED` | 121 | 43,391 |
| `ELIGIBLE` | 21 | 11,413 |
| `FUTURE_DUE` | 2 | 6 |
| `NOT_APPROVED` | 10 | 9,966 |

`BLOCKED`, `ELIGIBLE` and `FUTURE_DUE` must not be renamed to active/ready without a separate approved business phase. Zero-production records are excluded from `v_release_queue` and remain diagnostic rather than load.

## 6. Live state distribution

| State | Rows | Orders | Quantity | Quantity meaning |
| --- | ---: | ---: | ---: | --- |
| `WAITING_FOR_PICKING` | 1,948 | 66 | 5,735 | Physical Workbank `source_qty` |
| `READY_TO_PRINT` | 6,435 | 101 | 6,435 | Physical Workbank `source_qty` |
| `NOT_APPROVED_INFORMATIONAL` | 817 | 10 | 9,966 | Release-line process quantity (`qty_lcd`) |

The active physical total is 12,170. The NOT_APPROVED value is not part of that total.

## 7. State overlap and double-count analysis

Tested keys and findings:

| Key | Finding |
| --- | --- |
| Workbank `source_row_id` | 0 duplicate current-row keys |
| Sales Order + Product/SKU across active Workbank and NOT_APPROVED | 0 overlaps in the current snapshot |
| Sales Order + Line | Not directly comparable: Workbank does not expose the Release Queue `line_number` as the same authoritative field |
| Product alone | Not unique; products legitimately occur in many orders and states |
| Routing | Not suitable; ML-NA2 routing is unresolved/ambiguous for the current potential records |
| Production Demand ID | Not available in the published Machine Load path |
| MO / MO line | Not available in the published Machine Load path |

Current data has no observed Order+SKU overlap, but the canonical future anti-double-count key should be source system + Sales Order + Sales Order Line + source product + snapshot/lifecycle identity. Until Workbank-to-release-line identity is proven, totals across active and potential states must remain separate.

## 8. Quantity semantics

Verdict: `QUANTITY_SEMANTICS_NOT_COMPATIBLE`.

| State | Field | Meaning |
| --- | --- | --- |
| Waiting for Picking | Workbank `source_qty` | Physical quantity used by the current active Production Mix |
| Ready to Print | Workbank `source_qty` | Physical quantity used by the current active Production Mix |
| Not Approved | Release line `qty_lcd` / `process_quantity` | Process/source demand quantity; explicitly not guaranteed to be garments |

Waiting and ready use the same active Workbank unit and can be compared or stacked within the active mix. NOT_APPROVED cannot be stacked into that same physical total. No conversion is approved in ML-MIX1.

## 9. Productivity-modelling readiness

Verdict: `NOT_READY_FOR_PRODUCTIVITY_MODEL`.

Reasons:

- Active garment classification is deterministic and currently complete, which is a strong foundation.
- Classification is still description-derived application logic rather than canonical Product Master data.
- The potential population is dominated by `OTHER` and includes materially different products/processes.
- Product family does not yet carry an approved productivity factor, operation, routing, blank-product identity or machine-time model.
- Physical garment quantity for NOT_APPROVED remains unresolved.
- Similar-looking product descriptions do not prove equal production complexity.

ML-MIX2 may visualize information, but must not drive capacity or productivity.

## 10. Proposed Product Mix model

Use one shared read model with three separate measures per family:

1. `active_waiting_physical_qty` from SP11 Workbank rows.
2. `active_ready_physical_qty` from PCOR Workbank rows.
3. `potential_not_approved_process_qty` from ML-NA2.

Rules:

- Waiting + Ready may form an active physical subtotal.
- Potential must be visually separated and labelled `PROCESS QTY - NOT GARMENTS`.
- Do not show a combined grand total across active and potential.
- Preserve `Other / Unclassified`; never force unsupported products into garment families.
- Keep source order and product identity in drilldown.

## 11. Visualisation and drilldown contract

A grouped bar/column chart is appropriate only with a unit boundary:

- Active Waiting and Active Ready may be stacked because both are physical Workbank quantities.
- Potential Not Approved must be a separate adjacent bar, separate axis/panel, or patterned informational marker with its own unit label.
- It must not visually imply addition to the active stack.

Clicking a segment should return:

- demand state;
- Sales Order;
- source line where available;
- product/SKU and description;
- family and extracted product type;
- quantity plus explicit unit/semantics;
- customer and due date;
- process, routing-resolution status and blockers where applicable.

## 12. Filter behaviour

Product Mix must reuse the existing Machine Load scope and filter values; no second filter engine.

- Process/machine/routing filters apply only where the underlying dataset has deterministic evidence.
- Unresolved potential records remain unassigned instead of being filtered into a machine.
- Due date, customer and product filters apply independently to both datasets using their evidenced fields.
- `Show Not Approved=OFF` suppresses the potential series and query.
- `Show Not Approved=ON` adds only the informational series.
- Active totals must remain identical between OFF and ON for the same snapshot.

## 13. Regression boundary

The future Product Mix view is read-only and informational. It must not alter active load, backlog, aging, capacity, utilisation, productivity, targets, labour, scheduling, Production Demand or Manufacturing Orders.

## 14. Unresolved issues

- No canonical Product Family assignment is consumed by the published Machine Load.
- Release line and Workbank line identity are not directly joinable at authoritative line grain.
- NOT_APPROVED physical garment count is unresolved.
- `OTHER` potential demand spans heterogeneous processes/products.
- Product Master, blank-product, routing and operational-code context are not available in the current published Machine Load read model.
- Process/routing filters cannot safely assign unresolved potential records.

## 15. Implementation recommendation

Proceed with ML-MIX2 only as an informational, dual-unit visualization:

- preserve the existing active classifier and active physical totals;
- implement active Waiting/Ready as the only stackable values;
- expose NOT_APPROVED in a separately labelled process-quantity series;
- show Other/Unclassified explicitly;
- reuse the Machine Load filters;
- provide order/product drilldown;
- add parity tests proving OFF/ON does not change active KPIs;
- do not introduce productivity factors or quantity conversion.

This recommendation makes ML-MIX2 safe despite the incompatible quantity semantics because it forbids combined totals and protects the existing operational calculations.
