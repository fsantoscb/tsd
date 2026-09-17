# Machine Load Product Mix Implementation

## Scope

ML-MIX2 adds an informational product-family view to `/production/machine-load`. It does not change active load, backlog, capacity, utilisation, productivity, scheduling, Production Demand, Manufacturing Orders, release lifecycle, Oracle data, or Supabase schema.

## Sources and semantics

- `WAITING_FOR_PICKING`: active `SP11` Workbank rows using physical `source_qty`.
- `READY_TO_PRINT`: active `PCOR` Workbank rows using physical `source_qty`.
- `NOT_APPROVED_INFORMATIONAL`: ML-NA2 Release Queue rows using `process_quantity`.

Physical garment quantity and process quantity remain separate. Not Approved values are never added to active load. A matching active Sales Order plus SKU suppresses its potential presentation to prevent duplicate display.

## Classification

The implementation reuses the existing `extractProductType` and `classifyProductType` resolver. Unknown values remain visible as `Unclassified / Other`; no fuzzy or new product inference was introduced.

## Filters and drilldown

The view follows Machine Load due date, customer, order, priority, site, mix group, and product type filters. Not Approved appears only when `Show Not Approved` is enabled. Each family expands to SO/line, product, state, quantity semantics, and due date.

## Safety

- No migration or database write.
- No new dependency.
- Oracle remains read-only.
- Existing operational calculations are unchanged.
- Dedicated tests cover state separation, deduplication, overlap protection, classification, reconciliation, semantics, and source immutability.
