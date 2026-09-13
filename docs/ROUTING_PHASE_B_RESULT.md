# Routing Architecture Phase B

Phase B introduces the expected-process definition without changing current execution authority.

## Included

- Routing Master with code, revision, status and effectivity.
- Ordered Routing Operations linked to canonical Operations and optional Work Centers.
- Product default Routing assignment.
- Initial DTG, Underprint and Screen Print route definitions.
- Organization isolation, RLS and administrative permissions.
- Compact ordered-table Routing editor.

## Boundaries

- No Production Orders or operation snapshots until Phase C.
- No source-event resolver or deviation engine until Phase D.
- No Flow, KPI, Planning or Capacity authority switch.
- No BOM/MRP or competing WMS stock behavior.
- No production migration execution or deployment in this branch.

- Audit trail reuses maintenance_audit_log for routing revisions, routing operations and product routing assignments.
