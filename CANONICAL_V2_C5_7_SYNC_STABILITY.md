# Canonical V2 C5.7 Sync Stability

## Safety

Canonical V2 `saecycamkyvzzppxudzq` was the only write target. Production `gdajktoqmajipivpdude` remained read-only, DEV `tlflipdeahgwsueerkex` remained inactive and untouched, and Oracle was queried read-only. Scheduler, Preview and cutover remained off.

The three runs used the normal Oracle connector against a local V2 ingestion endpoint. No reset, truncate, cleanup or configuration change occurred between runs. An earlier sync completed while post-run instrumentation referenced a wrong diagnostic column; it was excluded, a fresh baseline was captured, and the required sequence restarted from Run 1.

## Baseline and stability matrix

Baseline captured at `2026-09-18 14:42:13.992871+00`.

| Metric | Baseline | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: | ---: |
| Orders | 1,147 | 1,147 | 1,147 | 1,147 |
| Workbank rows | 8,323 | 8,323 | 8,323 | 8,323 |
| Workbank qty | 13,296 | 13,296 | 13,296 | 13,296 |
| DTG orders | 90 | 90 | 90 | 90 |
| DTG qty | 6,630 | 6,630 | 6,630 | 6,630 |
| Underprint orders | 29 | 29 | 29 | 29 |
| Underprint qty | 2,318.019 | 2,318.019 | 2,318.019 | 2,318.019 |
| Release Queue orders | 184 | 184 | 184 | 184 |
| Release Queue lines | 23,522 | 23,522 | 23,522 | 23,522 |
| Release Queue qty | 101,839 | 101,839 | 101,839 | 101,839 |
| Not Approved rows | 560 | 560 | 560 | 560 |
| Not Approved qty | 2,536 | 2,536 | 2,536 | 2,536 |
| Screen Print WB rows | 0 | 0 | 0 | 0 |
| Screen Print WB qty | 0 | 0 | 0 | 0 |
| Audit events | 76,092 | 76,092 | 76,092 | 76,092 |
| DTG history | 826 | 826 | 826 | 826 |
| Production events | 48,582 | 48,582 | 48,582 | 48,582 |
| Capacity | 3 | 3 | 3 | 3 |
| Maintenance WOs | 4 | 4 | 4 | 4 |

## Run results

| Run | Batch ID | Completed | Orders read | Release lines read | Workbank read | Stock read | New audit |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `328352bd-86a6-41c2-8634-0108e39388e9` | 2026-09-18 14:42:46.9409+00 | 1,147 | 23,522 | 8,323 | 57 | 0 |
| 2 | `3da3570f-dd51-4166-90bb-7215ee05f1de` | 2026-09-18 14:43:30.76779+00 | 1,147 | 23,522 | 8,323 | 57 | 0 |
| 3 | `ca51617b-5aa7-47ad-b854-ac8f2a7c7b4c` | 2026-09-18 14:44:24.132927+00 | 1,147 | 23,522 | 8,323 | 57 | 0 |

Every batch reached `completed`, had no error, and promoted a non-empty source snapshot. The application transaction records identical start/completion timestamps; end-to-end connector observation was approximately 33-54 seconds per run.

Source order timestamps were `14:35:09`, `14:35:09`, `14:45:20`, and `14:45:20` UTC for baseline through Run 3. The timestamp advancement between Run 1 and Run 2 is a `SOURCE_CHANGE`; it produced no operational count/quantity delta.

## Run-to-run deltas

| Interval | Operational count/qty delta | Source change | Classification |
| --- | ---: | --- | --- |
| Baseline to Run 1 | 0 | none observed | NO_CHANGE |
| Run 1 to Run 2 | 0 | Oracle order source timestamp advanced | EXPECTED_SOURCE_DELTA |
| Run 2 to Run 3 | 0 | none observed | NO_CHANGE |

`UNEXPLAINED_DELTA = 0`.

## Authority and parity validation

- Workbank parity: every run read and exposed 8,323 rows; source payload and V2 current view agree. Workbank remains the current-load authority.
- Release Queue parity: every run read 23,522 Oracle release lines. Release Queue remained independently derived at 184 orders and 101,839 process units; it was never added to Workbank.
- DTG/Underprint: current views remained stable at 90/6,630 and 29/2,318.019 respectively.
- Screen Print: PAK7 Workbank rows/qty, Release Queue rows/qty and Screen Print Not Approved rows all remained zero. `screen_print_jobs` was not used as workload.
- Historical isolation: audit events, DTG history and production events remained stable and did not increase current workload.
- Capacity: three configuration records remained unchanged, with zero duplicate configuration keys and no workload contribution.
- Maintenance: four WOs, six history rows, four comments and three downtime records remained unchanged.

## Duplicate, orphan and integrity checks

All baseline and post-run checks returned zero for duplicate Workbank source keys, audit IDs, audit hashes, DTG history keys, production event IDs, maintenance WOs, capacity keys and active demand mappings.

All checks returned zero for orphan maintenance assets, orphan parts, orphan release lines and orphan MO operations. Invalid maintenance statuses, invalid production events and unknown audit identities were also zero. Active MOs and operational demand mappings remain deferred/empty and were not fabricated for parity.

## Collapse and complete-snapshot protection

Orders, Oracle release lines, Workbank and the existing audit source remained non-empty. None approached zero. Each promoted batch was `completed`; no failed or partial batch replaced the authoritative `v_latest_completed_batch`. Existing ingestion tests cover rejection of incomplete or unauthorized payloads without promoting them.

## Tests

The full C5 regression set includes operational authority, Screen Print exclusion, audit/DTG history, capacity, maintenance and idempotency. Final results are recorded after Run 3.

| Validation | Result |
| --- | --- |
| Lint | PASS |
| Typecheck | PASS |
| Shared tests | 49/49 PASS |
| Oracle sync tests | 15/15 PASS |
| Web tests | 132/132 PASS |
| Total | 196/196 PASS |
| Production build | PASS |

The validation wrapper printed all four exit codes as zero. A typo in its final summary predicate occurred only after the successful build output and did not affect any validation result.

## Remaining blockers

No operational parity blocker remains. Preview remains off and requires a separate controlled validation phase.

## Result

`CANONICAL V2 OPERATIONAL PARITY: PASS`
