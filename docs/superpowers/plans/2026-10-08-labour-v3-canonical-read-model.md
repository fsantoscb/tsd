# Labour V3 Canonical Read Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Execution is inline, without subagents, preserving the established method. Steps use checkbox syntax for tracking.

**Goal:** Build local additive canonical cohort selection, Employee/Window projections and separate bounded certification without activating V3.

**Architecture:** An explicit CAS selection per organization/person/payroll week selects one certified generation context. Both projections expose the same persisted segment set. A separate bounded read certificate discovers contributors from authority, validates generation freshness and reports coverage independently from observed values.

**Tech Stack:** Existing PostgreSQL/PLpgSQL, Node built-in test runner, repository pnpm/Vitest/TypeScript tools. No new dependency or calculation engine.

**Spec:** `docs/superpowers/specs/2026-10-08-labour-v3-canonical-read-model-design.md`, approved 08 Oct 2026, plus the explicit multi-person isolation and authority-domain discovery gates below.

## Global Constraints

- Local implementation only. Production writes/apply/writer/helper activation/deploy/Preview/scheduler changes = NONE.
- Legacy remains canonical. No ACTIVE transition, selection seed, generation rebuild or segment mutation.
- Existing migrations, writer/helper definitions and ACLs remain unchanged.
- No Paid/Break/Productive/Regular/OT, shift, Capacity, Performance, Daily Flow or consumer change.
- Preserve every preexisting dirty/untracked file; stage only this workstream's explicit files.
- Production identity, if read-only evidence is required: `eziirebccovlvhaonsgw`, org `f39ce894-e039-4329-aeca-85e46e193aef`.
- SQL execution/atomicity/concurrency certification requires a verified disposable database. No Production/Preview/Docker test target. Otherwise report NOT EXECUTION-CERTIFIED.

## Review Focus

1. A multi-person generation must not auto-select unrequested people; test in Tasks 2 and 4.
2. A newly authoritative person missing from selection must prevent CERTIFIED_COMPLETE; test in Task 3.
3. Disable/re-enable and racing first inserts must preserve monotonic CAS and tombstones; test in Tasks 2 and 5.
4. Authority/selection changes during certification must not produce mixed-snapshot proof; test in Tasks 3 and 5.
5. A numeric observed total with stale/ambiguous authority remains blocking, and missing source coverage never means certified zero; test in Tasks 3 and 4.

## File and execution boundaries

Use the existing isolated canonical schema worktree `C:/Projects/tsd-production-schema-2026-09-27` only after capturing its baseline status and hashes. Its approved spec commit is `3405ed76916c0d3dfc8f89d54e5311e86de32f91`. Do not merge web/connector histories into it. If isolation is insufficient, stop and use the worktree skill before creating a separate checkout.

Create one migration `supabase/migrations/<actual-unused-timestamp>_labour_v3_canonical_read_model.sql`; the timestamp is chosen at creation, not reserved in this plan. Create these supporting files:

- `scripts/tests/labour-v3-read-model-static.test.mjs`: additive SQL/security source contracts, not execution proof.
- `scripts/tests/fixtures/labour-v3-read-model.json`: anonymized bounded G1/G2 and synthetic negative fixtures.
- `scripts/tests/labour-v3-read-model-fixtures.test.mjs`: disconnected projection/coverage expectations, never runtime authority.
- `supabase/tests/labour_v3_read_model_contract.sql`: guarded disposable SQL contract/fixture execution.
- `supabase/tests/labour_v3_read_model_concurrency.mjs`: guarded disposable two-connection CAS/snapshot checks.
- `docs/rollback/labour-v3-canonical-read-model-disable.sql`: non-destructive, unapplied recovery artifact.
- `docs/superpowers/plans/2026-10-08-labour-v3-read-model-local-result.md`: evidence and certification level.

All functional SQL belongs to the new migration. Intermediate task commits are local drafts, never deployable/applied artifacts; do not renumber the migration while completing tasks.

### Task 1: Pin contracts and establish failing safety tests

**Files:** static test, SQL contract, fixture JSON above. No migration yet.

**Consumes:** approved spec; existing storage/writer/validator SQL; bounded read-only generation metadata; existing SQL authority semantics.

**Produces:** exact migration version, certified algorithm identifier, immutable baseline hashes and safe fixture contract.

- [ ] Read applicable AGENTS.md and record worktree HEAD/status, existing migration hashes, legacy view definition fingerprint and V3 source hashes. No Production helper execution.
- [ ] Read G1/G2 metadata if not already available; verify actual algorithm identifier rather than adopting a test value. Stop on disagreement between generation algorithm/calculation identifiers. Do not print person names or secrets.
- [ ] Pin the existing full-manifest fingerprint structure, one-week/64-cohort bound, source lock order and validator signature. Record how the existing helper/validator can be invoked internally without changing their ACLs.
- [ ] Write static tests requiring new object names, no old-object replacement, no seeds/ACTIVE transitions, no runtime imports, fixed security-definer search_path and SELECT-only normal table access. Run `node --test scripts/tests/labour-v3-read-model-static.test.mjs`; expect failure because migration is absent.
- [ ] Write disposable SQL assertions for empty selection table, exact ordered projection field contracts, unchanged legacy/V3 rows and original function ACLs. SQL test must refuse to run unless both an explicit disposable approval sentinel and the expected disposable database identity are supplied.
- [ ] Generate the actual project-convention timestamp, ensure it is later than all canonical migration versions and unused in relevant worktrees, then create the migration in Task 2. Record its immutable filename.
- [ ] Commit only newly created tests/fixtures when review passes; never stage old untracked scripts/tests as a directory.

### Task 2: Implement selection and simple deterministic projections

**Files:** new migration, static test, SQL contract.

**Consumes:** Task 1 generation/algorithm and full-manifest contracts.

**Produces:** `labour_v3_canonical_cohorts`; `labour_v3_check_generation_v1(uuid,uuid) RETURNS jsonb` internal validation; `labour_v3_select_cohort_v1(jsonb) RETURNS jsonb`; shared `v_canonical_labour_segments_v3`; Employee and Window views named in the spec.

Selector request keys: `organizationId`, `personKey`, `payrollWeek`, `generationId`, `expectedGenerationId`, `expectedSelectionVersion`, `enabled`, `actor`, `reason`. Response returns exact cohort key, generation, enabled, selectionVersion and selectedAt; no raw payload. Internal validation is postgres-only; selector is service_role-only.

- [ ] Add executable SQL negative assertions: wrong org, FAILED/BUILDING/SUPERSEDED/ACTIVE, incomplete manifest, invalid algorithm, stale fingerprints, missing/raw membership, conservation failure, NULL wildcard, version overflow, and stale CAS all reject with no selection mutation.
- [ ] Implement the spec table PK/FK/checks, RLS and direct DML revocations. No DELETE/TRUNCATE permission for the normal selector caller.
- [ ] Implement full-generation validation using the existing authority snapshot and validator contracts. Validate all manifest cohorts/areas; never recertify a caller-selected subset. Existing persisted segments are read, not rewritten.
- [ ] Implement advisory cohort lock, exact CAS, version increment, tombstone retention, generation lock and short source SHARE locks with 1s timeout. Match existing source order `deputy_import_batches`, `deputy_raw_timesheets`, `shift_rules`. Disable can use stale generations but still requires exact prestate. No automatic retry.
- [ ] Build the shared view joining organization + generation + person + payroll week, enabled selection and READY/validation_complete. Project Employee and Window fields without helper calls, aggregates, timestamp ownership derivation or competing-generation UNION.
- [ ] Test a 24-person manifest: selecting one person/week changes exactly one selection; both views expose only that person's selected segments across all areas. Other 23 persons remain unselected. A second real Employee B journey affects B headcount; physical A spillover does not.
- [ ] Run static tests to PASS. Execute the SQL contract only on a verified disposable target; otherwise mark SQL tests NOT EXECUTION-CERTIFIED, not PASS.
- [ ] Commit only the migration and directly related tests. Record file hash; later task additions must retain the same version and be reported as local development of this never-applied draft.

### Task 3: Implement separate bounded coverage and freshness certification

**Files:** same new migration, static test, SQL contract.

**Consumes:** shared selection/projection set; existing hybrid authority SQL; existing effective ownership resolver; Task 2 internal generation validation.

**Produces:** `labour_v3_window_domain_v1(uuid,date,date) RETURNS jsonb` internal read-only authority-domain evidence; `labour_v3_certify_window_v1(uuid,date,date) RETURNS jsonb` service_role-only certificate. Views do not invoke either function.

Response fields: `contractVersion = LABOUR_V3_WINDOW_CERTIFICATE_V1`, organizationId, from, to, checkedAt, statuses[], blocking, certifiedComplete, requiredCohorts[], selectionVector[], generationChecks[]. No names/raw timesheets. Generation checks bind full-manifest authority/rules fingerprints and exact selection versions.

- [ ] Write SQL assertions that invalid/inverted/>31-day requests and >8-week expansion reject; >64 manifest cohorts are never truncated; absent rows or empty selections cannot alone establish certified zero.
- [ ] Implement contributor discovery from the authoritative raw domain plus effective ownership, using the existing hybrid CTE semantics and 24h journey bound. Do not start discovery from selection rows. Enumerate source coverage for empty dates and classify incomplete versus ambiguous evidence explicitly.
- [ ] Test a new authoritative person not in selections: requiredCohorts includes that person/week and status is MISSING_COHORT (or appropriate adjacent partial), never CERTIFIED_COMPLETE. Test a multi-area person and previous-week physical overlap even when no current-week selection names that person.
- [ ] Recertify each selected generation once, using its full original manifest and existing fingerprint serialization. Keep original helper postgres-only. No DML, writer calls, hidden grants or source-table mutation in certificate code.
- [ ] Prove one consistent authority/selection snapshot. Do not assume nested calls to the existing VOLATILE helper under READ COMMITTED share one snapshot. Use an explicitly REPEATABLE READ/SERIALIZABLE read-only transaction for this local certificate contract, reject weaker isolation fail-closed, and test that rejection. Do not alter global DB/PostgREST configuration to make the test pass. Future API transaction integration remains out of scope.
- [ ] Implement deterministic multiple-status response: ambiguity/stale force blocking=true; partial/missing force certifiedComplete=false; complete is the only status when all invariants pass. Unexpected SQL/authority errors propagate fail-closed and do not become an empty complete response.
- [ ] Test a still-observable numeric total with stale/ambiguous authority remains blocked. Test generation made non-READY, disabled selection, changed rules, changed manifest and renamed/new source identity; certificates cannot be silently reused across changes.
- [ ] Run static tests and disposable SQL contract with separate evidence labels; commit only relevant local files.

### Task 4: Reconcile disconnected projection and coverage fixtures

**Files:** fixture JSON, fixture test, SQL contract, local result report.

**Consumes:** G1/G2 observed segment evidence and Phase 2.6A deltas. Synthetic cohort keys are opaque IDs; no invented prior READY generation.

**Produces:** local proof of intended projection semantics, explicitly distinct from SQL execution certification.

- [ ] Write failing fixture assertions before adding the disconnected reference expectations. It is a test-only join/projection oracle, not a second authority or calculation engine; it never imports into apps/shared runtime exports.
- [ ] Assert G1 contributes on 28 Sep: INDIRECT 7.215686274509803 h and SCREEN_PRINT_CREW 8.210526315789474 h. G2 does not duplicate those raw/segment IDs.
- [ ] Assert exact 28 Sep DTG Window A=15.458333333333332, B=16.708333333333332; A+B matches legacy 32.166666666666664 within 1e-9. Check actual 14:00/14:30/15:00 intervals, not only totals.
- [ ] Assert one explicit cohort selection includes only its person/week across all areas from a multi-person generation; alternate competing READY segments are excluded, not DISTINCT-merged.
- [ ] Assert 21 Sep partial prior coverage while observed SCREEN_ROOM A=7.666666666666666 h remains displayable diagnostically. The known 7.712962962962962 h missing contribution explains the gap but is not inserted as a canonical segment/generation.
- [ ] Assert 05–11 Oct incomplete coverage cannot certify 05 Oct solely from FULL through 06 Oct. Assert same-week selected rows do not prove absence of adjacent contributors.
- [ ] Reuse existing calendar fixtures for cross-midnight C and Friday exact boundaries. Verify headcount only by Employee dimensions and productive aggregation only by Window dimensions; assert raw totals unchanged and each segment appears at most once in either projection.
- [ ] Run `node --test scripts/tests/labour-v3-read-model-fixtures.test.mjs scripts/tests/labour-v3-read-model-static.test.mjs`; expect PASS. Report fixture proof separately from actual PostgreSQL proof.
- [ ] Commit only these fixtures/tests/report updates.

### Task 5: Certify SQL execution and concurrency if a disposable target exists

**Files:** disposable SQL contract and concurrency harness.

**Consumes:** full local migration plus a verified disposable database containing prerequisite schema. No migration replay against linked Production.

**Produces:** actual SQL apply/rollback/CAS/snapshot evidence or NOT EXECUTION-CERTIFIED.

- [ ] Detect existing authorized disposable tooling/target read-only. No Docker, random global tools or Production credential use. Stop execution portion if the target cannot be proven disposable; retain static/fixture test results.
- [ ] Add explicit host/database/project rejection for known Production and Preview, an approval sentinel, ON_ERROR_STOP and transaction rollback to the harness. Do not log connection strings.
- [ ] Run local draft migration and guarded SQL contract in the disposable DB; verify empty selections, projection shape, unchanged old definitions/ACLs/rows and rollback restores prestate. Selector execution occurs only in fixtures; no seed in migration.
- [ ] Run two-connection first-insert and replacement races: at most one CAS succeeds for the same prestate, version advances once, loser leaves no mutation. Test lock timeout with another source writer holding a conflicting lock; selection fails promptly and no automatic retry occurs.
- [ ] Test concurrent selection/source-authority changes under the certificate's required consistent read snapshot; the response describes one snapshot only and a subsequent certificate reflects the changed state. Verify weak-isolation requests reject.
- [ ] Record independent results for SQL apply, contract, atomicity, CAS concurrency, source-lock timeout and certificate snapshot consistency. A static test cannot stand in for any of them.
- [ ] Commit only execution tests/evidence, without disposable credentials or generated sensitive raw data.

### Task 6: Final local gates, recovery artifact and no-consumer proof

**Files:** unapplied recovery SQL, local result report; no consumer/runtime file changes.

**Consumes:** all task artifacts, original migration/view/ACL hashes and baseline Git status.

**Produces:** final migration filename/SHA, ordered object list, local gate results and Phase 2.6 PASS WITH COVERAGE LIMITATION only when evidence supports it.

- [ ] Draft non-destructive recovery SQL revoking execute on only the new selector/certificate functions. Preserve all selections/tombstones/V3 tables and evidence; do not replace old helper/writer ACLs, drop tables, update generations or repair ledger.
- [ ] Run focused static/fixture tests, then `pnpm --filter @tsd/shared test`, `pnpm --filter @tsd/web test`, `pnpm --filter @tsd/oracle-sync test`, `pnpm lint`, `pnpm typecheck`, `pnpm build` from the suitable isolated implementation worktree. Verify test/build scripts do not execute operational sync/Oracle calls. Use existing Production-compatible local build environment without printing/changing credentials or remote writes.
- [ ] If canonical schema checkout cannot run an application gate, record the exact worktree/HEAD used for that unchanged runtime regression gate; do not present it as SQL execution proof or merge its history. Do not improvise unrelated baseline repairs.
- [ ] Run `git diff --check` and scoped file-list checks. Search active apps/shared/connector entrypoints for new read-model imports/calls; expect zero. Compare all baseline hashes and existing ACL definitions; expect unchanged.
- [ ] Restore only newly generated tracked caches if needed after proving they were not preexisting user changes. Stage only explicit Phase 3A files, commit locally, and distinguish clean task diff from the older canonical worktree dirtiness that must remain preserved.
- [ ] Record migration filename/hash, selector CAS/isolation tests, projection/coverage fixture results, SQL execution status, full gate counts, immutable migration hashes and old/new runtime scope. No push or activation is required by this plan.
- [ ] Return the requested Phase 3A report. Legacy canonical, selection seeds=0, ACTIVE=0, Production changes=0. If execution certification is missing, keep activation blocked even when local static/fixture/application gates pass.

## Plan self review and handoff

Every spec requirement maps to Tasks 1–6. The two additional user gates are executable assertions in Tasks 2–4. Selection/certification interfaces are fixed above, data projections remain deterministic, and all execution evidence levels stay separate.

The isolation requirement in Task 3 is a fail-closed implementation constraint, not a Production configuration change. It must be visible in the final RPC contract and tests; a future ordinary PostgREST caller cannot be presumed compatible without its own transaction integration review.

Review this written plan before local migration implementation. Execution remains inline with no subagents. No Production apply/cutover or active consumer integration follows automatically from plan approval.
