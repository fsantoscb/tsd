# ERP production architecture

The target production model separates intent from evidence.

Product Master -> Routing Master -> Routing Operations -> Production Order -> Production Order Operations -> Source validation.

`production_orders` is the transitional physical name for the Manufacturing Order execution header. The authoritative grouping rule is: ONE SO + ONE ROUTING = ONE MO. DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO. Product detail is retained in Manufacturing Order lines.

Phase A establishes Product Families, Product Types, Products, Operations, Work Centers, Production Resources and source-product mappings. Routing and production-order entities are intentionally deferred.

Oracle and WMS values describe observed source state. They never become canonical operation codes. WMS remains authoritative for inventory and materials.

## Boundary

BOM STATUS = FUTURE / STANDBY.

No BOM explosion, MRP, material allocation, reservation, stock ledger, shortage calculation or purchase recommendation is part of this architecture phase.

## Manufacturing Order boundary

ONE SO + ONE ROUTING = ONE MO.

DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.

A Sales Order may create multiple Manufacturing Orders. Product composition remains on manufacturing_order_lines, while each MO owns exactly one immutable Routing revision and its operation snapshot. production_orders is the transitional physical table name for Manufacturing Orders.
