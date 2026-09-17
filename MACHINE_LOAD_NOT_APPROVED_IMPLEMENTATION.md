# Machine Load - Not Approved Implementation

## Scope

ML-NA2 adds an informational, opt-in view of Release Queue lines whose canonical status is `NOT_APPROVED` to `/production/machine-load`.

The feature is OFF by default. It does not add potential demand to active machine load, backlog, capacity, utilisation, productivity, targets, Production Demand, Production Orders or Manufacturing Orders.

## Implementation

- `v_machine_load_not_approved` is a read-only service-role view built from the current release-line snapshot and canonical `v_release_queue` status.
- The view retains source-order and source-line identity and exposes process quantity without garment conversion.
- DTG and Underprint are assigned only when deterministic process evidence exists.
- Routing and machine assignment remain visibly unresolved or ambiguous instead of being guessed.
- The web page queries the view only when `showNotApproved=1`.
- Potential rows are returned and rendered separately from active machine-load data.
- Existing Machine Load filters are applied to the potential dataset without changing active calculations.

## Isolation proof

Database result after two successive successful Oracle snapshots:

| Check | Result |
| --- | ---: |
| Potential lines | 817 |
| Potential Sales Orders | 10 |
| Potential process quantity | 9,966 |
| DTG process quantity | 627 |
| Underprint process quantity | 329 |
| Unresolved process quantity | 9,010 |
| Duplicate source lines | 0 |
| Routing resolved | 0 |
| Routing ambiguous | 4 |
| Routing unresolved | 6 |
| Production Orders created | 0 |
| Production Demand table | Not present |
| Manufacturing Orders table | Not present |

The two observed snapshots completed successfully under the existing five-minute read-only Oracle agent. The second snapshot did not create duplicate informational rows or production execution records.

## Active-load parity baseline

With the informational toggle OFF, the live active dataset remained:

| Metric | Value |
| --- | ---: |
| Underprint to pick | 184 garments |
| Underprint ready | 4,284 garments |
| Underprint total | 4,468 garments |
| DTG to pick | 5,849 garments / 7,971 forecast prints |
| DTG ready | 6,435 garments / 8,770 confirmed prints |
| DTG total active load | 16,741 prints |
| Daily capacity | 3,952 prints |
| Daily load | 424% |
| Weekly capacity | 19,760 prints |
| Weekly load | 85% |

The ON state adds only the separate Potential Not Approved section. It does not alter these active metrics.

## Validation

| Validation | Result |
| --- | --- |
| Lint | PASS |
| Typecheck | PASS |
| Shared tests | PASS - 49 |
| Oracle sync tests | PASS - 14 |
| Web tests | PASS - 92 |
| Total application tests | PASS - 155 |
| Production build | PASS |
| Oracle access | READ ONLY |
| Production Demand / MO side effects | NONE |

## Operational behavior

- Default URL: `/production/machine-load`
- Informational view: `/production/machine-load?showNotApproved=1`
- Toggle OFF: only active approved/released machine load is shown.
- Toggle ON: active machine load remains unchanged and a separate potential-demand section is displayed.
- Unknown process, routing or machine assignments stay explicit and do not affect active calculations.

## Conclusion

The Not Approved dataset is informationally isolated, idempotent at source-line grain, and has no path into production execution demand.
