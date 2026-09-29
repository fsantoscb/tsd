# Labour Canonicalization Production Activation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task. This document is a decision package only; execution requires separate authorization.

**Goal:** Replace only `public.v_current_labour_segments` with the exact-duplicate selection from `20260929173001_deputy_exact_duplicate_canonical_selection.sql`, with a bounded lock window and an exact view-definition rollback.

**Architecture:** The migration uses `CREATE OR REPLACE VIEW`; raw Deputy rows, import batches and Labour segments remain untouched. Before any future activation, certify the migration and rollback SQL in an authorized disposable PostgreSQL database, then verify fresh Production identity, ledger, baseline fingerprint and read-only data diagnostics. On a post-apply failure, restore the captured previous view body, not an improvised formula.

**Tech Stack:** PostgreSQL 17.6 / Supabase migrations, Next.js Production web readers.

**Spec:** User request “LABOUR CANONICALIZATION PRODUCTION ACTIVATION PLAN ONLY — DO NOT EXECUTE”, 2026-09-29.

## Global Constraints

- Production projectRef: `eziirebccovlvhaonsgw`; never use Preview.
- Canonical schema HEAD: `793c70260e1745106d41eff7e8fbac5061005f8c`.
- Migration: `supabase/migrations/20260929173001_deputy_exact_duplicate_canonical_selection.sql` only.
- No changes to Deputy raw rows, batches, `labour_segments`, breaks, shift boundaries, Capacity, KPIs or UI.
- Never manually edit `supabase_migrations.schema_migrations`.
- This plan and rollback artifact are not authorization to apply anything.

## Review Focus

- A selected representative with no segments while its exact sibling has segments must block activation (audit result: zero unsafe groups).
- A non-identical revision must remain a separate contribution; 28 Sep remains ambiguous and must not be described as fixed.
- An unexpected view column/order/type, owner, ACL or reloption change must trigger rollback.
- A long-running reader can block the view replacement; use a short lock timeout, not an unbounded wait.
- Runtime rollback of the view does not undo a successful migration-ledger entry; record it and repair lineage later with a separately approved versioned migration, never manual ledger edits.

## Files

- Activation candidate (unchanged): `supabase/migrations/20260929173001_deputy_exact_duplicate_canonical_selection.sql`.
- Read-only safety audit (unchanged): `supabase/tests/deputy_exact_duplicate_representative_audit.sql`.
- Prepared rollback: `docs/rollback/2026-09-29-v-current-labour-segments-pre-canonical.sql`.
- SQL contract test (unchanged): `supabase/tests/deputy_exact_duplicate_canonical_selection.sql`.

## Task 1: Execution certification and fresh preflight

- [ ] Identify an already-authorized **disposable** PostgreSQL target, prove it is neither Production nor a Preview clone, and run the rollback-wrapped SQL contract test there. Require every assertion to pass and the disposable target to remain unchanged after rollback. If unavailable, keep activation **BLOCKED**.
- [ ] Test the prepared rollback artifact on that disposable target after applying the candidate inside a disposable transaction; confirm its final view fingerprint, owner, ACL, reloptions and 22-column contract. The current rollback SQL has **not** been execution-tested.
- [ ] Re-run tests, lint, typecheck and Production-compatible build from clean HEAD. Confirm exact migration checksum and that it is the only pending migration in the official Production ledger.
- [ ] Read-only: reconfirm Production projectRef, current view definition fingerprint `d38ab739730f066374497a372892277c`, owner `postgres`, captured ACL, `reloptions IS NULL`, and ordered 22-column contract. Stop if any changed since capture; regenerate a new reviewed rollback artifact rather than applying this stale one.
- [ ] Read-only: re-run representative audit, baseline 23/24/25/28 Sep Labour diagnostics, prints, garments, capacity, utilisation, application availability, scheduler status and current database locks. Unsafe groups must be zero.

## Task 2: Separately authorized migration application

- [ ] Choose a low-traffic window and a supported official migration path that records exact version `20260929173001`. Set a short `lock_timeout` and bounded `statement_timeout` for the migration session; do not change database-wide settings. Require that no other migration is pending.
- [ ] Apply exactly the versioned migration once. A transaction error must roll back the attempted DDL automatically; stop and report instead of retrying blindly.
- [ ] Immediately verify the ledger contains `20260929173001`, the view exists, the ordered names/types remain unchanged, and owner/ACL/reloptions match the preflight capture.

## Task 3: Immediate read-only validation

- [ ] Re-run the representative audit: zero unsafe groups or rollback.
- [ ] Recompute by shift and day: 23 Sep ~38.18, 24 Sep ~35.83, 25 Sep ~17.00 DTG productive hours; compare with exact pre-apply diagnostic at a recorded source watermark. Keep 28 Sep **AMBIGUOUS / NOT CERTIFIED** because distinct revisions are intentionally not merged.
- [ ] Verify prints/garments and Capacity/utilisation are unchanged. Verify `/production/performance`, Labour pages and other consumers of `v_current_labour_segments` load without query errors. Do not redesign UI or formulas.
- [ ] Observe errors/latency during the bounded validation window. Record the new view fingerprint, migration completion time and runtime deployment identity.

## Task 4: Failure response

- [ ] Trigger rollback on any migration error, view-contract/metadata drift, unsafe association, unexplained 23/24/25 deviation, downstream query or Production page error, or unrelated Labour consumer failure.
- [ ] If the migration transaction itself failed, verify automatic database rollback and stop. If it committed, execute **only** `docs/rollback/2026-09-29-v-current-labour-segments-pre-canonical.sql` under separate Production authorization, with its bounded lock/statement timeouts; require its fingerprint and metadata assertions to pass.
- [ ] Confirm restored Labour consumers and metrics. Record that the migration ledger still shows the applied version if the migration had committed; request a separate versioned lineage correction. Do not edit the ledger manually or attempt another fix live.

## Decision

**Recommended now: A — KEEP BLOCKED UNTIL A DISPOSABLE DATABASE EXISTS.** The application gates and read-only Production audit do not prove that the new and rollback SQL execute correctly. Option B is a conscious first-execution risk and requires an explicit new Operations authorization after reviewing this package; this task does not exercise it.
