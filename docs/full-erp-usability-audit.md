# Full ERP usability audit

Date: 13 September 2026

## Scope and environment

Audit of TSD Production Control as operator, maintenance technician, supervisor, manager and admin. Static and automated checks ran locally. Browser checks used the authenticated production site. No mutating test was executed against real assets or inventory.

## Results and findings

| Severity | Area | Finding | Status |
|---|---|---|---|
| CRITICAL | Control tower | Root page performed full machine-load and dispatch reads and failed under production volume | Fixed in source |
| HIGH | Navigation | Extended authenticated route sweep eventually received HTTP 413 | Open |
| HIGH | KPI dashboard | Initial render previously performed excessive transactional reads | Fixed and deployed previously |
| MEDIUM | Build | Local build lacks NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY | Environment issue |
| CRITICAL | Test safety | No isolated E2E tenant or disposable fixture set was identified | Open |
| MEDIUM | Automation | Project has Vitest but no browser E2E framework | Open |

## Automated regression

- Lint: pass.
- Typecheck: pass.
- Unit and integration: 118 passed.
- Local build: blocked only by missing public Supabase environment variables.

## Browser audit

Forty page routes were discovered. Thirty direct operational routes were attempted. Admin pages, KPI dashboard, maintenance dashboard, inventory, reports and production views through planning rendered. The root page failed before its correction. Later HTTP 413 responses invalidate the remaining results and require a clean-session retest.

## Workflow safety

Operator Fix, Corrective Now and Schedule Corrective were inspected statically. Immediate server timestamps, idempotency key, advisory locking, persistent timer and same-ticket escalation exist. Parts, rollback, concurrency, PM and PH movement remain unexecuted until isolated test data is available.

## Fix applied

The root page now uses the aggregate source snapshot. Detailed transactional calculations remain in dedicated process pages, and unavailable values are not displayed as factual zero.

## Open risks

- HTTP 413 after prolonged navigation.
- Five-role permission matrix is unproven with one account.
- Inventory rollback and concurrency are untested.
- Maintenance golden paths require disposable assets and parts.
- Responsive, keyboard and complete filter matrices remain pending.

