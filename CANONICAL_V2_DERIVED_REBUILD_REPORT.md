# Canonical V2 Derived Rebuild Report

## Phase C5.2 result

**BLOCKED BEFORE DERIVED WRITES**

Target identity was positively verified as Canonical V2 project `saecycamkyvzzppxudzq`, worktree `C:\Projects\tsd-canonical-v2`, branch `canonical-v2`. DEV (`tlflipdeahgwsueerkex`) and production (`gdajktoqmajipivpdude`) were not modified. Oracle remained read-only.

## Frozen source baseline

| Metric | Count |
| --- | ---: |
| Source order lines | 23,477 |
| Released Y | 5,768 |
| Released N | 17,709 |
| Product mapped | 5,768 |
| Routing resolved | 4,438 |
| Routing unresolved | 1,330 |
| Routing ambiguous | 0 |

## Eligibility gate

All 4,438 Routing-resolved candidates fail the canonical positive-quantity eligibility rule.

| Supported source group | Lines | Lines with positive quantity | `production_units` | `qty_lcd` |
| --- | ---: | ---: | ---: | ---: |
| DTG_1 | 863 | 0 | 0 | 0 |
| DTG_2 | 3,073 | 0 | 0 | 0 |
| UNDERPRINT | 502 | 0 | 0 | 0 |
| **Total** | **4,438** | **0** | **0** | **0** |

`production_demand_lines.quantity` is constrained to be greater than zero. No approved alternative quantity exists in the authoritative release-line contract. Substituting Workbank process quantity, order-header quantity, SKU defaults, or an inferred value would violate source provenance and quantity conservation.

| Metric | Count |
| --- | ---: |
| Routing-resolved candidates | 4,438 |
| Eligible after all canonical rules | 0 |
| Production Demands created | 0 |
| Active Production Demands | 0 |
| Active Demand mappings | 0 |
| Manufacturing Orders | 0 |
| MO lines | 0 |
| Canonical MO quantity mismatch | 0 |

No first derived rebuild was executed because its eligible set is empty. Consequently a second rebuild would not prove Demand/MO idempotency and was not presented as a successful rebuild.

## Negative controls

| Control | Result |
| --- | ---: |
| Active demand from 17,709 Released=N lines | 0 |
| MO lines from Released=N | 0 |
| Active demand from Routing-unresolved lines | 0 |
| Duplicate Demand natural-key groups | 0 |
| Quantity contributed by unresolved Routing | 0 |

Partial-release safety remains line-scoped through `ORDER_NO + LINE_NUMBER`; no Sales Order-level release promotion was used.

## Unsupported Routing exceptions

All 1,330 released Product-mapped lines without canonical Routing remain controlled source exceptions. The complete row-level export is `canonical-data/derived/C52_UNSUPPORTED_ROUTING_EXCEPTIONS.csv`.

| Source group | Classification | Lines | Source quantity |
| --- | --- | ---: | ---: |
| UV PRINT | UNSUPPORTED_ROUTING | 489 | 2,192 |
| STICKERS | UNSUPPORTED_ROUTING | 489 | 4,676 |
| HATS | UNSUPPORTED_ROUTING | 271 | 0 |
| PROD | MISSING_MO_ROUTING | 44 | 3,469 |
| FINISHED | NON_PRODUCTION / FINISHED | 27 | 0 |
| CUSTOM EMB | CUSTOM_EMB_UNSUPPORTED | 8 | 0 |
| VISUAL / VM | UNSUPPORTED_ROUTING | 2 | 0 |
| **Total** |  | **1,330** | **10,337** |

These are not Product Mapping failures. No UV, Stickers, Hats, Finished Goods, VM, or Custom Emb Routing was added.

## Release Queue, Machine Load and Product Mix

Canonical executable Demand is empty because eligible positive-quantity Demand is empty. The unresolved 1,330 lines contribute zero to active load, backlog, capacity, productivity, and ready-to-print Product Mix. Existing source/informational Release Queue views are not reclassified as canonical executable state.

## Root cause and required prerequisite

The Oracle release snapshot proves line-level release and Routing context, but the current payload does not carry a positive authoritative production quantity for any supported DTG or Underprint line. C5.2 cannot safely build Demand or MOs until the source ingestion contract supplies a deterministic, auditable quantity for these lines.

The next action is a quantity-authority investigation limited to the Oracle source contract. It must identify the exact line-level quantity field and semantics without writing to Oracle and without deriving quantity from unrelated Workbank totals.

## Final gate

**CANONICAL V2 DERIVED REBUILD BLOCKED — authoritative positive quantity is absent for all 4,438 Routing-resolved released lines**

## Validation

| Suite | Result |
| --- | --- |
| Application tests | 177/177 PASS |
| Canonical release ingestion | 10/10 PASS |
| Routing Phase B-E SQL | 26/26 PASS |
| E5/E6 legacy SQL | FAIL - legacy contracts absent from clean V2 baseline |
| Release Queue application rules | PASS within 177/177 |
| Machine Load application rules | PASS within 177/177 |
| Product Mix application rules | PASS within 177/177 |
| Lint | PASS |
| Typecheck | PASS when run after build generation; initial parallel run had a `.next/types` race |
| Production build | PASS |

The E5/E6 legacy runner first requires `bootstrap_phase_e5_master_data(uuid)` / legacy Task coverage, then requires `resolve_source_operational_context(uuid,text,text,text)`. These superseded contracts were intentionally not copied into the clean Canonical V2 baseline. Reintroducing them solely to satisfy legacy tests would violate the clean-baseline rule. This is a test-contract compatibility blocker, not evidence that the established release or Routing rules are wrong.
