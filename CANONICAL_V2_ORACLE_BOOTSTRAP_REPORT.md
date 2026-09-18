# Canonical V2 Oracle Bootstrap Report

## Result

Phase C4 stopped at the pre-connection hard gate. No Oracle connection or ingestion was attempted because the current connector does not carry the authoritative line-level release signal required by the approved contract.

**CANONICAL V2 ORACLE BOOTSTRAP BLOCKED — AUTHORITATIVE RELEASE FIELD IS NOT PRESENT IN THE SYNC CONTRACT**

## Environment identity

- V2: `saecycamkyvzzppxudzq` — `ACTIVE_HEALTHY`
- Production: `gdajktoqmajipivpdude` — `ACTIVE_HEALTHY`, untouched
- DEV: `tlflipdeahgwsueerkex` — `INACTIVE`, untouched
- Worktree: `C:\Projects\tsd-canonical-v2`
- Branch: `canonical-v2`

## Oracle read-only audit

All executable Oracle paths in `apps/oracle-sync` were inspected. The connector opens an Oracle connection and executes only `SELECT` statements through `connection.execute`. The statements cover connectivity (`DUAL`), orders, release-line candidates, Workbank, stock, audit events, inspection counts and bounded audit backfill reads.

- Oracle SELECT paths: identified
- Oracle write paths: 0
- Oracle stored procedure calls: 0
- Oracle connection attempted in C4: no
- Oracle credentials loaded in C4: no
- Oracle writes: 0

## Required source contract

| Oracle source | Required V2 destination | Grain | Natural/upsert key | Quantity | Date | Release |
| --- | --- | --- | --- | --- | --- | --- |
| `IS_ORDER_VIEW_SALE_V` + `IS_ORDER_HEAD` | `source_orders` | Sales Order | `organization_id, order_no` | n/a | received/due/released/source updated | header evidence only |
| `IS_ORDER_LINE` + `IS_ORDER_HEAD` + `IS_PRODUCT` | `source_release_order_lines` | Sales Order Line | `organization_id, order_no, line_number` | `QTY_LCD` | `SOURCE_UPDATED_AT` | not currently selected |
| `IS_ORDER_LINE` | `source_order_release_lines` | authoritative Sales Order Line | `organization_id, source_system, source_order_no, source_line_id` | authoritative line units | source updated | **`IS_ORDER_LINE.RELEASED` required** |
| `IS_WORKBANK_V` | `source_workbank_items` | Workbank row | `organization_id, source_row_id` | mapped QTY/WEIGHT | due | none |
| `IS_STOCK_V` | `source_stock_items` | stock pack/location | `organization_id, product, pack_id, location` | mapped QTY/WEIGHT | source timestamp | none |
| `ISIS_AUDIT` + `IS_PRODUCT` | `source_audit_events` | audit event | `organization_id, source_audit_id/raw_hash` | mapped production units | event timestamp | none |

The current working window is open orders for headers, active site-B `13%` order lines due from `SYSDATE-30` through `SYSDATE+30`, production-relevant Workbank zones, TSD underprint/PWL1 stock, and audit rows after the persisted audit cursor.

## Exact blocker

The release-line query selects `ORDER_NO`, `LINE_NUMBER`, product/client fields, `QTY_LCD`, `ORIG_REF3`, Product Group/Name and source timestamp. It does **not** select `IS_ORDER_LINE.RELEASED`.

The shared `releaseOrderLineSchema` and `mapReleaseOrderLine` also contain no release value. `syncOnce` posts this incomplete shape to `/api/ingest/sync`, and `ingest_sync_batch` replaces `source_release_order_lines`; it does not populate the authoritative `source_order_release_lines` table. Although `ingest_authoritative_release_lines` exists in the database, the connector/API path does not call it and cannot provide its required release value.

Running the bootstrap would therefore create line data without the approved release authority and make release reconciliation impossible. Release must not be inferred from MO existence, Routing, status text, picking or production activity.

## Pre-bootstrap V2 snapshot

| Dataset | Rows |
| --- | ---: |
| `source_orders` | 0 |
| `source_release_order_lines` | 0 |
| `source_order_release_lines` | 0 |
| `source_workbank_items` | 0 |
| `source_stock_items` | 0 |
| `source_audit_events` | 0 |
| `production_events` | 0 |
| `production_demand_lines` | 0 |
| `production_orders` | 0 |
| `manufacturing_order_lines` | 0 |
| `sync_batches` | 0 |

Master/config remains 273 rows from C3.2.

## Bootstrap and validation status

- Pass 1: not run
- Pass 2: not run
- Pass 3: not run
- Oracle rows imported: 0
- Production Demand delta: 0
- MO delta: 0
- MO line delta: 0
- Derived contamination: 0
- C4 regression: not run because the hard gate stopped before implementation/execution
- Last validated C3.2 state remains: Routing 26/26, application 176/176, lint/typecheck/build PASS

## Required resolution before retry

Add the authoritative `IS_ORDER_LINE.RELEASED` value to the Oracle SELECT, mapping and shared ingestion contract, and route it to `source_order_release_lines` using its validated line grain and idempotent snapshot semantics. This must be implemented and tested without activating Production Demand, MO or release lifecycle derivation. After that contract is proven, C4 can restart from the pre-bootstrap snapshot.


## Phase C4.1 - Authoritative Oracle release ingestion

### Root cause

`IS_ORDER_LINE.RELEASED` was absent at three layers: the Oracle release-line SELECT, the TypeScript transformation/payload contract, and the `ingest_sync_batch` orchestration. The V2 table `source_order_release_lines` already had `released` and `raw_release_value`, so no table-column change was required.

### Contract

- Oracle field: `IS_ORDER_LINE.RELEASED` (`VARCHAR2`)
- Canonical grain: `ORDER_NO + LINE_NUMBER`
- `Y` -> `released = true`
- `N` -> `released = false`
- NULL/other -> `released = null`, raw source value retained
- Oracle write paths: 0

### V2 baseline replay

The updated ingest function and authenticated RLS DML grants were incorporated into `001_canonical_baseline.sql`. Only disposable project `saecycamkyvzzppxudzq` was replayed. DEV remained inactive and production remained active and untouched. The exact master-config package was restored twice: 273/273 rows, second-import delta 0.

### Controlled bootstrap

The three passes used the same Oracle release-line scope and V2 target. Historical audit backfill was intentionally excluded by starting at observed `MAX_AUDIT_ID = 12779175`; this avoids materializing 12.7 million historical events and does not change the order-line bootstrap scope.

| Metric | Pass 1 | Pass 2 | Pass 3 |
| --- | ---: | ---: | ---: |
| Source orders | 1,149 | 1,149 | 1,149 |
| Source order lines | 23,477 | 23,477 | 23,477 |
| Released Y | 5,768 | 5,768 | 5,768 |
| Released N | 17,709 | 17,709 | 17,709 |
| NULL release | 0 | 0 | 0 |
| Invalid release | 0 | 0 | 0 |
| Partially released orders | 90 | 90 | 90 |
| Duplicate order + line | 0 | 0 | 0 |
| Production Demand | 0 | 0 | 0 |
| Manufacturing Orders | 0 | 0 | 0 |
| MO lines | 0 | 0 | 0 |

### Reconciliation

- Source lines: 23,477
- V2 lines: 23,477
- Missing V2 keys: 0
- Extra V2 keys: 0
- Release mismatches: 0
- Quantity mismatches: 0
- Source quantity: 100,533
- V2 quantity: 100,533
- Unexplained quantity difference: 0

### Validation

- Release-ingestion SQL: 10/10 PASS
- Canonical routing/lifecycle/RLS SQL: 65/65 PASS
- Application tests: 177/177 PASS
- Lint: PASS
- Typecheck: PASS
- Production build: PASS
- DEV: untouched
- Production: untouched
- Oracle: read-only and untouched
