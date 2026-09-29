-- Add batch-level source-authority evidence without changing current Labour selection.
-- Existing imports remain unverified; no rows are backfilled or certified here.
alter table public.deputy_import_batches
  add column report_generated_at timestamptz,
  add column coverage_start date,
  add column coverage_end date,
  add column snapshot_type text,
  add column certified_at timestamptz,
  add column certified_by text,
  add column certification_note text;

alter table public.deputy_import_batches
  add constraint deputy_snapshot_type_check
    check (snapshot_type is null or snapshot_type in ('FULL', 'PARTIAL')),
  add constraint deputy_snapshot_coverage_order_check
    check (coverage_start is null or coverage_end is null or coverage_start <= coverage_end),
  add constraint deputy_full_snapshot_certification_check
    check (
      snapshot_type is distinct from 'FULL'
      or (
        report_generated_at is not null
        and coverage_start is not null
        and coverage_end is not null
        and certified_at is not null
        and nullif(btrim(certified_by), '') is not null
      )
    );
