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

## Formal pre-Phase-C review

The review added database-enforced safeguards for immutable active/inactive revisions, draft-only routing-operation edits, valid routing status transitions, active/effective product routing assignment, and protected operation deactivation. Routing revision cloning and operation reordering are transactional PostgreSQL functions. A transactional database/RLS smoke suite is available at `supabase/tests/routing_phase_b.sql`.

Phase B validation is complete against the local Supabase development stack. A clean database reset applied every migration through `202609130007_routing_phase_b.sql`; the routing SQL/RLS integration suite passed creation, revision cloning, operation ordering, permitted deactivation, product assignment, historical snapshot immutability, organization isolation and unauthorized-role rejection.

Final gates passed: lint, typecheck, 130 unit tests, database/RLS tests and production build. Two pre-existing migration bootstrap defects were corrected during the clean reset: the monthly KPI interval literal and self-only membership visibility required by authenticated RLS policies. Production Supabase was not accessed or modified.
