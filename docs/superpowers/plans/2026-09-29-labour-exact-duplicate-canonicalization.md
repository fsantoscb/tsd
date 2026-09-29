# Labour Exact-Duplicate Canonicalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove only exact Deputy timesheet import copies from the canonical Labour selection, without altering raw history, segmentation, breaks, or unrelated production behavior.

**Architecture:** Replace the internal ranking in `public.v_current_labour_segments` using `CREATE OR REPLACE VIEW`, not `DROP VIEW`. A CTE selects one raw row per conservative, normalized business tuple plus the nullable stable source ID; existing `labour_segments` continue to join by `source_timesheet_row_id`. No new public helper view is needed, avoiding new access grants or a second consumer contract.

**Tech Stack:** PostgreSQL/Supabase versioned SQL migrations; rollback-wrapped SQL contract tests; existing pnpm/Vitest monorepo checks.

**Spec:** `docs/superpowers/specs/2026-09-29-labour-exact-duplicate-canonicalization-design.md`, as amended by the user's 29 September design-approval clarifications.

## Global Constraints

- Base lineage must include `8450c3472e2a1481e732809e628ee9324183711b`; use the isolated canonical schema worktree, not the web-only migration lineage.
- One new migration: choose the version from the actual project-convention timestamp at migration creation, strictly later than the canonical lineage and verified unused. Do not preset a numeric version in this plan or silently renumber an already-created migration.
- Do not edit historical migrations, drop the existing view, or alter any table, row, FK, break/shift rule, Capacity, KPI formula, UI, or Performance layout.
- Preserve `v_current_labour_segments` output names, order, types, grants, owner, security options, and downstream contract exactly. Snapshot `pg_attribute`, `pg_get_viewdef`, `reloptions`, owner, and ACL before and after in the isolated SQL test database.
- Preserve `deputy_raw_timesheets`, `deputy_import_batches`, and `labour_segments` byte-for-byte; only canonical selection changes.
- Source IDs: both NULL may deduplicate; equal non-NULL may deduplicate only with identical business tuple; different non-NULL never deduplicate; NULL versus non-NULL never deduplicate. Do not turn empty/nonempty IDs into an implicit equivalence class.
- Identity must compare actual normalized fields, not a hash alone. Use only trim plus current case normalization for text; no aliases, accents, fuzzy matching, inferred meal breaks, rounding, or latest-batch preference.
- Keep the conservative tuple in Task 2 intact even if it leaves additional copies. For this first change, false negatives are preferable to false-positive merges.
- No Production migration apply, database write, deployment, Preview, scheduler, or connector change during this implementation stage.
- A safely isolated SQL execution path is mandatory for the label `SQL EXECUTION-CERTIFIED`; otherwise report `NOT EXECUTION-CERTIFIED` and do not claim the implementation gate passed.
- Before any later Production activation, run a read-only Production audit proving no exact group has a representative without segments while an identical sibling has valid segments. If found, STOP; never choose a segment-bearing sibling as an alternate authority.

## Review Focus

1. Null stable ID versus populated stable ID with otherwise identical content: retain both; Task 1 SQL test.
2. Different populated stable IDs with identical content: retain both; Task 1 SQL test.
3. Two records with same stable ID but revised end/meal/hours: retain both, with no authority winner; Task 1 SQL test.
4. Representative raw row lacking segments while another exact copy has segments: fail orphan audit before accepting any view change; Task 1 SQL test and Task 3 gate.
5. `CREATE OR REPLACE VIEW` silently changing a type, order, owner, option, or grant: reject via catalog comparison; Task 1 SQL test and Task 3 gate.

---

### Task 1: Write the canonical-selection contract tests

**Files:**
- Create: `supabase/tests/deputy_exact_duplicate_canonical_selection.sql`
- Reference only: `supabase/migrations/001_canonical_baseline.sql:3200`
- Reference only: `apps/web/lib/deputy-import.ts`

**Interfaces:**
- Consumes: current `deputy_raw_timesheets`, `deputy_import_batches`, `labour_segments`, and `v_current_labour_segments` schemas.
- Produces: a rollback-wrapped SQL contract test that the Task 2 migration must satisfy.

- [ ] **Step 1: Freeze the baseline catalog and fixture expectations.** In the test, snapshot the current view's ordered `(attnum, attname, atttypid, atttypmod)`, owner, ACL, and reloptions into temporary test state *before* including the new migration. Use a synthetic isolated organization/batch fixture according to existing test conventions, all inside `BEGIN ... ROLLBACK`. Before invoking `psql`, independently reject any test URL whose projectRef is `eziirebccovlvhaonsgw` or whose target is not proven disposable.
- [ ] **Step 2: Write failing duplicate-selection tests.** Insert accepted/completed raw rows and matching segments for groups of 2, 4, and 6. Vary filename, source row number, source row key, and batch, but keep business tuple equal. Assert one representative raw ID and one copy's segment contribution per group. Assert the selected ID is the minimum UUID and remains the same on two successive reads.
- [ ] **Step 3: Write failing separation tests.** Assert nonidentical business fields, distinct legitimate timesheets, Stewart 28 September 05:30–14:00 versus 05:30–14:32, different non-NULL source IDs, and NULL-versus-non-NULL source IDs stay separate. Equal non-NULL IDs collapse only with identical business content; both NULL IDs may collapse when content matches.
- [ ] **Step 4: Write preservation and safety tests.** Assert raw/batch/segment counts and row values are unchanged, every qualifying segment has a valid selected raw-row association or raises a test failure, and no nonduplicate contribution changes. Add a fixture where the deterministic representative has no segment while its identical sibling does; run that negative fixture in its own rollback-wrapped transaction so it cannot make the ordinary success test fail. Verify the post-migration view's ordered columns/types, owner/ACL/options against the pre-migration snapshot.
- [ ] **Step 5: Verify red only on an isolated disposable database.** Structure the SQL contract as baseline snapshot and fixtures, a `\ir` to the as-yet-uncreated migration path chosen at Task 2 creation time, then assertions, all inside a transaction that ends `ROLLBACK`. Before writing the migration file, its missing include gives a red test. Run `psql $env:TEST_DATABASE_URL -v ON_ERROR_STOP=1 -f supabase/tests/deputy_exact_duplicate_canonical_selection.sql` in PowerShell only after independently confirming `TEST_DATABASE_URL` is disposable. If no safe SQL runner exists, record `NOT EXECUTION-CERTIFIED` and do not substitute Production execution.
- [ ] **Step 6: Commit the test alone.** Commit only the new SQL test with message `test: specify exact Deputy canonical selection`.

### Task 2: Implement the single view-only migration

**Files:**
- Create: `supabase/migrations/<actual-unused-timestamp>_deputy_exact_duplicate_canonical_selection.sql`
- Test: `supabase/tests/deputy_exact_duplicate_canonical_selection.sql`

**Interfaces:**
- Consumes: Task 1 contract, and the exact current output projection of `v_current_labour_segments`.
- Produces: the same public view signature, with a new internal deterministic canonical raw-row selection.

- [ ] **Step 1: Confirm migration version and source contract.** Check `git status --short` is clean after Task 1 commit, choose the project-convention timestamp at creation time, verify it is unused and later than every current canonical migration, and verify the view definition matches the recorded baseline. If the test's deferred include path needs filling, do it with that same version; never silently renumber later. Stop on mismatch.
- [ ] **Step 2: Implement a CTE over accepted raw rows in completed batches.** Partition by organization, nullable `source_timesheet_id` as its own exact value, and the business tuple: conservatively normalized employee (`employee_id` when present, otherwise `person_key`, with source-kind separation), normalized `display_name`, `timesheet_date`, normalized `raw_area` and `normalized_area`, exact `start_at`, `end_at`, `total_hours`, persisted `meal_break_hours`, `approval_status`, and `row_status`. Use `UPPER(BTRIM(...))` only where the existing parser already case-normalizes the corresponding text; do not derive a break value or coerce NULL into an unrelated value. SQL `PARTITION BY` treats both NULL source IDs together but keeps NULL distinct from any non-NULL ID. No hash-only equality.
- [ ] **Step 3: Select the lowest UUID `id` within each exact partition.** Use `row_number() OVER (... ORDER BY id ASC)` and retain `rn = 1`; join existing segments to that raw ID and reproduce the existing view's exact ordered SELECT list. Do not use `imported_at`, `created_at`, batch, filename, `source_row_key`, or source-ID recency as authority. Use `CREATE OR REPLACE VIEW public.v_current_labour_segments AS`; never drop the view. Do not change grants, ownership, or security options.
- [ ] **Step 4: Run the Task 1 SQL test in the isolated database.** Recreate the disposable database at the canonical migration baseline and run the test, which includes the new migration inside its rollback transaction. Do not put explicit `BEGIN`/`COMMIT` in the migration file because the test owns the transaction. Expected: all duplicate/separation/preservation/catalog/orphan assertions pass. If safe SQL execution is unavailable, stop before claiming this gate.
- [ ] **Step 5: Commit only the migration.** Message `fix: canonicalize exact Deputy import copies`. Keep the Task 1 test commit separate.

### Task 3: Local regression, diagnostic, and handoff gate

**Files:**
- Modify only if a directly relevant test gap is found: `supabase/tests/deputy_exact_duplicate_canonical_selection.sql`
- Reference only: `packages/shared/__tests__/labour-segmentation.test.ts`, `packages/shared/src/labour-segmentation.ts`, and current Labour/KPI read functions.

**Interfaces:**
- Consumes: Task 2 migration and Task 1 contract.
- Produces: an evidence report, not a Production activation.

- [ ] **Step 1: Run the complete SQL contract and read-only orphan audit.** On the isolated DB, certify view signature/ACL/options unchanged; raw, batch, and segment tables unchanged; no accepted/completed segment is silently orphaned. An orphan or signature change is `FAIL`, not a warning. Separately prepare the read-only Production representative-without-segments audit as a mandatory *future activation* gate; do not execute Production SQL in this local-only task.
- [ ] **Step 2: Recalculate source-watermarked local diagnostics.** For 23/24/25/28 September 2026 compute current versus exact-copy-only productive hours, overtime hours, and prints/hour. Cross-check 23/24/25 against approximate 38.18/35.83/17.00 productive hours; never hardcode them as live acceptance. Mark 28 September `AMBIGUOUS` because both Stewart revisions remain. Prove prints, garments, Capacity, and Utilisation formulas and inputs unchanged.
- [ ] **Step 3: Run focused and full relevant gates.** Run the isolated SQL contract, `pnpm --filter @tsd/shared test -- labour-segmentation`, `pnpm test`, `pnpm lint`, `pnpm typecheck`, `pnpm build`, and `git diff --check`; inspect actual package scripts first and use their supported equivalent if a focused filter is unavailable. Existing 20-minute paid-break tests must pass; Deputy meal must not be deducted again.
- [ ] **Step 4: Review exact diff and status.** Confirm only the new migration and directly relevant SQL test were added; no historical migration or application runtime file changed. Confirm clean worktree after local commits. Report SQL certification honestly, source counts, representative IDs, nonduplicate invariants, ambiguous revisions, test results, and the local implementation gate.
- [ ] **Step 5: Stop.** Do not apply migration to Production, change scheduler, deploy, or use Preview. Request a separate, explicit Production activation approval only after local gate passes.

## Self-review notes

The plan covers the approved source-ID matrix, conservative business equality, deterministic technical winner, view contract, raw-history preservation, orphan-fail rule, break invariant, local diagnostics, and no-Production boundary. The existing approved design's broader phrase “key nulls” is refined here by the explicit four-case stable-ID rule supplied at design approval. No revision-winner or shift-boundary work is included.
