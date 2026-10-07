# Labour V3 Stage 3 — versioned shadow persistence

Status: written specification for review; implementation and Production application have not started.

## Approved intent and boundaries

Persist complete V3 shadow generations without changing current Labour authority or any live consumer. Production identity is `eziirebccovlvhaonsgw`, organization `f39ce894-e039-4329-aeca-85e46e193aef`. Schema base is `3c939767d4b0640abe4b1a3b24690648fb52687a`; web reference is `1430e6ce15378cd2550cf7ac6fd4df7bf22bfe2d`. Keep histories isolated.

The immediate authorization is documentation and local implementation only. No Production write, migration application, deploy, Preview, scheduler change, active writer integration, consumer change or cutover. A later explicit activation approval is required.

Keep `20261007084113_labour_v3_shadow_generations.sql` byte-identical. Add a separately versioned writer migration with a project-convention timestamp generated at creation, later than the lineage and verified unused. Do not renumber historical or existing drafts. No legacy DDL/DML. No raw-table constraint change.

## Objects and local surfaces

- Existing Stage 2 draft creates only `public.labour_segment_generations` and `public.labour_segments_v3`, their constraints, indexes and security metadata.
- New writer migration adds `public.persist_labour_v3_generation_v1` and only directly necessary server-only authority/validation helpers. No diagnostic view is necessary in this stage.
- SQL contract tests exercise writer, security, failure and concurrency on an authorized disposable database only.
- A disconnected local adapter obtains bounded authority input, invokes the existing TypeScript builder, prepares the writer request and compares persisted read-back. No importer, route, shared-index export or scheduler imports it.
- A recovery SQL artifact disables this writer while preserving V3 tables, generations and segments. It is excluded from normal CLI push inputs.

## One hybrid authority semantic source

The writer must not independently implement snapshot winner selection. Its raw-selection helper consumes the exact CTE prefix of the current `pg_get_viewdef(public.v_current_labour_segments, true)`, ending at `canonical_raw`, before the legacy segment join. The local adapter consumes that same helper, not a TypeScript authority algorithm.

Check the expected view-definition fingerprint and supported CTE/result shape. An unrecognized definition fails closed; never silently use a cached historical definition or fall back to joining legacy segments. Bounds and organization are parameters, not interpolated input. Output selects accepted, completed canonical raws with `rn = 1` and applies tenant/source-envelope bounds without loosening the existing business tuple.

Preserve latest eligible certified FULL per source date, tied-latest fail-closed behavior, existing permitted fallback and conservative exact deduplication. Completeness certification is stricter than raw selection: every date in the required envelope must have exactly one latest eligible FULL, including dates without raw activity. Fallback alone does not certify a complete V3 payroll cohort. Use the existing eligibility/winner semantics for this coverage check; do not introduce import-time or UUID tie-breaking.

## Payload and authority evidence

Use a versioned request contract `LABOUR_V3_SHADOW_V1`. It carries generation UUID, organization, generation/algorithm versions, employee-week cohort manifest, envelope dates, expected authority/rule fingerprints, expected raw and segment counts, expected totals and complete builder segments. Missing or unknown versions fail closed.

Cohort identity is organization + persisted person_key + employee payroll week, across all areas. Use actual person keys in persistence, never audit pseudonyms. Each requested person/week must be complete. Select all authoritative raws whose resolved ownership belongs to those cohorts; reject omitted or extra raws. An empty unspecified cohort is not certified by this first builder.

Fingerprints are SHA-256 of explicit server-produced canonical text: ordered raw identities and all source fields affecting calculation, relevant FULL metadata/coverage/certification, view-definition identity, ordered cohort manifest and effective rule rows. The read adapter receives those canonical fingerprints; it does not invent a second JSON serialization. A hash assists comparison, not semantic equality. Raw membership and fields must also compare relationally.

Use real generation UUIDs, not Stage 2 diagnostic labels. Algorithm version identifies the reviewed builder artifact and its content digest. Generation version identifies this persistence contract, not an authority ranking.

## Consistent snapshot and stale authority — review-critical decision

REPEATABLE READ by itself cannot discover a FULL committed after its snapshot. A second fingerprint query inside that snapshot is not a valid freshness proof. Row locks cannot prevent a newly inserted FULL or rule (phantom). Advisory locks alone cannot coordinate with current importers, which do not acquire the new lock.

Proposed strict solution: the writer requires READ COMMITTED, takes transaction-scoped advisory locks for all requested cohorts in deterministic order, then briefly takes SHARE locks on `deputy_import_batches`, `deputy_raw_timesheets` and `shift_rules` in fixed order before capturing authority/rules. These locks block INSERT/UPDATE/DELETE while permitting ordinary SELECT reads. Under those locks, subsequent volatile SQL statements observe a stable input set. Expected fingerprints captured before the call must match this locked state; changes before lock acquisition produce FAILED/STale diagnostics. Concurrent changes after acquisition wait until the transaction completes, then make the stored generation detectably stale; no activation occurs.

Use a bounded local function lock timeout of 1 second, preserve the existing statement timeout, and do not retry automatically. Input locks are held through final validation/READY, including the enclosing transaction. Calls must use a short standalone transaction; never an open interactive transaction. Abort validation on unsupported isolation level. Lock ordering, duration and release need disposable-database execution tests before certification.

This is a new operational consideration requiring written-spec review: table-level SHARE locks affect all tenants' imports briefly, not only selected raws. No such lock has been acquired in Production. If that blocking surface is unacceptable, do not weaken stale checks or alter existing importers automatically; stop and review the design.

## Prestate, concurrent duplicates and status transitions

The writer creates a new BUILDING generation, or accepts an existing matching BUILDING generation with zero segments. Lock the generation row. Existing READY/ACTIVE/SUPERSEDED/FAILED IDs are rejected without mutating them. Metadata, manifest, versions and expected fingerprints must match the stored BUILDING prestate exactly.

Take sorted cohort advisory locks before checking other generations. Reject another READY generation that includes any requested identical cohort with the same authority/rule/algorithm fingerprints; do not silently duplicate or union it. A retry with an already READY UUID returns a prestate rejection, not a new generation or overwrite. New fingerprints represent a separate version, never superseding automatically.

BUILDING creation is outside the inner exception block; segment writes and validation/READY are inside one exception subtransaction. A caught validation/insertion failure rolls back all inner segments and marks only this BUILDING generation FAILED with non-sensitive diagnostics. Return a structured failure so the caller does not roll back the FAILED record by throwing inside the enclosing transaction.

Transaction cancellation, connection loss or outer transaction rollback may remove the entire attempt, including FAILED. No design can guarantee a persisted failure record when the transaction itself cannot commit. Such cases are reported as no committed generation/unknown outcome and require read-back, not automatic retry. They must never leave a committed READY partial generation.

Never assign ACTIVE. Never change prior generations or live selection.

## Database READY validation

Before any segment insertion validate organization exists, every raw exists and belongs to that organization, generation tenant matches, exact authoritative membership/fields, FULL envelope, rules, prestate, duplicates and finite numeric inputs. Cross-org failure rejects the whole generation; no filtering and no raw reassignment.

Validate and then verify read-back counts and sums within `1e-9 h`:

- Every expected raw contributes exactly one contiguous segment chain with exact raw start/end coverage, no gaps, overlaps or duplicate `(generation, raw, segment_start)`.
- Paid equals persisted raw total_hours per raw; Productive + Paid Break = Paid; Regular + OT = Paid.
- Paid Break is 1/3 h once if Paid >= 4, otherwise zero. No inferred new break or second unpaid deduction.
- Person, area, approval, calendar/hour, allocation and calculation version match their approved source/contract.
- Exactly one employee ownership per raw: literal Brisbane clock-in, no tolerance, original scheduled bounds, previous-day cross-midnight ownership, one employee payroll week. Ambiguous rules fail.
- Every segment lies within one production window, including Friday boundaries; actual cut intervals match the existing builder's hour/window cuts.
- Regular/OT are nonnegative and follow chronological raw-start/raw-ID order, original scheduled eligibility, weekday/weekend, shared person/day 8 h and person/week 38 h across areas. Validate per-segment allowance allocation, not only aggregate upper bounds.
- No mixed generation/org, missing source contribution or unexpected segment. Counts and distributions match declared expected values and authoritative evidence.

The TypeScript builder remains the local calculation reference. SQL validates these rules, but no second authority selector is authored. READY follows validation_complete only after persisted checks. Record fingerprints and validation evidence with the generation.

## Security and indexes

Owner postgres, fixed safe function search_path and schema-qualified objects. SECURITY DEFINER is allowed only with explicit service-role boundary. Revoke EXECUTE from PUBLIC/anon/authenticated; grant only service_role. Helpers are similarly restricted. RLS remains enabled. No broader application read access is added.

Existing new-table indexes cover employee cohort/week and bounded production-window analysis. Generation PK and `(generation_id, source_timesheet_row_id, segment_start)` uniqueness cover read-back/source association. Add no speculative index on legacy tables. No browser or web endpoint exposes the writer.

## Local tests and evidence gates

Test valid BUILDING -> READY, invalid prestate immutability, changed fingerprints, missing/extra raws, incomplete/ambiguous envelopes, different-organization raw, duplicate identities, nonfinite/negative fields, conservation, owner/window boundary mismatch, allowance allocation, missing segment, mid-insert failure, no partial persistence and FAILED diagnostics. Test concurrent identical-cohort submissions and phantom authority/rule changes with two disposable sessions. Test lock timeout and full rollback, restricted ACL, generation isolation and disabling the writer without deleting evidence.

Re-run focused V3/shared/web/connector tests, lint/typecheck/build/diff check independently in the appropriate workstreams. Preserve Stage 2 artifacts; restore only generated tracked caches after generators exit. Static SQL tests are not execution certification. No Production negative tests or foreign-org fixture writes. No Docker or Preview. Without authorized disposable SQL execution, label NOT EXECUTION-CERTIFIED and require explicit acceptance before any first Production execution.

## Future activation sequence — not authorized now

Capture fresh identity, ledger, view definition/22-column metadata, legacy counts/totals and unchanged Performance reference data. Compare Stage 2 draft digest with the reviewed artifact. Align canonical lineage; temporary CLI workspace outside Git contains applied migrations plus only V3 schema/writer migrations, excluding recovery artifacts. Exact dry-run, API/organization health and rollback preparation are mandatory; any divergent lineage stops application.

After later explicit approval, apply only approved versioned migrations. Verify initial V3 counts zero and legacy schema/rows/results unchanged. Re-certify authority/rules and complete cohorts; build first 21–27 Sep locally, call writer once, read back every row/distribution and compare. Only after exact reconciliation and live safety pass repeat fresh certification/build/persist/read-back for 28 Sep–04 Oct. No automatic retries.

Local diagnostics from persisted READY rows must match local Stage 2 projections: window productivity, employee headcount/Capacity via unchanged calculateKpis, and scoped Daily Flow date movement. No live consumer imports V3. Recompute stored fingerprints on diagnostic reads to detect later stale generations; retain stale evidence without automatic activation or deletion.

## Non-destructive recovery and completion

Recovery artifact is a separately reviewed versioned migration revoking writer/helper execution from service_role (and confirming PUBLIC/anon/authenticated remain revoked), preserving all tables and data. It is not included in activation dry-run. No DROP TABLE, ledger repair or automatic recovery application. Unexpected live Labour/Performance/Capacity/Flow changes fail the stage; stop persistence and use the approved recovery procedure, not an ad hoc repair.

Stage 3 Production PASS later means two READY shadow generations reconcile and legacy/live health remain unchanged. It never means V3 canonical or Capacity/Performance cutover. SAVEPOINT READY is a report, not permission to create a tag.

## Current review checkpoint

This specification incorporates the approved architectural intent and adds explicit consistency/lock and transaction-failure semantics that must be reviewed before the implementation plan. No source code, migration or Production runtime has changed during specification preparation.
