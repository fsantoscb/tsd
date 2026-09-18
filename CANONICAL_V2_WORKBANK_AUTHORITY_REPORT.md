# Canonical V2 Workbank Operational Authority Report

## Phase C5.2C Part A result

**WORKBANK AUTHORITY: NOT PROVEN**

Part A stopped at the authority gate. Parts B and C were not executed. No Production Demand, Demand Mapping, Manufacturing Order, MO line, schema, fixture, Oracle, DEV, production, or V2 derived write occurred.

## Actual Workbank source

| Attribute | Proven value |
| --- | --- |
| Source system | Oracle/WMS |
| Source object | `IS_WORKBANK_V` |
| Reader | `apps/oracle-sync/src/source-reader.ts` Workbank query |
| Persisted object | `source_workbank_items` |
| Current-state view | `v_current_workbank`, latest completed sync batch |
| Source key | `WB_ROWID` persisted as `source_row_id` |
| Quantity inputs | `QTY`, `WEIGHT`, `PACKDESC`, `FROM_ZONE` |
| Quantity formula | `WEIGHT` for CARTON or PWL1; otherwise `QTY`; null becomes zero |
| Process evidence | `QUEUE`, `WK_QUEUE`, `ISIS_TASK`, zones and locations |
| Source filters | Active order heads and approved PG11/DTGS/PG01/PG1H/PG1A/PG1D/PWL1 operational zones |
| Refresh contract | Current completed Oracle sync snapshot; configured recurring connector interval |
| Provenance | Sync batch + source row ID + Oracle operational fields |

## Quantity semantics

Classification: **CURRENT_OPEN_PROCESS_QUANTITY**.

The working ERP uses Workbank quantities for current DTG/Underprint operational screens, Machine Load, Flow, ready-to-lift, and Product Mix. The quantity changes with current operational location/queue and completed work may move or disappear from the current snapshot.

It is not original ordered quantity, original released quantity, immutable physical garment quantity, or historical production quantity.

## Canonical grain analysis

The only unexplained-duplicate-free source grain is Oracle `WB_ROWID` / V2 `source_row_id`.

| Candidate grain | Result |
| --- | --- |
| `source_row_id` | 8,323 current rows; duplicate keys 0 |
| Order + product + queue + zone/location | 1,425 duplicate groups |
| Order + line | Impossible: Workbank has no Sales Order line number |
| Order + line + process | Impossible: Workbank has no Sales Order line number |

Therefore Workbank has a valid operational-row grain, but no proven canonical bridge to `ORDER_NO + LINE_NUMBER` release identity.

## Join to released population

Join used only the strongest common available fields: `ORDER_NO + source SKU/product`.

| Metric | Result |
| --- | ---: |
| Released Y | 5,768 |
| Routing-resolved | 4,438 |
| Exact single Workbank match | 0 |
| Multiple Workbank matches | 0 |
| No Workbank match | 4,438 |
| Positive matched quantity lines | 0 |
| Positive matched quantity | 0 |
| Zero matched quantity | 0 |
| Null matched quantity | 0 |

Even order-only matching returned zero for all 4,438 lines in the current snapshot. This is legitimate for release records not yet represented as current open Workbank, but it prevents Workbank from serving as the quantity authority for those release lines.

## Routing/process alignment

| Classification | Lines |
| --- | ---: |
| PROCESS_MATCH | 0 |
| PROCESS_MISMATCH | 0 |
| PROCESS_NOT_AVAILABLE / no join | 4,438 |

Workbank did not override canonical Routing.

## Multi-process safety

No line-level Workbank match exists, so DTG/Underprint process contribution cannot be proven at released-line grain. Workbank operational duplicates also exist at collapsed business keys.

**MULTI_PROCESS_DOUBLE_COUNT_RISK: unresolved grain/linkage issue.**

Summing rows into a release line or across processes would risk duplicating current operational work. It is not approved.

## Unreleased and partial-release controls

- Released=N lines: 17,709.
- Unreleased lines with a positive exact `ORDER_NO + SKU` Workbank match: 0.
- Partially released Sales Orders: 90.
- Line-specific release identity remains mandatory.
- Because Workbank cannot link to line identity, no Y-line quantity was promoted and no N-line quantity contributed.

## PROD reconciliation

V2 and PROD read-only contain the same current Workbank aggregate:

| Environment | Rows | Quantity | Queue/zone groups |
| --- | ---: | ---: | ---: |
| V2 | 8,323 | 13,296 | 8 |
| PROD | 8,323 | 13,296 | 8 |

This proves source ingestion parity at aggregate current-state level. It does not prove release-line quantity authority.

## Three-snapshot stability

| Snapshot | Workbank rows | Positive quantity |
| --- | ---: | ---: |
| Latest | 8,323 | 13,296 |
| Previous | 0 | 0 |
| Third | 0 | 0 |

Three comparable populated snapshots are not available. Changes cannot be classified reliably as unchanged, increased, decreased, removed, or new. The stability gate therefore fails independently of the join gate.

## Gate assessment

| Required proof | Result |
| --- | --- |
| Exact source known | PASS |
| Quantity semantics known | PASS |
| Canonical operational-row grain known | PASS |
| Join to released line proven | **FAIL** |
| Process relationship understood at line grain | **FAIL** |
| No unexplained double-count | **FAIL** |
| PROD current aggregate reconciliation | PASS |
| Three-snapshot behavior proven | **FAIL** |

## Derived state

| Metric | Result |
| --- | ---: |
| Eligible for Demand | 0 |
| Production Demands | 0 |
| Active Demand Mappings | 0 |
| Manufacturing Orders | 0 |
| MO lines | 0 |
| Active Demand from Released=N | 0 |
| Active Demand from Routing-unresolved | 0 |
| Fixture residue | 0 |

No operational quantity contract was adopted. Existing schema was not changed.

## Final gate

**CANONICAL V2 OPERATIONAL DEMAND BLOCKED — WORKBANK AUTHORITY NOT PROVEN**
