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

Application validation passed: lint, typecheck, 130 unit tests and production build. Database/RLS execution remains pending because this workstation currently has neither Supabase CLI nor Docker and no separate development Supabase project is configured. Production Supabase was not touched. Phase C must not start until that isolated database gate passes.
