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
