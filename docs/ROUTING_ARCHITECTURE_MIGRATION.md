# Routing architecture migration

| Current entity | Target entity | Strategy | Compatibility layer | Removal criteria |
|---|---|---|---|---|
| production_processes | routing master | Preserve; reconcile in Phase B | Existing Flow queries | Routing parity approved |
| production_process_stages | routing operations | Preserve; map later | Existing stage engine | Order-operation parity approved |
| production_stage_source_rules | source operation mappings | Preserve; migrate in later phase | Current source rules | Source validation parity approved |
| Flow logic | production order operations | No Phase A rewrite | Existing Flow service | Full reconciliation signed off |
| KPI logic | operation facts | No Phase A rewrite | Existing KPI engine | KPI parity tests pass |
| Planning logic | production orders/routings | No Phase A rewrite | Existing planning tables | Planner acceptance complete |
| Capacity logic | work centers/resources | Foundation only | Existing capacity profiles | Resource capacity reconciliation complete |

Phase A is additive. SP11, PCOR, PWL1, DTGMOVE and UPMOVE remain source integration values only.

Manufacturing Order correction: group canonical demand lines within each Sales Order by effective Routing revision. ONE SO + ONE ROUTING = ONE MO. DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO. Existing execution records are not silently regrouped.
# Phase B implementation note

Routing Master and Routing Operations are introduced additively. Existing Flow, KPI, Planning and Capacity consumers remain on their validated compatibility sources. Products may reference a default routing, but no Production Order is created until Phase C. Routing revisions are immutable references for the future order-operation snapshot; historical execution must never dynamically inherit a later revision.

# Phase D implementation note

`source_operation_mappings` and the deterministic source resolver now form the canonical validation layer. Existing `production_stage_source_rules`, Flow and KPI queries remain as compatibility consumers through Phase E reconciliation. Removal is prohibited until old/new order state and quantity totals meet the approved parity threshold.

# MO grouping correction

ONE SO + ONE ROUTING = ONE MO.

DIFFERENT SALES ORDERS ARE NEVER MERGED INTO THE SAME MO.

Canonical source lines are grouped within their Sales Order by effective Routing revision. Existing routed headers are not silently regrouped. Future Flow, Planning, Capacity and KPI migrations must preserve drilldown from aggregate to MO, SO and source/product lines.
