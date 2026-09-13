# MO grouping reconciliation

`v_mo_grouping_reconciliation` compares each Sales Order's canonical demand lines with generated Manufacturing Orders.

It exposes Sales Order, source line count, resolved Routing count, expected MO count, actual MO count, MO difference, expected quantity by Routing and actual MO quantity.

Acceptance requires zero MO-count difference and quantity parity per Routing. Unmapped lines remain visible as setup exceptions and never produce malformed MOs.

## Local checkpoint

| Measure | Result |
|---|---:|
| Legacy headers | 0 |
| Routed headers without lines | 0 |
| Canonical demand lines | 0 |
| Canonical MOs | 0 |
| Grouping differences | 0 |

The local schema and automated fixtures reconcile. Operational reconciliation is pending real canonical source-line ingestion; an empty dataset is not presented as production-data parity.
