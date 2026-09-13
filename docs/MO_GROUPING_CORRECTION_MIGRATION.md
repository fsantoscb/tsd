# MO grouping correction migration

The correction is additive. Existing Phase C/D/E `production_orders` are not silently regrouped.

Classification rules:

| Classification | Rule | Action |
|---|---|---|
| VALID | One source Sales Order, one Routing snapshot, coherent line ownership | Keep unchanged |
| NEEDS_REGROUPING | More than one Routing represented by one execution record | Report; controlled migration required |
| AMBIGUOUS | Source identity or Routing ownership cannot be proven | Do not mutate |
| MISSING_SOURCE_LINE_DATA | Header exists without canonical demand/MO lines | Keep as compatibility record |

Local Phase C/D/E records created before this migration are classified as `MISSING_SOURCE_LINE_DATA` until source lines are ingested. No destructive data rewrite is performed.

