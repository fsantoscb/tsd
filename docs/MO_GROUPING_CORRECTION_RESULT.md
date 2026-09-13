# MO grouping correction result

## Authoritative rule

ONE SO + ONE ROUTING = ONE MO.

DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.

## Correction

The previous execution header supported one product and one order identity but had no canonical source-line layer or database grouping contract. The corrected model adds demand lines, MO lines, deterministic grouping, line/header integrity, quantity roll-up, idempotency and post-start quantity exceptions.

`production_orders` remains the physical table and represents Manufacturing Orders for routed records. Legacy planning records remain compatible and are not rewritten.

## Schema and behaviour

- `production_demand_lines` preserves source-line and product identity.
- `manufacturing_order_lines` preserves product mix below one MO.
- One database key protects `organization + source system + SO + Routing revision + split`.
- Routing operations are copied by the existing immutable snapshot trigger.
- Pending/released quantity changes update the line and canonical header total.
- In-progress quantity changes create `SOURCE_QUANTITY_CHANGE` without rewriting history.
- Unresolved lines remain outside MO creation and can be represented by demand exceptions.
- `v_mo_grouping_reconciliation` provides the release gate.

## Existing records

Existing records are not destructively regrouped. Headers without source lines are `MISSING_SOURCE_LINE_DATA` until explicitly reconciled.

## Phase readiness

Local validation passed:

- lint: PASS
- typecheck: PASS
- unit tests: PASS, 133 tests
- database/RLS tests: PASS, 48 tests including 17 MO scenarios
- production build: PASS, 46 routes
- local schema reconciliation: PASS, no existing canonical records required regrouping

Operational data reconciliation remains pending because the local source-line/MO dataset is empty. The next routing migration remains blocked pending explicit approval. Flow, Planning, Capacity and KPI logic are unchanged by this package.

## Unresolved

- Oracle sync currently imports order/workbank/stock/audit snapshots, not canonical Sales Order line identifiers suitable for production_demand_lines.
- The line-ingestion adapter must supply a stable string source_order_line_id before operational MO generation is enabled.
- Existing legacy planning records remain outside the MO line model until deliberately reconciled.

ONE SO + ONE ROUTING = ONE MO.

DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.
