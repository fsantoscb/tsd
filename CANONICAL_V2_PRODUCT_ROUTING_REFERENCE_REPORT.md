# Canonical V2 Product and Routing Reference Report

## Result

Canonical reference data was recovered without copying transactional Demand/MO history and without modifying Oracle, DEV, or production.

## Actual runtime authority

The current production system does **not** contain populated canonical Product/Route tables. Read-only PROD inspection found only the Oracle-derived `source_release_order_lines` and runtime views `v_release_queue` / `v_machine_load_not_approved`. Production resolves process through SQL cases over `GROUP_CODE` and through Workbank queue/location evidence.

| Domain | Actual source | Authority classification |
| --- | --- | --- |
| Product identity | Exact Oracle SKU in V2 `source_order_release_lines` + `source_release_order_lines` | ORACLE_DERIVED |
| Product mapping | Exact Oracle SKU to same canonical SKU; validated E5.7 rule, no fuzzy match | CANONICAL_MERGE |
| Operations | Validated E5 operation vocabulary | CODE_CONFIG |
| Manufacturing processes | Existing V2 process config plus validated E6.3 unsupported-process vocabulary | CODE_CONFIG |
| Routings and steps | Validated E5 DTG, Underprint and Screen Print standard routes | CODE_CONFIG |
| Product/process/routing assignment | Exact released-line `GROUP_CODE` process plus approved standard Routing | CANONICAL_MERGE |
| Operational codes | Validated E6.3 exact PAK/SP11/location mappings | CODE_CONFIG |

Oracle remained read-only. PROD and DEV were read-only/untouched.

## Why the 13 datasets were empty

They are `NEW_CANONICAL_DESTINATION` objects. Production does not populate or use these tables; it performs `RUNTIME_DERIVED` classification directly in views. The earlier assumption that populated canonical rows could be copied from PROD was therefore a `WRONG_SOURCE_ASSUMPTION`.

## Source to V2 transformation

| Source | Source column/rule | Destination | Natural key | Conflict handling |
| --- | --- | --- | --- | --- |
| Oracle release snapshot | `PRODUCT` / exact source SKU | `products.sku`, `source_product_code` | organization + SKU | Missing SKU blocks; no fuzzy matching |
| Oracle release snapshot | exact source SKU | `product_source_mappings` | organization + source system + source code | More than one Product blocks as ambiguous |
| Validated E5 config | operation code/name | `operations` | organization + code | Existing exact key retained |
| Validated E5 config | standard route/revision | `routings` | organization + code + revision | Existing exact key retained |
| Validated E5 config | route sequence + operation | `routing_operations` | routing + sequence | Active revisions are never mutated |
| Oracle `GROUP_CODE` | `DTG_1/DTG_2 -> DTG`, `UNDERPRINT -> UNDERPRINT` | `product_routing_assignments` | organization + Product + process | Unsupported process remains unresolved |
| Validated E6.3 config | exact queue/location code | `source_operational_code_mappings` | organization + system + dataset + field + code | Exact-match only |

All imported Products remain Family/Type `UNMAPPED` until separately reviewed; Product classification was not fabricated.

## Export package

Location: `canonical-data/product-routing/`

- Manifest: `PRODUCT_ROUTING_REFERENCE_MANIFEST.json`
- Datasets: 10
- Reference rows: 3,940
- Each dataset includes source authority, destination, natural key, transformation rule, row count, and SHA-256 checksum.

| Dataset | Rows |
| --- | ---: |
| Product families | 6 |
| Product types | 3 |
| Production processes | 6 |
| Operations | 6 |
| Routings | 3 |
| Routing operations | 10 |
| Operational-code mappings | 15 |
| Products | 1,526 |
| Product source mappings | 1,526 |
| Product routing assignments | 839 |

## Import and idempotency

| Metric | First import | Second import |
| --- | ---: | ---: |
| Products | 1,526 | 1,526 |
| Product mappings | 1,526 | 1,526 |
| Operations | 6 | 6 |
| Routings | 3 | 3 |
| Routing steps | 10 | 10 |
| Product-routing assignments | 839 | 839 |
| Operational-code mappings | 15 | 15 |

Second-import duplicate/delta count: 0. Duplicate Products, mappings, and assignments: 0.

## Released-line coverage

| Classification | Lines |
| --- | ---: |
| Released lines | 5,768 |
| Product mapped | 5,768 |
| Product unresolved | 0 |
| Product ambiguous | 0 |
| Routing resolved | 4,438 |
| Routing unresolved | 1,330 |
| Routing ambiguous | 0 |

## Routing breakdown

| Source group | Process | Routing | Lines |
| --- | --- | --- | ---: |
| DTG_2 | DTG | DTG_STANDARD | 3,073 |
| DTG_1 | DTG | DTG_STANDARD | 863 |
| UNDERPRINT | UNDERPRINT | UNDERPRINT_STANDARD | 502 |
| UV PRINT | UV | UNRESOLVED / not yet supported | 489 |
| STICKERS | STICKERS | UNRESOLVED / not yet supported | 489 |
| HATS | HATS | UNRESOLVED / not yet supported | 271 |
| PROD | PRODUCTION | UNRESOLVED | 44 |
| FINISHED | FINISHED_GOODS | NO MO routing assigned | 27 |
| CUSTOM EMB | CUSTOM_EMB | UNRESOLVED | 8 |
| VISUAL | VM | UNRESOLVED / not yet supported | 2 |

No current released line or Workbank row supplied PAK7 evidence, so Screen Print Routing exists but has zero current assignments from this snapshot. The validated mapping remains `PAK7 -> SCREEN_PRINT`.

## Current operational-code observations

- SP11: 1,633 rows / 53 orders -> DTG / current supported process
- PAK1: 10 rows / 5 orders -> Underprint / current supported process
- HOLD: 15 rows / 4 orders -> non-applicable blocker state
- PAK2/3/4/5/6/7/9 and dispatch codes remain configured but had zero current Workbank rows in this snapshot.

## Validation

- Canonical Routing tests: 26/26 PASS
- Canonical release/E6 lifecycle tests: 39/39 PASS
- Total canonical SQL assertions: 65/65 PASS
- Application tests: 177/177 PASS
- Lint: PASS
- Typecheck: PASS
- Build: PASS
- Production Demand: 0
- Manufacturing Orders: 0
- MO lines: 0

The legacy E5 bootstrap test that requires `bootstrap_phase_e5_master_data(uuid)` is superseded by the deterministic reference package and is intentionally not part of the clean-baseline canonical suite.

## Remaining scope

Product reference coverage is complete for the current released snapshot. Routing coverage is complete only for approved supported processes DTG and Underprint. The 1,330 released lines in unsupported/unresolved processes remain visible and must not create canonical Demand until their Routing contracts are separately approved.

