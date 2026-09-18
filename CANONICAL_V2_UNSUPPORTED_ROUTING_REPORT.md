# Canonical V2 Unsupported Routing Report

## Scope

This report covers all 1,330 `RELEASED=Y`, Product-mapped source lines that do not have a resolved canonical Routing in Phase C5.2.

| Source group | Exception classification | Lines | Source quantity | Executable contribution |
| --- | --- | ---: | ---: | ---: |
| UV PRINT | UNSUPPORTED_ROUTING | 489 | 2,192 | 0 |
| STICKERS | UNSUPPORTED_ROUTING | 489 | 4,676 | 0 |
| HATS | UNSUPPORTED_ROUTING | 271 | 0 | 0 |
| PROD | MISSING_MO_ROUTING | 44 | 3,469 | 0 |
| FINISHED | NON_PRODUCTION / FINISHED | 27 | 0 | 0 |
| CUSTOM EMB | CUSTOM_EMB_UNSUPPORTED | 8 | 0 | 0 |
| VISUAL / VM | UNSUPPORTED_ROUTING | 2 | 0 | 0 |
| **Total** |  | **1,330** | **10,337** | **0** |

## Row-level evidence

The complete evidence file is `canonical-data/derived/C52_UNSUPPORTED_ROUTING_EXCEPTIONS.csv`. It preserves Sales Order, line, source SKU, source description, source group/process evidence, source quantity, raw release value, and the concrete exception reason.

No Routing was inferred or created for these records. They create no Production Demand, active Demand Mapping, Manufacturing Order, Machine Load, Capacity, Productivity, or ready-to-print Product Mix contribution.
