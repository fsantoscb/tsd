# Canonical V2 Business Quantity Contract Report

## Phase C5.2B result

**B. NO ORACLE LINE QUANTITY CAN BE PROVEN**

This phase inspected Oracle and application behavior read-only. Production Demand, mappings, Manufacturing Orders, MO lines, Oracle, DEV, PROD, and V2 derived state were not written.

## Scope

- Source order lines: 23,477
- Released Y lines: 5,768
- Routing-resolved released lines: 4,438
- Routing-unresolved released lines: 1,330
- Partially released Sales Orders: 90

## Oracle line quantity fields

### All 5,768 released lines

| Field | Oracle type | Oracle business description | Positive | Zero | Null | Total |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `QTY_LCD` | NUMBER | Quantity expressed numerically in lowest units | 727 | 5,041 | 0 | 10,337 |
| `QUANTITY` | VARCHAR2 | Quantity as entered, including editing/pack characters | 727 | 5,041 | 0 | 10,337 |
| `QTY_PROCESSED` | NUMBER | Numeric quantity actually processed | 0 | 5,768 | 0 | 0 |
| `WEIGHT` | NUMBER | Weight in kilograms or pounds | 727 | 5,041 | 0 | 10,337 |
| `QTY_UNITS` | VARCHAR2 | Level number of pack-description quantity entered | 5,768 | 0 | 0 | 5,768 |

The 727 positive `QTY_LCD`/`QUANTITY`/`WEIGHT` lines occur only in currently unsupported or noncanonical groups: `PROD` 44, `STICKERS` 343, and `UV PRINT` 340.

### Exact 4,438 Routing-resolved lines

| Field | Positive | Zero | Null | Total |
| --- | ---: | ---: | ---: | ---: |
| `QTY_LCD` | 0 | 4,438 | 0 | 0 |
| `QUANTITY` | 0 | 4,438 | 0 | 0 |
| `QTY_PROCESSED` | 0 | 4,438 | 0 | 0 |
| `WEIGHT` | 0 | 4,438 | 0 | 0 |
| `QTY_UNITS` | 4,438 | 0 | 0 | 4,438 |

`QTY_UNITS` is rejected as commercial quantity. Oracle explicitly describes it as the level number of the pack description, and unrelated lines with quantities such as 100 still carry `QTY_UNITS=1`. Its observed value cannot be reinterpreted as one physical garment.

## Representative order validation

Oracle order `130133510` demonstrates the source structure:

| Line type | Released | Quantity fields | Linkage |
| --- | --- | --- | --- |
| Custom DTG/Underprint process line | Y | `QUANTITY=0`, `QTY_LCD=0`, `WEIGHT=0`, `QTY_PROCESSED=0` | `ORIG_REF1` physical-item index |
| Paired blank `PROD` line | N | Also zero in the inspected order | Same `ORIG_REF1`; `ORIG_REF3` points to custom SKU |

The pair proves that custom process and physical blank are separate Oracle lines. It does not provide a positive ordered quantity or an approved formula for deriving one.

The current ERP order-detail page cannot validate a commercial line quantity. It displays order headers and current Workbank, Stock, and Audit records. Those quantities are operational snapshots, not original Sales Order Line demand.

## Partial release

All 90 partially released Sales Orders retain line-level release identity. The dry-run found 5,520 positive `QTY_UNITS` Y-lines and 10,267 N-lines within those orders, but `QTY_UNITS` is not a quantity authority. No order-header aggregation was used and every N-line remains a zero active-demand contribution.

Result: release separation is proven; original commercial quantity is not.

## Multi-process contract

Current `ORDER_NO + ORIG_REF1` analysis found zero physical keys simultaneously classified as DTG and Underprint among released supported lines. Therefore no current double-count was observed.

This does not authorize multiplying one physical quantity by process count. If one physical item later traverses Underprint and DTG, it must retain one physical original demand while operations represent multiple routing steps. Process quantities must remain distinct from physical-garment quantity.

## Dry run

| Process | Lines | Positive proven quantity | Zero/unproven | Null | Total proven original demand |
| --- | ---: | ---: | ---: | ---: | ---: |
| DTG_1 | 863 | 0 | 863 | 0 | 0 |
| DTG_2 | 3,073 | 0 | 3,073 | 0 | 0 |
| UNDERPRINT | 502 | 0 | 502 | 0 | 0 |
| **Total** | **4,438** | **0** | **4,438** | **0** | **0** |

## Business decision required

Technical investigation is stopped. The business owner must explicitly define one of the following with operational evidence:

- Which Oracle line carries the physical/commercial quantity for DTG and Underprint process lines.
- A deterministic relationship from the released custom line to a physical blank/order line carrying that quantity.
- An approved rule that each released process line represents a fixed physical quantity, if that is truly the business contract.

Until that decision is supplied, the safe contract is:

- `RELEASED=Y` proves eligibility state only, not quantity.
- `RELEASED=N` contributes zero.
- Zero, null, negative, or unproven quantity remains a controlled exception.
- Workbank, printed, picked, completed, and Machine Load values must not be subtracted or substituted during original Demand creation.

## No-write proof

| State | Count / writes |
| --- | ---: |
| Production Demand | 0 |
| Manufacturing Orders | 0 |
| MO lines | 0 |
| Oracle writes | 0 |
| DEV writes | 0 |
| PROD writes | 0 |
| V2 derived writes | 0 |

## Final gate

**B. NO ORACLE LINE QUANTITY CAN BE PROVEN**
