# Canonical V2 Quantity Authority Report

## Phase C5.2A result

**E. NO_AUTHORITATIVE_QUANTITY_PROVEN**

This phase was read-only. No Production Demand, Demand Mapping, Manufacturing Order, MO line, schema, or source data was changed. Oracle, DEV, production, and V2 derived state remained untouched.

## Runtime trace

| Step | Object / field | Grain | Transformation | Semantics |
| --- | --- | --- | --- | --- |
| Oracle release | `IS_ORDER_LINE.RELEASED` | Order + line | Exact Y/N normalization | Authoritative release state |
| Oracle release quantity currently extracted | `IS_ORDER_LINE.QTY_LCD` | Order + line | Numeric passthrough | Lowest-unit numeric quantity; zero for every supported DTG/Underprint line |
| V2 source | `source_order_release_lines.production_units` | Order + line | Currently populated from `QTY_LCD` | Preserved release-line source quantity |
| Workbank source | `IS_WORKBANK_V.QTY`, `WEIGHT` | Operational Workbank row | Weight for CARTON/PWL1, otherwise quantity | Current operational snapshot, not Sales Order Line demand |
| Current PROD | `v_current_workbank.production_units` | Workbank row | Same Workbank rule | Operational remaining/state quantity; no canonical Demand/MO tables exist in PROD |
| Historical E5/E6 Demand | `production_demand_lines.quantity` | Demand line | Copied from source `production_units` | Positive source quantity required |
| Historical MO mapping | `manufacturing_order_lines.planned_quantity` | Demand-to-MO line | Copied from Demand quantity | Mapping contribution |
| Canonical MO quantity | `sum(active mapped Demand contributions)` | Sales Order + Routing MO | Sum of active mappings | Derived/cache quantity |

## Quantity candidate inventory

| Field | Source | Positive lines in supported set | Total | Meaning | Candidate |
| --- | --- | ---: | ---: | --- | --- |
| `QTY_LCD` | Oracle `IS_ORDER_LINE` | 0 / 4,438 | 0 | Numeric quantity in lowest units | No: zero for all supported lines |
| `QUANTITY` | Oracle `IS_ORDER_LINE` | 0 / 4,438 | 0 | User-entered formatted quantity | No: zero for all supported lines |
| `QTY_PROCESSED` | Oracle `IS_ORDER_LINE` | 0 / 4,438 | 0 | Quantity already processed | No: execution result, also zero |
| `WEIGHT` | Oracle `IS_ORDER_LINE` | 0 / 4,438 | 0 | Weight | No: wrong unit and zero |
| `QTY_UNITS` | Oracle `IS_ORDER_LINE` | 4,438 / 4,438 | 4,438 | Data dictionary: pack-description level number | No: not physical/order quantity |
| `QTY` / `WEIGHT` | Oracle Workbank | No line-grain match | Not comparable | Operational snapshot quantity | No: wrong grain and mutable remaining state |
| `production_units` | V2 release line | 0 / 4,438 | 0 | Current `QTY_LCD` projection | No: zero |

Oracle column comments are decisive: `QTY_UNITS` is “Level number of pack description quantity entered”, not quantity. It cannot be treated as one garment merely because its observed value is `1`.

## Exact Routing-resolved population

| Process group | Lines | Positive authority | Zero authority | Null authority | Total authority quantity |
| --- | ---: | ---: | ---: | ---: | ---: |
| DTG_1 | 863 | 0 | 863 | 0 | 0 |
| DTG_2 | 3,073 | 0 | 3,073 | 0 | 0 |
| UNDERPRINT | 502 | 0 | 502 | 0 | 0 |
| **Total** | **4,438** | **0** | **4,438** | **0** | **0** |

For all 5,768 released lines, `QTY_LCD` is positive on only 727 unsupported/noncanonical lines: PROD 44, Stickers 343, and UV Print 340. This does not resolve the supported DTG/Underprint population.

## Product/component structure

Representative Oracle orders show a paired structure by `ORDER_NO + ORIG_REF1`:

- Custom DTG/Underprint process line: `RELEASED=Y`, quantity fields zero.
- Physical blank `PROD` line: commonly `RELEASED=N`, quantity fields also zero in the inspected example.
- `ORIG_REF3` links the blank line back to the custom SKU; it is not a proven quantity field.

This proves that Routing/process lines and physical blank lines are separate records. It does not prove a positive quantity formula between them.

## Partial release and process safety

- Partially released Sales Orders: 90.
- All 90 preserve line-specific Y/N state.
- Y lines can be identified independently; N lines remain excluded.
- No Sales Order header quantity was used.
- Multi-process collisions at `ORDER_NO + ORIG_REF1` across DTG and Underprint: 0 in the current population.
- Workbank cannot be joined reliably to the 4,438 lines at `ORDER_NO + LINE_NUMBER` or `ORDER_NO + SKU`.

The multi-process double-count risk is therefore not observed in the current snapshot, but Workbank aggregation remains unsuitable for Demand creation because it has operational-row grain and mutable remaining-state semantics.

## Current PROD comparison

PROD read-only contains `source_release_order_lines`, `source_workbank_items`, `v_current_workbank`, and Release Queue views. It does not contain `production_demand_lines`, `manufacturing_order_lines`, or canonical Manufacturing Orders.

Consequently:

- Exact canonical Demand/MO quantity matches: 0.
- Routing-resolved lines with no comparable PROD Demand/MO quantity: 4,438.
- Representative released order `130133510` has no current Workbank row, so Workbank cannot explain its release-line quantity.

PROD proves current operational Workbank quantities, not an authoritative line-level quantity contract for creating canonical Demand.

## Quantity semantics

| Semantic | Grain | Mutable | Additive for Demand | Result |
| --- | --- | --- | --- | --- |
| Ordered quantity | Sales Order line | Until order amendment | Potentially | Not identified positively for supported process lines |
| Released quantity | Sales Order line | Release lifecycle | Yes, only when proven | Release state proven; quantity not proven |
| Production Demand quantity | Canonical Demand line | Lifecycle-controlled | Yes | Must not be created yet |
| Remaining to produce | Operational row/stage | Yes | No for original Demand | Workbank evidence only |
| Physical garment quantity | Physical product/component | Potentially | Yes if authoritative | Physical linkage observed; quantity absent |
| Process quantity | Process line | Yes | Risks multi-process duplication | Not interchangeable with garments |
| Picking quantity | Workbank/stock row | Yes | No for original Demand | Operational evidence |
| MO quantity | Sales Order + Routing | Derived | Sum of active mappings | Cannot exist before source quantity authority |

## Proposed V2 contract

No executable quantity formula is proposed. The safe contract remains:

- Source grain: `ORDER_NO + LINE_NUMBER [+ process only if independently proven]`.
- Source quantity: unresolved until an Oracle field or deterministic relation with documented business semantics is proven.
- Null, zero, negative, or nonnumeric quantity: ineligible for active Demand.
- Demand Mapping contribution: exactly the accepted positive Demand quantity.
- MO planned quantity: sum of active Demand Mapping contributions for one Sales Order + one Routing.
- Workbank quantities: operation evidence only, never silently substituted for original Demand quantity.
- Idempotency key: organization + source system + order + line (+ process only if proven necessary).

## Legacy test classification

| Failing contract | Classification | Reason |
| --- | --- | --- |
| `bootstrap_phase_e5_master_data(uuid)` existence | LEGACY_SCHEMA_COMPATIBILITY_TEST | Superseded bootstrap function is intentionally absent from clean V2 |
| Legacy Task coverage objects in `routing_phase_e5_2.sql` | LEGACY_SCHEMA_COMPATIBILITY_TEST | C5.1 uses approved operational-code configuration rather than old task schema |
| `resolve_source_operational_context(...)` function call | LEGACY_SCHEMA_COMPATIBILITY_TEST | Tests an old function signature, not the clean V2 resolver contract |
| Product/Routing uniqueness and organization isolation assertions | CANONICAL_BEHAVIOUR_TEST | Behaviour remains required and passes in Routing suites |
| Legacy bootstrap implementation-shape assertion | OBSOLETE_TEST | Tests the internals of a function deliberately not carried forward |

## Validation

| Validation | Result |
| --- | --- |
| Quantity diagnostic | PASS, read-only |
| Routing SQL | 26/26 PASS |
| Release ingestion SQL | 10/10 PASS |
| Application tests | 177/177 PASS |
| Lint | PASS |
| Typecheck | PASS |
| Production build | PASS |
| Database writes | 0 |
| Oracle writes | 0 |

## Final gate

**C5.2A BLOCKED — NO AUTHORITATIVE PRODUCTION QUANTITY PROVEN**
