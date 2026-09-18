# Canonical V2 Operational Parity Report

## Scope

Read-only comparison performed on 18 September 2026 between:

- Canonical V2: `saecycamkyvzzppxudzq`
- Production: `gdajktoqmajipivpdude`

DEV `tlflipdeahgwsueerkex` was not modified. Oracle was not modified.

## Runtime dependency decision

The current operational application does not query Production Demand or Manufacturing Order objects. Demand/MO is classified as `DEFERRED_CANONICAL_LAYER`; it is not required to reproduce the current live Production, Release Queue, Machine Load, Product Mix, Performance or Maintenance experiences.

## Source parity

| Dataset/read model | V2 | Production | Result |
| --- | ---: | ---: | --- |
| Current orders | 1,149 | 1,149 | PASS |
| Current Workbank rows | 8,323 | 8,323 | PASS |
| Current Workbank units | 13,296 | 13,296 | PASS |
| Current Stock rows | 57 | 57 | PASS |
| Current Stock units | 2,318.019 | 2,318.019 | PASS |
| DTG operational orders | 90 | 90 | PASS |
| DTG remaining units | 6,630 | 6,630 | PASS |
| DTG prints | 9,659 | 9,659 | PASS |
| Underprint operational orders | 29 | 29 | PASS |
| Underprint remaining units | 2,318.019 | 2,318.019 | PASS |
| Release Queue orders | 182 | 182 | PASS |
| Release Queue process quantity | 100,533 | 100,533 | PASS |
| Not Approved lines | 560 | 560 | PASS |
| Not Approved process quantity | 2,536 | 2,536 | PASS |

Not Approved remains isolated from Workbank workload totals. Release Queue and Workbank quantities were compared independently and were not summed.

## Current-live blockers

| Required live source | V2 | Production | Affected capability | Result |
| --- | ---: | ---: | --- | --- |
| Audit events | 76,092 | 76,092 | authoritative Oracle/WMS movement history | PASS |
| DTG order history | 826 | 826 | derived from preserved movement history | PASS |
| Capacity rows | 0 | 3 | Machine Load and Performance capacity | BLOCKED |
| Screen Print current Workbank (`PAK7`) | 0 | 0 | Machine Load, Product Mix and Performance | PASS |
| Maintenance work orders | 0 | 4 | active Maintenance workflow | BLOCKED |

Maintenance assets match at 31 versus 31. Parts, preventive plans and inventory locations are zero in both environments. Asset master parity therefore passes, but Maintenance functional parity fails because four production work orders are absent from V2.

## Snapshot status

V2 contains three completed sync batches. The latest completed batch contains 1,149 orders, 8,323 Workbank rows and 57 Stock rows. Earlier bootstrap batches contained empty operational payloads, so three-consecutive-run stability is not proven.

Production's latest completed snapshot at comparison time contained the same current Orders, Workbank and Stock counts. V2 was approximately two hours behind production, so a V2-specific five-minute scheduler must not be enabled until missing application-owned/history datasets are resolved and three controlled full snapshots pass.

## Functional readiness

| Module | Status | Reason |
| --- | --- | --- |
| Production / DTG / Underprint | PASS | Current snapshot aggregates match production |
| Release Queue | PASS | Order and process totals match production |
| Machine Load core DTG/UP | PASS | Workbank, Stock and Not Approved match |
| Machine Load Screen Print | PASS | Workbank `PAK7` is authoritative and is empty in both snapshots |
| Product Mix DTG/UP | PASS | Current Workbank authority matches |
| Product Mix Screen Print | PASS | Current Workbank `PAK7` load is zero; no manual quantity is added |
| Performance | BLOCKED | Audit and DTG history pass; capacity remains absent |
| Maintenance | BLOCKED | Four active/historical work orders are absent |
| Freshness/dashboard | BLOCKED | V2-specific recurring sync and three-run stability are not proven |

## Cutover decision

No preview deployment or V2 scheduler was activated. Doing so would expose incomplete current-live functionality even though the primary Oracle snapshots reconcile.

## Regression validation

| Check | Result |
| --- | --- |
| Lint | PASS |
| Typecheck | PASS |
| Shared tests | 49/49 PASS |
| Oracle sync tests | 15/15 PASS |
| Web tests | 113/113 PASS |
| Total application tests | 177/177 PASS |
| Production build | PASS |

The first test invocation encountered a Windows temporary-path I/O error only after its assertions passed. Re-running with a stable temporary directory completed all 177 tests successfully. No implementation was changed in response.

The next work must migrate or deterministically seed the missing non-Oracle/current-live datasets into V2, then execute three consecutive complete V2 syncs and repeat this parity matrix. This is operational data/configuration completion, not a redesign of Demand/MO architecture.

## Gate

## C5.4 Screen Print reconciliation

Screen Print is MAKE TO STOCK and Workbank-only. At comparison time, both V2 and production contained zero current Workbank rows with queue/task `PAK7`; current Screen Print load is therefore zero in both environments.

| PROD job | Workbank match | Qty | Status | V2 strategy |
| --- | --- | ---: | --- | --- |
| `faec7514-a304-4cfa-a912-01cb8a514edd` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |
| `7b7d33d3-9e0a-49a7-83a3-621243dd76e3` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |
| `7efe60db-26e5-469a-b00d-92d76a94bb48` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |
| `e152d90c-b77d-4e6c-96a9-c2ca4e3a5a21` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |
| `865648a0-d942-4616-bb7e-8708955f7021` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |
| `35c5a214-cf47-450c-ad7b-1c84c0a9b6b1` / order 123 / Teste | None | 1,000 | todo | OBSOLETE |

All six records are duplicate manual test jobs created within one minute, have no completed quantity and have no Workbank match. They were not migrated or deleted. Production and V2 both return zero Screen Print Release Queue rows/quantity and zero Screen Print Not Approved rows/quantity.

## C5.5 audit and DTG history

All 76,092 authoritative Oracle/WMS movement events were preserved in V2 with original IDs and timestamps. Re-application inserted zero rows. `v_dtg_order_history` now reconciles at 826/826 orders and remains derived, so it cannot inflate current Workbank load.

`production_events` was rebuilt from source history rather than copied. Its 48,582 canonical rows differ from 55,163 legacy production-derived rows because transformation rules changed; this is documented as `DERIVED_REBUILDABLE`, not missing source history.

`CANONICAL V2 OPERATIONAL PARITY BLOCKED — capacity, maintenance work orders, and three-run V2 sync stability are missing`

## C5.6 capacity and maintenance reconciliation

| Domain | PROD | V2 | Difference | Resolution |
| --- | ---: | ---: | ---: | --- |
| Capacity | 3 | 3 | 0 | Migrated as temporary PCP Online planning configuration; never workload |
| Maintenance Work Orders | 4 | 4 | 0 | Migrated with original IDs, assets, timestamps and operational history |

| Maintenance classification | Count |
| --- | ---: |
| Active | 3 |
| Completed | 1 |
| Scheduled (semantic mapping) | 1 |
| Preventive | 0 |
| Corrective | 4 |
| Cancelled | 0 |
| Orphan assets | 0 |
| Invalid stored statuses | 0 |

The maintenance child-state parity is six history rows, four comments, three downtime records and zero parts, labor, attachments or checklist rows. Reapplication inserted zero records and produced no duplicate audit events. Capacity and workload remain separate inputs in `v_capacity_load`.

`CANONICAL V2 OPERATIONAL PARITY BLOCKED — only C5.7 three-run V2 sync stability remains; scheduler, Preview and cutover remain off`

## C5.7 three-run sync stability

Three consecutive complete, non-empty V2 snapshots passed without reset, truncate, cleanup or configuration change.

| Metric | Baseline | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: | ---: |
| Orders | 1,147 | 1,147 | 1,147 | 1,147 |
| Workbank rows | 8,323 | 8,323 | 8,323 | 8,323 |
| Workbank qty | 13,296 | 13,296 | 13,296 | 13,296 |
| DTG orders / qty | 90 / 6,630 | 90 / 6,630 | 90 / 6,630 | 90 / 6,630 |
| Underprint orders / qty | 29 / 2,318.019 | 29 / 2,318.019 | 29 / 2,318.019 | 29 / 2,318.019 |
| Release Queue orders / qty | 184 / 101,839 | 184 / 101,839 | 184 / 101,839 | 184 / 101,839 |
| Not Approved rows / qty | 560 / 2,536 | 560 / 2,536 | 560 / 2,536 | 560 / 2,536 |
| Screen Print WB rows / qty | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| Audit / DTG history | 76,092 / 826 | 76,092 / 826 | 76,092 / 826 | 76,092 / 826 |
| Production events | 48,582 | 48,582 | 48,582 | 48,582 |
| Capacity / Maintenance WOs | 3 / 4 | 3 / 4 | 3 / 4 | 3 / 4 |

Batch IDs were `328352bd-86a6-41c2-8634-0108e39388e9`, `3da3570f-dd51-4166-90bb-7215ee05f1de`, and `ca51617b-5aa7-47ad-b854-ac8f2a7c7b4c`. Each read 1,147 orders, 23,522 release lines, 8,323 Workbank rows and 57 stock rows and completed without error.

All duplicate, orphan, invalid-state and unknown-event checks returned zero. Screen Print remained Workbank-only and absent from Release Queue/Not Approved. Release Queue remained isolated from Workbank. The Oracle source timestamp advanced once without changing operational content; this is an explained source metadata change. `UNEXPLAINED_DELTA = 0`.

Final validation: lint PASS, typecheck PASS, 196/196 tests PASS and production build PASS.

C5.3, C5.4, C5.5, C5.6 and C5.7 all pass. Scheduler, Preview and cutover remain off.

`CANONICAL V2 OPERATIONAL PARITY: PASS — READY FOR PREVIEW VALIDATION`
