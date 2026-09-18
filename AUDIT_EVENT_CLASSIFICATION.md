# Audit Event Classification

## Scope and authority

The production object named `source_audit_events` is not a generic ERP change log. It is one Oracle/WMS movement-event mechanism imported from the source audit feed.

The authoritative identity is `(organization_id, source_audit_id)`. `raw_hash` is a second idempotency key. Original `event_at`, `username`, movement fields, source quantities and source IDs are preserved. There are no old/new JSON values or polymorphic entity references in this source.

## Source quality

| Measure | Result |
| --- | ---: |
| Total events | 76,092 |
| Oldest | 2026-08-02 20:37:36 UTC |
| Newest | 2026-09-18 07:35:02 UTC |
| Orders | 951 |
| Null order | 0 |
| Null actor | 0 |
| Null source ID | 0 |
| Duplicate source IDs | 0 |
| Duplicate raw hashes | 0 |
| Zero quantity | 4 |
| Negative quantity | 0 |
| Test/synthetic candidates | 0 |

Monthly distribution: August 2026 contains 21,685 events and September 2026 contains 54,407.

There are 1,894 additional source-distinct rows whose operational payload and timestamp match another row. They are concentrated in DTG Pick (1,252), DTG Print (640) and UP In (2). These are not migration-created duplicates: each has a distinct Oracle `source_audit_id` and `raw_hash`. They are retained as source-confirmed events; C5.5 does not infer that two authoritative source IDs are one event.

## Classification matrix

| Event family | PROD | Classification | Required | Strategy | V2 target |
| --- | ---: | --- | --- | --- | --- |
| DTG Pick (`PG11 -> DTGS`) | 33,571 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| DTG Print (`DTGS -> PWL1`) | 31,888 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| DTG Dispatch (`to_location=DTGMOVE`) | 544 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| Underprint In | 8,218 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| Underprint Out | 726 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| Other Oracle movement | 1,145 | REQUIRED_OPERATIONAL_HISTORY | Yes | MIGRATE | `source_audit_events` |
| KPI `production_events` generated from audit | 55,163 legacy PROD / 48,582 canonical V2 | DERIVED_REBUILDABLE | No independent history | REBUILD_FROM_AUTHORITATIVE_HISTORY | `production_events` |
| `v_dtg_order_history` | 826 | DERIVED_REBUILDABLE | No independent history | REBUILD_FROM_AUTHORITATIVE_HISTORY | view over `source_audit_events` |

Every raw event belongs to exactly one family. `UNKNOWN = 0`, `TEST_OR_OBSOLETE = 0` and `LEGACY_COMPATIBILITY_ONLY = 0`.

## Derived-event divergence

Production's `production_events` is not copied because it reflects an older transformation history. For example, production has 23,870 `DTG_PRINT` facts, while the current canonical resolver produces 4,939 facts requiring `PCOR` queue/task evidence. Canonical V2 reconstructs all metrics from the preserved source events under the current baseline contract.

This divergence is classified `DERIVED_REBUILDABLE`, not lost source history.

## Idempotency

The migration was executed against Canonical V2 and then re-applied. Results:

- source events after first complete import: 76,092;
- second-pass inserts: 0;
- duplicate source IDs: 0;
- duplicate raw hashes: 0;
- historical timestamp changes: 0;
- DTG history rows after rebuild: 826.

An expression index on `(organization_id, coalesce(source_audit_id, raw_hash))` supports deterministic derived-event reconstruction and the existing normalization trigger.
