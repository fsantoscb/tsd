# Full ERP usability test report

## Executive summary

The ERP has a broad functional surface and 118 passing tests, but the current audit result is CONDITIONAL FAIL. One critical landing-page scalability defect was found and corrected. A repeatable HTTP 413 condition and the absence of an isolated E2E tenant prevent safe completion of destructive maintenance, PM and inventory golden paths.

## Metrics

- Routes discovered: 40
- Direct operational routes attempted: 30
- Automated tests passed: 118
- Automated tests failed: 0
- Bugs found: 6
- Critical: 2
- High: 2
- Medium: 2
- Bugs fixed in source: 1
- Final status: CONDITIONAL FAIL

## Coverage

Static discovery, navigation inventory, lint, typecheck, unit/integration regression and authenticated route sweep were completed. Maintenance mutations, stock consumption, concurrency, rollback, PH transfer and complete role testing were not run against production data.

## Maintenance and KPI status

The operator workflow contains immediate downtime creation, idempotency, per-asset locking and same-ticket escalation. Browser rendering of the KPI dashboard passed after aggregate-source optimisation. Controlled mathematical scenarios and complete maintenance lifecycles require deterministic fixtures.

## Final decision

Read paths tested before the 413 condition are usable. Full PASS requires resolving the 413 response and provisioning isolated fixtures and accounts for golden paths, permissions, rollback and concurrency.
