# DTG Production Source Contract

- Authority: Oracle `ISIS_AUDIT` (read-only).
- Completion: `TASK = PCOR`, `QUEUE = PCOR`, `FROM_ZONE = DTGS`, `TO_ZONE = PWL1`.
- Grain: unique `AUDIT_ID`; one event is one garment.
- Prints: `QTY * PROD_X_5`; `1 / 2` is two prints.
- Machine: `USERNAME` mapped to `machine_code`, preserving historical values; missing values are `UNATTRIBUTED`.
- Source timestamp: `ISIS_AUDIT.TIMESTAMP` is an Australia/Brisbane local wall-clock value. It is never shifted by `+10` and is never interpreted as UTC.
- Performance date: shift-based `operational_date`, derived from the effective canonical `shift_rules`. For a cross-midnight shift, events after midnight retain the date on which that shift started.
- Out-of-shift: facts that match no effective rule remain visible as `OUT_OF_SHIFT`; they are never forced into a nearby shift or discarded.
- Aggregate grain: `operational_date + process + machine_code + shift_code`, with garments and prints as base measures.
- Retention: shift/machine aggregates for Performance, not full Oracle event replication.

Vercel reads Supabase only. The factory agent is the Oracle bridge and loads active `shift_rules` before aggregating Oracle facts. Normal refresh covers seven Brisbane operational dates. Closed ranges use `pnpm --filter @tsd/oracle-sync dtg:refresh -- YYYY-MM-DD YYYY-MM-DD` on the factory agent.

## Shift attribution policy

- Monday-Friday production is assigned only by the effective canonical `shift_rules` for the applicable operational date.
- Saturday production is valid when an effective Saturday rule covers the Brisbane local wall-clock timestamp; it remains a Saturday operational date unless an explicit cross-midnight rule assigns it to the preceding shift-start date.
- Approved overtime is represented by an explicit `OVERTIME` shift rule. Performance queries must not contain hardcoded date or time exceptions.
- A source fact without a matching effective rule remains visible as `OUT_OF_SHIFT` and contributes to daily totals.
- Dates before the first effective `shift_rules` date support daily garment and print totals only. Their shift attribution remains `OUT_OF_SHIFT`; Morning, Afternoon, Graveyard, or Overtime history is never fabricated.
