# Implementation Plan
- Phase 0: complete and validated.
- Phase 1: complete and validated against live Oracle and Supabase.
- Phase 2: complete and validated.
- Phase 3: complete and validated.
- Phase 4: complete and validated against live operational data.
- Phase 5: complete and validated against the live Supabase planning queue.
- Phase 6: complete and validated with live Supabase schema, transactional lifecycle acceptance, authenticated UI, typecheck and production build.
- Phase 7: complete and validated with configurable profiles, dynamic scenarios, live workload comparison, cross-midnight attribution, tests, typecheck, lint and production build.
- Phase 8: implementation in progress; governed schema and centralized quality/threshold rules prepared, catalogue and dashboard pending.
- Phase 8 dashboard: production-performance redesign implemented with global filters, executive KPIs, process comparison, capacity, SLA, labour, mix, risk, trends, separated data health and governed null handling. Machine telemetry and shift-resource detail remain source-data gaps.
- Phases 9-10: not started.
- Routing Architecture Phase A: canonical Product Family, Product Type, Product, Product Source Mapping, Operation, Work Center and Production Resource foundations implemented on a dedicated feature branch. Phase B Routing Master is not started.

Phase 0 includes the monorepo, responsive Next.js shell, Tailwind, Supabase clients, auth skeleton, environment validation, disconnected connector skeleton, shared contracts, tests, and documentation.

Phase 1 includes atomic sync migrations, source snapshot tables, append-only audit ingestion, heartbeat, protected ingest endpoints, and connector commands.

Phase 2 includes authenticated source views, source reconciliation, source-data exploration and connector status.

Phase 3 includes configurable production areas, stage mappings, quantity conversion rules, order-stage summaries, aged orders and explicit UNMAPPED handling.

Phase 4 includes read-only UP and DTG workbanks, Oracle-aligned filters, search, pagination, putwall visibility, operational balance/progress, and order drill-down across order, workbank, stock and audit data.

Phase 8 prerequisite documentation defines the complete KPI Engine. `KPI_DATA_READINESS.md` is the gate for calculation work; KPIs require authoritative sources, approved formulas, tests and reconciliation before activation.

## Maintenance Manager
- Phase 0-2: published foundation, authenticated shell, asset registry and asset status visibility.
- Phase 3: in progress. Corrective reporting, automatic downtime, controlled work-order transitions, cancellation reason, detail view and status/downtime history implemented. Comments, labour and attachments remain.
- Phase 4: pending. Preventive plans, checklists and idempotent generation.
- Phase 5: pending. Parts inventory and work-order consumption.
- Phase 6: pending. Maintenance KPIs and reports.
- Phase 7: pending. QR, mobile workflow and PWA.
- Phase 8: pending. RLS hardening, accessibility, performance and production acceptance.

## Maintenance delivery status
- Phase 3 complete: corrective work, downtime, history, comments, labour and private attachments.
- Phase 4 complete: preventive plans, frozen checklists and idempotent generation.
- Phase 5 complete: transactional parts inventory and work-order consumption.
- Phase 6 complete: dashboard, period reports and CSV export.
- Phase 7 complete: QR labels, scan route, mobile reporting and PWA integration.
- Phase 8 in progress: role enforcement, audit log, indexes, loading/error states and accessibility.
- Asset naming standard: configurable prefixes, atomic permanent codes, component hierarchy, lifecycle metadata, expanded search, QR identity and non-destructive reconciliation.
- Production Flow KPI: independent DTG/UP/Screen Print process model, governed source mappings, stage KPIs, freshness, capacity load, clearance and manual Screen Print workflow implemented.
# Routing Phase B checkpoint

- Routing Master, revision and effectivity schema.
- Ordered Routing Operations with optional Work Center and capacity references.
- Product default Routing assignment.
- Initial DTG, Underprint and Screen Print routing configuration.
- Admin Routing editor and validation rules.
- Phase C Production Execution remains pending explicit approval.

## Routing Architecture Phase B - 2026-09-13

Status: implemented on `feature/routing-architecture` and awaiting database migration/promotion.

Delivered:
- revision-controlled Routing Master;
- ordered Routing Operations;
- optional Work Center, setup, run-rate and queue parameters;
- Product default Routing assignment;
- seeded DTG, Underprint and Screen Print routing revisions;
- organization isolation and role-controlled administration;
- compact Routing editor at `/admin/routings`.

Boundaries preserved:
- no Production Orders or execution snapshots yet;
- no source-event validation or routing deviations yet;
- no Flow/KPI/Planning/Capacity authority switch;
- no BOM/MRP or competing WMS behavior;
- no production migration or deployment from this branch.

Next controlled phase: Phase C - Production Orders and immutable Production Order Operation snapshots.
