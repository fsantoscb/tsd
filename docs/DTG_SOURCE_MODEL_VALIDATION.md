# DTG Source Model Validation

Read-only Oracle validation on 20 Sep 2026: 1,261,189 exact PCOR completions, 1,261,189 distinct `AUDIT_ID`, every `QTY = 1`, no missing `USERNAME`, and complete `DTIME1 <= DTIME2 <= DTIME3 <= TIMESTAMP` ordering. `PROD_X_5` distribution: 741,674 at 1, 519,184 at 2, and 331 at `1 / 2` (two prints). Two transition-only staged rows were task `SA`, queue null, destination `PWL1FULL`, and are not PCOR completions.

| Brisbane date | Garments | Prints |
| --- | ---: | ---: |
| 2026-09-07 | 2,053 | 2,459 |
| 2026-09-08 | 3,018 | 4,054 |
| 2026-09-09 | 2,989 | 3,738 |
| 2026-09-10 | 1,633 | 2,099 |
| 2026-09-11 | 1,362 | 1,915 |
| 2026-09-12 | 934 | 1,363 |
| 2026-09-14 | 2,487 | 3,761 |
| 2026-09-15 | 2,718 | 3,512 |
| 2026-09-16 | 3,294 | 4,058 |
| 2026-09-17 | 2,320 | 3,133 |
| 2026-09-18 | 1,359 | 1,790 |
| 2026-09-19 | 289 | 433 |

The calendar-date totals above are source-control totals. Performance totals are subsequently attributed to the effective canonical shift and its operational start date; cross-midnight events therefore move to the preceding operational date without changing total garments or prints. `ISIS_AUDIT.TIMESTAMP` is already Brisbane local wall-clock time and receives no UTC conversion or `+10` shift. Machine/shift sums must reconcile to the source facts, while unmatched events remain visible as `OUT_OF_SHIFT`.

Existing raw/staged/reconstructed records remain untouched. `RAW_HISTORY_SAFE_TO_REMOVE_LATER = UNKNOWN` because legacy audit families and event screens still consume the existing structures. Three years at 50 historical machine codes and three shifts remains materially smaller than the current staged DTG population.
