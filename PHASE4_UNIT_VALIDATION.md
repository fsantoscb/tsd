# Phase 4 Unit and Rule Validation

**Validated:** 09/09/2026  
**Result:** APPROVED

## Approved rules

| Workbank | Record count | Production units | Exact source filter |
|---|---|---|---|
| UP | One stock row = one box/pack | Sum of `WEIGHT` = physical pieces | `LOCATION = UNDERPRINT` |
| DTG | One workbank row = one line | Always `1` per line | `FROM_ZONE = DTGS` |

## DTG print rule

| Source value `IS_PRODUCT.PROD_X_5` | Prints per garment |
|---|---:|
| `1` | 1 |
| `2` | 2 |
| `1 / 2` | 2 |

The product relationship is `IS_WORKBANK_V.CLIENT + PROD` to `IS_PRODUCT.CLIENT + CODE`. `total_prints` is reported separately from garments.

Raw Oracle `QTY` and `WEIGHT` values are preserved. The DTG rule overrides only the derived `production_units`; it does not alter source evidence.

## Validation evidence

- The Oracle sample containing `QTY = 1` and `WEIGHT = 100` now produces `production_units = 1` for DTG.
- Migration `202609090001_phase4_unit_rules.sql` was applied successfully in Supabase.
- A fresh atomic sync batch was accepted: `5381ec9d-9600-4b7b-a077-0df63e203ad5`.
- The resulting DTG snapshot contained 4,579 lines and 4,579 production units.
- A direct Oracle check moments later contained 4,574 DTG lines; the five-line movement is consistent with an active operational queue after snapshot completion.
- The resulting UP snapshot contained 105 boxes and 3,480.575 physical pieces.
- All 23 automated tests passed.
- TypeScript type checking passed.
- The production build passed.

## Gate decision

Phase 4 unit semantics and operational filters are approved. Phase 5 may start when requested.

The print extension was validated with sync batch `bd3c248b-5454-4d56-a117-c4fbf0234d2b`: 4,563 garments, 4,563 production units and 5,980 prints, with no missing print values. A direct Oracle read moments later showed three two-print garments had moved out of the live queue, explaining the expected difference of three garments and six prints.

## DTG Adult/Kids print split

- Descriptions starting with `MENS` or `WOMENS` are Adult.
- Descriptions starting with `BOYS` or `GIRLS` are Kids.
- Other descriptions are retained as Unclassified and displayed with `?`.
- Validation result: 3,923 Adult prints + 2,051 Kids prints + 6 Unclassified prints = 5,980 Total prints.
- The six Unclassified prints belong to orders `130136295` and `130136505`, three each, for Universal Carry Tote products.
