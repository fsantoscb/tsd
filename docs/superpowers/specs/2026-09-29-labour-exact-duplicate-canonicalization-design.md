# Labour exact-duplicate canonicalization — local design

Status: proposed written design for review. No migration has been implemented or applied.

## Baseline and scope

- Canonical schema lineage: `8450c3472e2a1481e732809e628ee9324183711b`.
- Add one new versioned migration; never edit an applied migration.
- Affect only the canonical selection consumed by `public.v_current_labour_segments` and downstream Labour/KPI readers. Preserve that view's existing output columns and meaning except removal of exact duplicate copies.
- Preserve `public.deputy_raw_timesheets`, `public.deputy_import_batches`, and existing `public.labour_segments` rows. Do not delete or rewrite historical records.
- Local work only. No Production write, deploy, Preview, scheduler change, or connector change.
- No shift-boundary, break, Capacity, KPI-formula, UI, or Performance-layout changes.

## Existing behavior and problem

`v_current_labour_segments` currently ranks completed, accepted raw timesheets by `(organization_id, COALESCE(NULLIF(source_timesheet_id, ''), source_row_key))`, preferring later imports. In the observed Deputy data, `source_timesheet_id` is null and `source_row_key` changes with source filename/row. Thus content-identical imports remain separate and multiply Labour hours. This ranking is not an authority rule for revised timesheets.

The read-only diagnostic of 1,350 raw rows found 355 content-identical groups containing 1,330 rows: 147 groups of 2, 106 of 4, and 102 of 6. Selecting one representative per group would remove 975 *copies from the canonical selection*, not from raw storage. All compared business fields and six available source `raw_data` fields matched within these groups. These are observed figures, not migration postconditions or live-data constants.

## Canonical identity and winner

Within one organization, group only accepted timesheets from completed batches whose normalized business content is exactly equal:

- employee: stable employee identifier when available, otherwise normalized `person_key`/source employee name;
- `timesheet_date`;
- normalized area (retain a distinction if source-area values are materially different);
- `start_at` and `end_at`;
- `total_hours` as reported by Deputy;
- `meal_break_hours` as reported by Deputy;
- `approval_status`;
- `row_status`.

Normalization may remove representational whitespace/case differences in text fields, but must not round hours or timestamps, infer a new shift, or reinterpret a source value. A non-null stable `source_timesheet_id` conflict is a safety signal: distinct IDs must not be silently collapsed solely because all other content matches. Confirm exact key expression against source/import parser before writing SQL. Filename, source row number, batch identity, import time, and `source_row_key` are never part of the duplicate identity.

Within a 100%-identical group, select one `deputy_raw_timesheets.id` with a stable technical ordering (for example, UUID `id` ascending). This tie-break is solely to avoid nondeterminism; it does not privilege the newest batch or decide which *different* revision is authoritative. Every nonidentical row remains in the canonical candidate set. In particular, Stewart on 28 September, 05:30–14:00 versus 05:30–14:32, remains two distinct, ambiguous records. No automated revision winner is selected.

An additive canonical-selection view, or an equivalent small CTE within a replacement `v_current_labour_segments`, will yield selected raw IDs. `v_current_labour_segments` will join existing `labour_segments.source_timesheet_row_id` to those IDs. Keep all existing view output columns, access control, accepted/completed status filters, and downstream contracts unchanged. Avoid recreating any Labour or KPI calculation.

## Break invariant

The existing fixed `1/3` hour deduction from productive time is the company's paid, nonproductive 20-minute break. Preserve it. Deputy's 30-minute unpaid meal is already reflected in reported hours; never subtract it a second time. Monday–Thursday day/evening shifts may have both breaks; Friday and graveyard/Shift C have only the paid 20-minute break. This migration does not change segmentation or break code, regardless of whether `meal_break_hours` participates in exact identity.

## Validation and acceptance

Create focused database tests for identical groups of 2, 4, and 6; varying filename, row number, and batch; differing content; Stewart's two revisions; distinct legitimate timesheets; raw/batch/segment preservation; and canonical view consumption by Labour/KPI. Retain existing tests that assert the 20-minute productive-time deduction and absence of a second Deputy-meal deduction. Test that key nulls and differing stable source IDs cannot produce unsafe merges.

Run the migration against an isolated disposable database if a safe SQL execution path is available, then inspect view shape, counts, selected IDs, downstream sums, and migration idempotence/rollback behavior. If SQL cannot be run safely, label SQL behavior `NOT EXECUTION-CERTIFIED`; static review and unit tests must not be called execution certification.

Recalculate locally for 23, 24, 25, and 28 September 2026, with identical source watermark and shift semantics: productive hours, overtime hours, and prints/hour. Expected diagnostic productive-hour values (not hardcoded test values) are 152.72 → about 38.18 on the 23rd, 143.32 → about 35.83 on the 24th, and 45.31 → about 17.00 on the 25th. Do not certify one corrected 28 September value while Stewart's revision is unresolved. Prints, garments, Capacity, and Utilisation must remain unchanged. Existing accepted segments with no corresponding canonical raw row must be investigated rather than hidden.

No Production application or database activation is authorized by this design. A later, explicit approval and deployment gate are required after local SQL execution and diagnostic reconciliation.

## Implementation gate

The next step is a separate implementation plan with exact migration filename, SQL shape, tests, and commands. No migration code should be written until this design is reviewed and approved. If the current schema, parser, or source content contradicts any identity assumption above, stop for review rather than broadening deduplication.
