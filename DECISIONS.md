# Architecture Decisions
- Oracle remains read-only and authoritative for source operational data.
- The browser never connects to Oracle; a local connector pushes HTTPS batches.
- Every external identifier is a string.
- Raw quantity and weight remain separate from configurable production units.
- Imported source data remains separate from planner-owned data.
- Oracle credentials are loaded from Windows Credential Manager target TSDPROD_KPI_ORACLE and never persisted in project files.
- The provisional production-unit rule is WEIGHT when present, otherwise QTY; reconciliation must approve it before pilot use.
- Maintenance asset codes are permanent database-generated identifiers; existing codes are never rewritten automatically.
- Tracked components use parent relationships and independent lifecycle records; consumables remain parts inventory.
- DTG, Underprint and Screen Print are independent production processes; Screen Print remains explicitly manual until an authoritative source exists.
- `/kpis` is the production-performance management surface and does not reproduce Flow stage navigation. It consumes existing server domain sources through one shared `KpiFilter`.
- KPI widgets preserve null semantics. Missing target, labour, capacity or machine telemetry is never converted to zero or substituted with another measure.
- Cumulative plan pacing is a labelled display allocation across selected buckets; the authoritative period target remains the published production plan total.
- Routing architecture separates canonical production intent from Oracle/WMS observations. Phase A adds master-data foundations without replacing legacy stage logic.
- BOM/MRP remains FUTURE / STANDBY and WMS remains authoritative for stock and materials.
- Production Orders reuse the existing planning record and gain execution fields non-destructively. A routed order freezes its Routing revision and ordered operation definitions at creation; later Routing Master changes never rewrite historical execution.
- Production execution extends the existing planning-owned `production_orders` identity. Routed orders freeze Routing and Operation definitions at creation; historical orders never resolve their execution path dynamically from the mutable Routing Master.
## Routing source validation

- Routing defines expected execution; Oracle/WMS records are deterministic evidence of actual execution.
- Historical Production Order routing snapshots are immutable and never rewritten to match observed source behavior.
- Ambiguous or out-of-sequence evidence creates a routing exception rather than an inferred process change.
- Source values such as SP11, PCOR, PWL1, DTGMOVE and UPMOVE belong only in configurable source mappings.
