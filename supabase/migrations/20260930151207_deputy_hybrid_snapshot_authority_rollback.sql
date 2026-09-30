-- Restore the pre-hybrid exact-content canonical Labour selection.
-- This is the exact view definition from 20260929173001; no source rows change.
create or replace view public.v_current_labour_segments as
with canonical_raw as (
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
  from public.deputy_raw_timesheets r
  join public.deputy_import_batches b on b.id = r.import_batch_id
  where b.status = 'COMPLETED'
    and r.row_status = 'ACCEPTED'
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
