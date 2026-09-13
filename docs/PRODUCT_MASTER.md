# Product Master

Product Families and Product Types are configurable organization-owned classifications. Products are unique by organization and SKU, may remain explicitly unmapped, and may reference a future default routing.

Product source mappings resolve a source system and source product code to one canonical product. Raw Oracle descriptions are not duplicated or parsed in React components.

BOM STATUS = FUTURE / STANDBY. WMS remains authoritative for stock.

## Manufacturing demand

Product resolution happens per source Sales Order line. Product detail is retained in production_demand_lines and manufacturing_order_lines, even when several products share one Manufacturing Order because they resolve to the same Routing.

ONE SO + ONE ROUTING = ONE MO.

DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.

Products resolve Routing at the source-line level. Multiple products may share one Manufacturing Order only when they belong to the same Sales Order and resolve to the same effective Routing. Product identity and quantity remain preserved in `manufacturing_order_lines`.
