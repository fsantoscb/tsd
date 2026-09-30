# Deputy Hybrid Snapshot Authority Implementation Plan

> **For agentic workers:** Use the approved Stage 7 specification as the binding brief. Implement locally; do not apply to Production.

**Goal:** Select one certified FULL Deputy batch per organization and source timesheet date, falling back to the current exact-content rule only where no eligible FULL batch covers that date.

**Architecture:** Select source-date authority before raw-row deduplication and before joining existing Labour segments. Equal latest report timestamps fail closed and are surfaced by a diagnostic query. Preserve the 22-column view contract and all stored segment semantics.

**Tech Stack:** PostgreSQL view migration, SQL contract tests, existing pnpm monorepo gates.

**Spec:** `C:/Users/Felipe.Santos/.codex/attachments/c4ee3d1f-83a9-4642-92f8-ac7ebc312d20/Pasted text.txt`

## Global Constraints

- Canonical base: `2aab17dfdfcfdcb5d94aacf8fdd71b05e82d138a`.
- One new timestamped migration; historical migrations unchanged.
- No Production write, migration application, deployment, Preview, Deputy import or Labour cutover.
- No raw, batch or segment update/delete; no changes to shifts, breaks, Capacity or KPIs.

## Review Focus

- A later FULL batch with a deleted employee/date must not carry the old row forward.
- Equal latest timestamps must not choose by UUID or import time.
- A source-date 29 Sep segment assigned operational 28 Sep must remain selected.
- Dates without eligible FULL coverage must preserve the old exact-dedup result.
- The view's ordered 22-column contract, owner and ACL must remain unchanged.

## Task 1: Read-only authority query and diagnostics

**Files:** SQL contract test and migration query design.

- [ ] Capture the current Production view fingerprint, shape and relevant current values.
- [ ] Build a read-only query selecting one eligible FULL batch by source date and failing closed on latest-timestamp ties.
- [ ] Verify 15–29 Sep simulation across all Labour areas and Stewart's cross-midnight segments.
- [ ] Obtain EXPLAIN without ANALYZE and decide whether an index is justified.

## Task 2: Versioned migration and contract test

**Files:** `supabase/migrations/<timestamp>_deputy_hybrid_snapshot_authority.sql`, `supabase/tests/deputy_hybrid_snapshot_authority.sql`.

- [ ] Write fixtures/assertions for fallback, replacement, revision, deletion, area change, new row, internal duplicate, historical date, tie and cross-midnight.
- [ ] Create only the new migration replacing `public.v_current_labour_segments` selection; preserve its projection.
- [ ] Confirm no table write or speculative index and statically compare view contract.
- [ ] If no disposable DB exists, mark SQL execution NOT CERTIFIED; never run test writes in Production.

## Task 3: Gates and commit

- [ ] Run relevant and full tests, lint, typecheck, build, `git diff --check`.
- [ ] Recheck Production read-only simulation and unchanged Production view fingerprint.
- [ ] Commit only migration, focused test and this plan; require clean worktree.
- [ ] Report Production unchanged and Deputy import temporarily paused.
