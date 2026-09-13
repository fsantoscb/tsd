# Routing Phase D Result

## Scope delivered

- Canonical source-operation mappings for Oracle Audit, Workbank and Stock evidence.
- Deterministic matching with exact, prefix, suffix and SQL-like rules.
- Production Order Operation evidence ledger.
- Actual operation-state resolver using the immutable Phase C routing snapshot.
- Routing exception foundation for skipped, out-of-sequence, unknown, unexpected and mismatched activity.
- Canonical routing-status view.
- Organization RLS, role-controlled configuration and audit coverage.

## Safety boundaries

- The implementation is additive and does not replace current Flow, KPI, Planning or Capacity queries.
- Oracle/WMS remains the evidence and stock authority.
- Routing remains the expected path; source evidence never rewrites a historical routing snapshot.
- Ambiguous source values are not guessed.
- BOM/MRP remains inactive.
- No production Supabase migration was applied.

## Semantics

- `CURRENT_LOCATION`, `ENTERED_OPERATION` and `MOVED_TO_OPERATION` reach/start an operation.
- `COMPLETED_OPERATION` and `MOVED_FROM_OPERATION` complete an operation.
- A later observed operation with an earlier required operation lacking evidence creates `SKIPPED_OPERATION`.
- A mapped operation absent from the order snapshot creates `UNEXPECTED_OPERATION`.

## Deferred to Phase E

- Reconciliation against legacy Flow, Excel and operational source totals.
- Approval of currently provisional DTGMOVE, UPMOVE and UP suffix semantics.
- Authoritative UI cutover.

