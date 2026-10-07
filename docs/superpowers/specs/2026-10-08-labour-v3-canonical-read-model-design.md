# Labour V3 canonical Employee and Window read model

## Purpose and activation boundary

Phase 3A prepares local additive SQL and disconnected tests for explicit canonical cohort selection. One persisted V3 segment set supplies Employee and Window projections. Legacy remains the Production Labour authority; no active consumer imports the new model.

Production identity is `eziirebccovlvhaonsgw`, organization `f39ce894-e039-4329-aeca-85e46e193aef`. The schema baseline is `f4e747e40537b4031fa357bb3f8a96639a4921c7`; the master savepoint is `production/savepoint-2026-10-08-labour-v3-master`.

No Production write, migration apply, writer call, helper activation, generation rebuild, deploy, Preview or scheduler change is permitted. Existing migration bodies remain immutable. No change to Paid, Break, Productive, Regular, OT, shift rules, legacy Labour, Performance, Capacity or Daily Flow is permitted.

## Evidence and certification target

The Phase 2.6A forensic classified 16 differences as `LEGACY_WINDOW_BOUNDARY_ALLOCATION` and one as `PREVIOUS_EMPLOYEE_COHORT_EDGE`. No real V3 defect or unknown difference was identified. Legacy segmentation classifies a whole hourly segment by its start; V3 cuts at the exact 14:30 boundary.

The certified READY generations are:

- `960e2d30-9b65-4c09-9cb4-d79202b0ee13`: Employee week 21–27 Sep, 971 segments.
- `9d07cf2f-5285-4569-b6e0-6df993a37c83`: Employee week 28 Sep–04 Oct, 912 segments.

These are fixture identities, not default selections. The local migration must seed no selections and set no generation ACTIVE.

Replace the future legacy-equality gate with raw conservation, exact Window containment/classification, unambiguous generation selection, no omitted or duplicated raws, sufficient adjacent-cohort coverage and explained legacy differences. This does not retrospectively certify missing historical coverage.

## Canonical selection table

Add `public.labour_v3_canonical_cohorts` with:

- `organization_id uuid NOT NULL`.
- `person_key text NOT NULL`, nonempty.
- `payroll_week date NOT NULL`, Monday.
- `generation_id uuid NOT NULL`.
- `selected_at timestamptz NOT NULL`.
- `selected_by text NOT NULL`, nonempty operational actor reference.
- `selection_version bigint NOT NULL`, positive, monotonically incremented.
- `enabled boolean NOT NULL`.
- `reason text NOT NULL`, nonempty.

Primary key: `(organization_id, person_key, payroll_week)`. Composite FK `(organization_id, generation_id)` references the existing generation organization/id unique contract. A retained disabled row is a tombstone; its version does not reset. No FK or unique constraint is added to legacy tables.

`selected_by` records the trusted internal operator supplied by the controlled server caller; it is not a substitute for authenticating that caller. No anon/authenticated write path exists.

## Compare and swap selector

Add a versioned selector RPC restricted to `service_role`; normal direct DML on the selection table is revoked. The function is postgres-owned, SECURITY DEFINER, with fixed search_path, schema-qualified relations and explicit input validation. All mutation happens through this path.

The caller supplies organization, person, payroll week, target generation, expected previous generation, expected selection version, enabled state, actor and reason. Creation requires `(expected_previous_generation = NULL, expected_selection_version = 0)` and no row. A retained row requires its exact generation/version, including when disabled. Version increments even when selecting the same generation again. Do not accept NULL as a wildcard.

Serialize the cohort key using a transaction advisory lock, and lock an existing selection row. A competing create or stale prestate fails with a conflict; it never overwrites. A lock hash collision may serialize unrelated keys but cannot authorize a different key. No automatic retry.

Before enabling a target selection, validate same organization, READY, validation_complete, approved algorithm, exact person/week manifest membership, certified complete cohort, current authority/rules fingerprints, valid persisted raw membership and no ambiguity. The algorithm allowlist must use the exact existing certified algorithm identifier discovered during implementation, not a maximum version or caller-provided arbitrary string.

Validate the generation's full manifest, not a subset chosen by the selector caller. All areas of the selected person/week are included. Reject inconsistent segment person/week membership, cross-org contribution, missing raws, duplicated raw intervals or failed conservation. A requested person/week absent from the manifest fails. FAILED/BUILDING/SUPERSEDED/ACTIVE generations are not eligible in this phase.

Selector recertification and mutation use a short critical section with ordered SHARE locks on the existing authority inputs/rules and `lock_timeout = 1s`, plus the target generation row lock. Reuse the existing writer's source-lock list; no TypeScript calculation or reporting occurs under these locks. A timeout fails without changing the selection. This prevents authority changing between recertification and selection commit. Subsequent authority changes are detected by the separate read certificate; selection is not permanent evidence of freshness.

Disabling a selection also requires CAS but does not require recertifying a stale generation. Disabling never changes its generation status or segments. Restoration/replacement is an explicit new version, not a latest-wins fallback.

## Shared canonical segment set

Add an internal canonical segment view joining enabled selections to generations and segments on organization, generation, person and Employee payroll week. Restrict generations to READY and validation_complete; preserve every matching persisted segment and its stable id. Do not join only on generation_id, which would incorrectly select every person in a multi-person generation.

Selection primary-key uniqueness and segment identity ensure each persisted segment appears at most once. Do not UNION competing generations, DISTINCT away duplicates or choose a winner by creation time, UUID or version string. A generation may contain multiple cohorts; different cohorts can explicitly select different certified generations.

This set is not a freshness certificate. Views do not call helpers, recalculate authority or silently replace selections. A stale selection can have observed rows; certification must block their use as certified values.

## Employee projection

Add `public.v_current_labour_employee_segments_v3` over the shared set. Expose id, organization_id, generation_id, source_timesheet_row_id, person_key, area_code, segment_start/end, employee_shift_code, employee_operational_date, paid_hours, paid_break_hours, productive_hours, regular_hours, overtime_hours, payroll_week, approval_status, calculation_version, scheduled_start_at/end_at and selection_version.

Employee dimensions come directly from persisted ownership, never from segment timestamps. Headcount is distinct person_key by organization, Employee operational date, Employee shift and area. One A journey extending physically into B counts in Employee A; a separate real B journey may count in B. Future Capacity inputs use Employee ownership; the present Capacity engine and consumers do not change.

## Window projection

Add `public.v_current_labour_window_segments_v3` over exactly the same shared set. Expose segment identity/provenance, area, physical interval, Window date/shift, Employee date/shift/week, paid/break/productive, approval, calculation and selection versions. Regular/OT may be exposed only as explicitly Employee-payroll traceability fields; OT is not redefined as a Window metric.

Select canonical cohorts first, then filter the requested Window date/shift. Never restrict selection to the generation whose Employee week equals the requested Window week. G1 contributions on 28 Sep must remain visible alongside G2 without duplicate raw/segment contribution. No second Window storage or calculation engine is created.

## Separate bounded certification

Add a read-only, versioned certification RPC with its own ACL, restricted to internal service_role access. It returns certification metadata, not Deputy names/raw payloads. It performs no DML, changes no grants, calls no writer and does not change generation status.

The function may internally reuse `labour_v3_authority_snapshot_v1` under its postgres owner privileges. The preparation helper remains postgres-only and is not reopened to service_role/public. Its one-week/64-cohort validation, full-manifest fingerprint format and hybrid-authority SQL semantics remain unchanged. Do not duplicate the authority algorithm or fingerprint serialization.

The requested operational period is inclusive and at most 31 days. Consider owning cohorts for physically overlapping journeys, including adjacent weeks; the existing maximum journey duration is 24 hours. Enumerate the full affected authority domain using the same hybrid-authority SQL and existing ownership resolver, not only persons already selected. This detects a new/missing person absent from the selection table. Source-date coverage is evidence, not equivalent to operational-date coverage.

Recertify each referenced generation using its complete original manifest, once per generation, within the same database statement snapshot. Never use a caller-supplied smaller manifest. An expanded request requiring more than eight Employee weeks or violating existing 64-cohort helper bounds is rejected, not truncated. Unexpected authority/query failures fail closed; they must not be converted to a complete certificate.

Certification binds to organization, requested period, affected cohort keys, selected generation ids/selection versions, authority/rules fingerprints and checked_at. It describes that snapshot only. Any future separate totals request must match this selection vector and snapshot or recertify; it must not reuse a certificate after selection/authority changes. No consumer integration is implemented in Phase 3A.

## Coverage response and precedence

Return `statuses[]`, `blocking`, `certified_complete`, affected cohort diagnostics and selection vector separately from observed metric values. Preserve multiple reasons rather than hiding one behind an enum.

Statuses are:

- CERTIFIED_COMPLETE: all required cohorts and adjacent contributions proven complete/current/unambiguous.
- PARTIAL_PREVIOUS_COHORT: required prior owning cohort lacks sufficient certification.
- PARTIAL_NEXT_COHORT: required following owning cohort lacks sufficient certification.
- STALE_GENERATION: selected generation authority/rules no longer matches, or eligibility became invalid.
- MISSING_COHORT: required current cohort has no enabled valid selection.
- AUTHORITY_AMBIGUOUS: authority or effective ownership cannot be chosen unambiguously.

If AUTHORITY_AMBIGUOUS or STALE_GENERATION occurs, `blocking = true` and `certified_complete = false`; a numeric observed total does not weaken this rule. Other incomplete statuses permit diagnostic observation only, never a certified total. CERTIFIED_COMPLETE must be the sole status and cannot coexist with a partial/blocking status.

Do not infer missing cohorts from raw minima/maxima alone or certify empty days from missing segments. Require the existing certified FULL source envelope and authority evidence for the entire relevant ownership domain. Where this cannot be proven, return incomplete coverage. Error classification must distinguish incomplete envelope from ambiguous authority; inspect the existing SQL evidence when an existing helper combines those errors instead of mislabeling both as complete or stale.

21 Sep remains PARTIAL_PREVIOUS_COHORT because week 14–20 Sep is incomplete. The known SCREEN_ROOM contribution explains 7.712963 h but is not a fabricated canonical generation. 28 Sep fixtures include G1/G2 spillover; complete status additionally requires all relevant cohorts recertified. Week 05–11 Oct is incomplete; its reports cannot claim complete coverage based on the FULL ending 06 Oct.

## Security and local migration

New tables have RLS enabled and no browser-role policies. Revoke public/anon/authenticated access. Service_role gets required SELECT only; mutations use the controlled selector. Projection and certification access stays server-only. Keep existing V3 writer/helper ACLs unchanged.

The migration creates only new selection/projection/certification objects and their own ACLs. No replacement of v_current_labour_segments or existing helpers. Generate the actual project-convention timestamp at migration creation, strictly after the canonical lineage, verify it unused and do not silently renumber later. No selection seed, ACTIVE transition or Production apply.

Recovery disables new selector/certificate access or explicit selections through approved versioned operations while preserving tables, segments and evidence. It does not drop legacy/V3 tables or repair the ledger.

## Tests and evidence levels

Local fixtures use anonymized IDs and bounded read-only G1/G2 evidence, not employee names or sensitive raw files committed to Git. Test initial CAS, stale CAS, concurrent create/replace, disable/re-enable tombstone versions, cross-org rejection, ineligible statuses, complete manifest/all-area selection, approved algorithm, stale fingerprints, missing/new cohorts, projection uniqueness and spillover.

Test 28 Sep DTG A/B exact 14:30 split and total conservation; cross-midnight C; Friday 06:00/12:00/18:00/23:00 boundaries; Employee-only headcount; Window productive; no omitted adjacent contribution; 21 Sep partial prior coverage; 05 Oct incomplete coverage; ambiguity/stale precedence over observed numbers. Hypothetical competing READY generations must never be unioned.

Run focused read-model tests, shared/web/connector suites, lint, typecheck, build and git diff --check in isolated suitable worktrees. Prove no active runtime consumer imports V3. Preserve preexisting uncommitted work and restore only generated artifacts attributable to these checks.

Static SQL tests and TypeScript fixtures do not certify SQL execution, locking or concurrency. If no verified disposable database executes the SQL suite, report NOT EXECUTION-CERTIFIED separately and keep Production activation blocked. Never use Production, Preview or forbidden Docker as the execution test target.

## Future reporting foundation

UP productivity pairs physical UP output and Window UP productive hours for identical date/Window. Headcount remains Employee-oriented and must be labeled separately. Hourly DTG/UP uses physical timestamps and hour/Window overlap, preserving existing validated print/output semantics. Toolbox staffing uses Employee Shift; toolbox performance uses Production Window. Do not label both dimensions generically as Shift.

## Review boundary

The architecture above incorporates the approved compare-and-swap, deterministic views, separate bounded recertification and blocking precedence. Review this written specification before generating the task-by-task implementation plan and local SQL. Phase 3A does not authorize any Production activation.
