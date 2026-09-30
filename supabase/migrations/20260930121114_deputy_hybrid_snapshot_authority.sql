-- Select Deputy authority by source timesheet date before joining existing
-- segments. A tied latest FULL report timestamp fails closed for that date;
-- it must be diagnosed, never resolved by import time or UUID.
create or replace view public.v_current_labour_segments as
with source_dates as (
  select distinct r.organization_id, r.timesheet_date
  from public.deputy_raw_timesheets r
  join public.deputy_import_batches b on b.id = r.import_batch_id
  where b.status = 'COMPLETED'
    and r.row_status = 'ACCEPTED'
),
latest_generation as (
  select d.organization_id, d.timesheet_date,
         max(b.report_generated_at) as report_generated_at
  from source_dates d
  join public.deputy_import_batches b
    on b.organization_id = d.organization_id
   and b.status = 'COMPLETED'
   and b.snapshot_type = 'FULL'
   and b.report_generated_at is not null
   and b.coverage_start is not null
   and b.coverage_end is not null
   and b.certified_at is not null
   and b.certified_by is not null
   and b.coverage_start <= d.timesheet_date
   and b.coverage_end >= d.timesheet_date
  group by d.organization_id, d.timesheet_date
),
latest_batches as (
  select g.organization_id, g.timesheet_date, b.id as import_batch_id,
         count(*) over (
           partition by g.organization_id, g.timesheet_date
         ) as latest_batch_count
  from latest_generation g
  join public.deputy_import_batches b
    on b.organization_id = g.organization_id
   and b.status = 'COMPLETED'
   and b.snapshot_type = 'FULL'
   and b.report_generated_at = g.report_generated_at
   and b.coverage_start <= g.timesheet_date
   and b.coverage_end >= g.timesheet_date
   and b.certified_at is not null
   and b.certified_by is not null
),
certified_authority as (
  select organization_id, timesheet_date, import_batch_id
  from latest_batches
  where latest_batch_count = 1
),
raw_candidates as (
  -- No eligible FULL report covers this source date: preserve the existing
  -- completed-batch exact-content behaviour, including legacy imports.
  select r.*
  from public.deputy_raw_timesheets r
  join public.deputy_import_batches b on b.id = r.import_batch_id
  left join latest_generation g
    on g.organization_id = r.organization_id
   and g.timesheet_date = r.timesheet_date
  where b.status = 'COMPLETED'
    and r.row_status = 'ACCEPTED'
    and g.organization_id is null

  union all

  -- A single latest FULL report owns the entire source date. An ambiguous
  -- latest timestamp produces no candidates and never falls back to legacy.
  select r.*
  from public.deputy_raw_timesheets r
  join certified_authority a
    on a.organization_id = r.organization_id
   and a.timesheet_date = r.timesheet_date
   and a.import_batch_id = r.import_batch_id
  where r.row_status = 'ACCEPTED'
),
canonical_raw as (
  select r.id,
         row_number() over (
           partition by
             r.organization_id,
             r.source_timesheet_id,
             case
               when nullif(btrim(r.employee_id), '') is not null
                 then 'ID:' || btrim(r.employee_id)
               when nullif(btrim(r.person_key), '') is not null
                 then 'PERSON:' || btrim(r.person_key)
               else 'UNKNOWN:' || r.id::text
             end,
             btrim(r.display_name),
             r.timesheet_date,
             upper(btrim(r.raw_area)),
             upper(btrim(r.normalized_area)),
             r.start_at,
             r.end_at,
             r.total_hours,
             r.meal_break_hours,
             r.approval_status,
             r.row_status
           order by r.id asc
         ) as rn
  from raw_candidates r
)
select s.id,
       s.organization_id,
       s.import_batch_id,
       s.source_timesheet_row_id,
       s.person_key,
       s.area_code,
       s.segment_start,
       s.segment_end,
       s.calendar_date,
       s.operational_date,
       s.hour_bucket,
       s.shift_code,
       s.paid_hours,
       s.regular_hours,
       s.overtime_hours,
       s.paid_break_hours,
       s.productive_hours,
       s.approval_status,
       s.allocation_method,
       s.week_start,
       s.calculation_version,
       s.created_at
from public.labour_segments s
join canonical_raw r on r.id = s.source_timesheet_row_id and r.rn = 1;
