# Labour V3 Phase 3A-C — LOCAL IMPLEMENTATION PASS

08 October 2026. Inline execution; no subagents. Production activation BLOCKED.

## Migration

Filename: `20261008090703_labour_v3_canonical_read_model.sql`.
SHA-256: `512FD1728C604C0158B28173BFD875DF822C613F9737BA37F62398EEB6EB6637`.
Applied: NO. The existing draft was completed through supporting fixtures/tests;
its SQL bytes and version were not changed in Phase 3A-C.

Objects: labour_v3_canonical_cohorts; labour_v3_check_generation_v1;
labour_v3_select_cohort_v1; v_canonical_labour_segments_v3;
v_current_labour_employee_segments_v3; v_current_labour_window_segments_v3;
labour_v3_window_domain_v1; labour_v3_certify_window_v1.
Only own constraints/RLS/ACL/comments accompany them. No legacy replacement,
seed, ACTIVE transition, generation mutation or old helper/writer ACL change.

## Local implementation and evidence

CAS: disconnected state-machine PASS for create, exact replacement, same-generation
reselection, retained tombstone, re-enable, stale version/generation, NULL wildcard,
overflow and first-insert one-winner model. This is NOT atomicity/concurrency SQL proof.

Employee and Window: exact typed field projections over one explicit selected
segment set. No business metric recalculation. Person isolation verified using
the actual 24-person G1 manifest and a multi-area person (UP + Shared Dispatch);
one local selection includes only that person's complete cohort, not the other 23.

Certificate fixtures: all 15 requested cases, plus 21 Sep/05 Oct/multiple-cause
cases. Every case asserts statuses, blocking, certifiedComplete, requiredCohorts,
selectionVector and generationChecks. The test-only oracle consumes a resolved
authority domain/full-manifest evidence; it does NOT choose FULL snapshots,
implement another authority algorithm or calculate SQL fingerprints.

AUTHORITY_AMBIGUOUS and STALE_GENERATION block. Partial/missing cannot be complete.
CERTIFIED_COMPLETE is alone. Numeric observed values never override coverage.

Snapshot: REPEATABLE READ or SERIALIZABLE plus READ ONLY; weaker/writable sessions
reject. No global isolation change. Ordinary PostgREST RPC is NOT assumed sufficient.

## Full G1/G2 read-only reconciliation

Read scope: two specific READY generations and organization
f39ce894-e039-4329-aeca-85e46e193aef. Small ordered pages, no helper/writer call.
Input: G1 971 + G2 912 = 1,883. Manifests: 24 + 25 cohorts.
Person keys replaced by opaque PERSON identifiers; no names, credentials or
Deputy raw payloads committed in the fixture. Numeric persisted values remain
strings so identity comparison does not round them.

| Input | Employee | Window | Missing | Duplicates | Changed |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1883 | 1883 | 1883 | 0 | 0 | 0 |

Every segment ID retained once; metric and dimensional fields match their persisted
source, with only the explicitly approved projection aliases. Synthetic competing
READY rows are excluded rather than unioned.

G1 -> 28 Sep Window: INDIRECT 7.215686274509803 h;
SCREEN_PRINT_CREW 8.210526315789474 h. Both remain owned by G1 Employee week
21 Sep, and their raw IDs are absent from G2 membership.

28 Sep DTG: A 15.458333333333332; B 16.708333333333332;
A+B 32.166666666666664. Actual persisted raw b628bdfc-ad79-4ed0-a06e-81bf906d88b3
contains 14:00–14:30 A and 14:30–15:00 B intervals.
Cross-midnight C and Friday 06/12/18/23 boundaries reuse the existing shared calendar
resolver with tolerance disabled; persisted Friday noon transitions also agree.
Headcount remains Employee-oriented despite physical B spill.

21 Sep SCREEN_ROOM A observed: 7.666666666666666 h, diagnostic only.
Known missing prior contribution: 7.712962962962962 h, NOT inserted/fabricated.
Fixture certificate: PARTIAL_PREVIOUS_COHORT, certifiedComplete=false.
05–11 Oct: FULL through 06 Oct does not certify complete Employee-week/adjacent
context. Missing/partial status preserved; no fictitious G3 or certified zero.

## Concurrency harness

Six scenario functions completed: first insert, replacement, conflicting source
lock >1 second, selection update during RR certificate, authority mutation during
RR certificate, and certificate after committed state change.
Guard tests reject absent approval, Production, Preview and missing fixtures.
Actual server host/database identity is checked before any mutation.
SQL harness execution: NO. No approved disposable target exists.
The handoff documents exact synthetic fixture prerequisites and retains evidence;
no automatic provisioning, retries or destructive cleanup.

## Fresh local gates

| Gate | Result |
| --- | --- |
| Static read-model contracts | 14/14 PASS |
| Original disconnected fixtures | 5/5 PASS |
| Complete certificate/projection/CAS/calendar fixtures | 29/29 PASS |
| Harness guards/code shape | 5/5 PASS |
| Total focused local tests | 53/53 PASS |
| Shared, canonical checkout | 49/49 PASS |
| Web, canonical checkout | 167/167 PASS |
| Connector, canonical checkout | 61/61 PASS |
| Lint, canonical checkout | PASS |
| Typecheck, canonical checkout | PASS |
| Production-compatible unchanged web build | PASS |
| git diff --check | PASS |

Build worktree: C:/Projects/tsd-performance-exclude-dtg-print.
HEAD: a0e2a221f2d4b26efde321b4edb30d4a4de67e2b.
Environment: existing Production-target local build environment from
C:/Projects/tsd-dtg-performance-release/apps/web/.env.local, loaded into the build
process only. Project URL verified as eziirebccovlvhaonsgw before use.
No env file changed, no fake values, no Preview target. Build worktree stayed clean.
The previously failing schema-checkout build lacked public env; this separate
unchanged deployed-runtime regression build satisfies the approved Task 12 path.
Neither build nor application tests certify PostgreSQL behavior.

## SQL certification — independent outcomes

Migration execution: NOT EXECUTION-CERTIFIED.
SQL contract: NOT EXECUTION-CERTIFIED.
CAS atomicity: NOT EXECUTION-CERTIFIED.
CAS concurrency: NOT EXECUTION-CERTIFIED.
Source lock timeout: NOT EXECUTION-CERTIFIED.
Certificate snapshot consistency: NOT EXECUTION-CERTIFIED.

## Recovery / review / scope

Recovery artifact revokes only service_role EXECUTE on the new selector and
certificate. No DROP/DELETE/TRUNCATE or generation update. Selection rows,
tombstones, legacy/V3 evidence, old ACLs and ledger remain intact.
Active consumers searched in canonical apps/packages, current Production web
app/lib/components and active connector src: 0 references.
Previous storage/writer/validator SHA-256 assertions PASS.
Separate final self-review performed inline per the explicit no-subagent constraint;
it is weaker than a fresh independent reviewer and does not waive SQL certification.

Fresh Production read-only state: READY=2, FAILED=2, ACTIVE=0.
Phase 3A selection table does not exist in Production.
Writes=0; migration=NO; selection seeds=0; deploy=NO; Preview=NO;
scheduler=UNCHANGED; writer/helper remain disabled; legacy remains canonical.
Preexisting canonical-checkout dirty artifacts preserved, not included in this work.

## Final gate

Phase 3A non-SQL local gate: PASS.
Production activation: BLOCKED.
Only remaining activation blocker: SQL EXECUTION CERTIFICATION.
