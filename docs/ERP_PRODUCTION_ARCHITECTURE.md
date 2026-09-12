# ERP production architecture

The target production model separates intent from evidence.

Product Master -> Routing Master -> Routing Operations -> Production Order -> Production Order Operations -> Source validation.

Phase A establishes Product Families, Product Types, Products, Operations, Work Centers, Production Resources and source-product mappings. Routing and production-order entities are intentionally deferred.

Oracle and WMS values describe observed source state. They never become canonical operation codes. WMS remains authoritative for inventory and materials.

## Boundary

BOM STATUS = FUTURE / STANDBY.

No BOM explosion, MRP, material allocation, reservation, stock ledger, shortage calculation or purchase recommendation is part of this architecture phase.
