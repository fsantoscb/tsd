# Canonical V2 C5.6 Capacity and Maintenance

## Safety and authority

The only write target was Canonical V2 `saecycamkyvzzppxudzq`. Production `gdajktoqmajipivpdude` was queried read-only, DEV `tlflipdeahgwsueerkex` remained inactive, and Oracle was untouched. Scheduler, Preview and cutover remain off.

Capacity is planning configuration: it is a denominator/constraint and is never workload. Maintenance is an independent operational domain and does not depend on Oracle release, Workbank, Screen Print rules or Manufacturing Orders.

## Capacity reconciliation

| PROD record | Semantic meaning | V2 equivalent | Action |
| --- | --- | --- | --- |
| `DTG` / 3,952 daily | Temporary PCP Online process planning capacity | `capacity_legacy_overrides` | MIGRATE |
| `UP` / 2,907 daily | Temporary PCP Online process planning capacity | `capacity_legacy_overrides` | MIGRATE |
| `DISPATCH` / 10,640 daily | Temporary PCP Online process planning capacity | `capacity_legacy_overrides` | MIGRATE |

All records use five work days and source `PCP Online active scenario 2026-09-09`. They are process/area planning capacities, not machine, shift or performance-output records. Original IDs, area links, values, timestamps, active/temporary flags and provenance are preserved. Official `capacity_profiles`, if introduced later, retain precedence over these legacy overrides.

Consumers are `/production/capacity`, Machine Load, Production Flow/KPIs and downstream Performance/planning presentations through `v_capacity_load`. The view keeps `demand_units` and capacity columns separate; tests explicitly prevent addition of capacity to workload.

## Maintenance reconciliation

| WO | Asset | Type | Stored status | Semantic lifecycle | Priority | Created | Assigned | Active? | Parts | Timer | Action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | ---: | --- | --- |
| `WO-2026-000001` | DTG-001 | SCHEDULE_CORRECTIVE / corrective | REQUESTED | SCHEDULED | medium | 2026-09-12 17:46:12Z | none | yes | 0 | NOT_OBSERVED | MIGRATE_ACTIVE |
| `WO-2026-000002` | DTG-001 | OPERATOR_FIX / corrective | completed | COMPLETED | high | 2026-09-18 11:16:58Z | none | no | 0 | downtime observed | MIGRATE_HISTORY |
| `WO-2026-000003` | DTG-002 | CORRECTIVE_NOW / corrective | WAITING_MAINTENANCE | OPEN | critical | 2026-09-18 11:18:40Z | none | yes | 0 | active downtime | MIGRATE_ACTIVE |
| `WO-2026-000004` | DRY-002 | CORRECTIVE_NOW / corrective | WAITING_MAINTENANCE | OPEN | high | 2026-09-18 11:37:34Z | none | yes | 0 | active downtime | MIGRATE_ACTIVE |

The V2 assets DTG-001, DTG-002 and DRY-002 exist under the same source IDs and remain `MAIN_ASSET`; no fake asset or remapping was created. Stored statuses are preserved because they are valid application states. The semantic mapping above provides the target lifecycle without silently rewriting operational state or inventing `started_at` values.

Original work-order IDs, numbers, timestamps, request keys, actor IDs/emails, descriptions, resolution and downtime fields are retained. Six work-order history records, four comments and three downtime records are migrated. There are no labor rows, attachments, parts transactions or checklist rows to migrate.

## Parts, timer, preventive and audit

- Parts: none observed; no part master or stock transaction was created.
- Timer: one closed downtime and two active downtime periods are preserved exactly. Missing technician timers remain `NOT_OBSERVED`.
- Preventive: none of the four work orders references a preventive plan. No schedule, service cycle or next-due value changed.
- Audit: `source_audit_events` is Oracle/WMS history and is intentionally not linked to maintenance. The six maintenance history records remain the operational timeline. V2 audit triggers record the initial migration inserts once; the idempotent second run creates no additional events.

## Idempotency and validation

The migration keys are the original primary IDs, plus the existing `(organization_id, production_area_id, source_name)` capacity uniqueness rule and operator request uniqueness rule. The second execution inserts zero capacity, work orders, history, comments, downtime, parts, labor, attachments or checklist rows.

Expected final parity: three capacity records, four work orders, six history records, four comments, three downtime records, zero orphan assets, zero invalid stored statuses and zero duplicates.

The additional 11 unit tests cover capacity authority/idempotency/separation and maintenance status mapping, identity, disposition, timer evidence and preventive schedule protection.

## Remaining blockers

No C5.6 capacity or maintenance blocker remains. Three-run sync stability belongs to C5.7 and was not executed.
