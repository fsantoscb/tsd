-- READ ONLY. Run immediately before a separately approved Production activation.
-- Any returned row BLOCKS activation: the deterministic canonical raw row has
-- no Labour segments while an identical sibling has at least one.
with ranked as (
  select r.id,
         first_value(r.id) over (
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
         ) as representative_id
  from public.deputy_raw_timesheets r
  join public.deputy_import_batches b on b.id = r.import_batch_id
  where b.status = 'COMPLETED'
    and r.row_status = 'ACCEPTED'
), segment_presence as (
  select ranked.id, ranked.representative_id,
         exists (
           select 1 from public.labour_segments s
           where s.source_timesheet_row_id = ranked.id
         ) as has_segments
  from ranked
)
select representative_id,
       count(*) filter (where id <> representative_id and has_segments) as siblings_with_segments
from segment_presence
group by representative_id
having not bool_or(id = representative_id and has_segments)
   and bool_or(id <> representative_id and has_segments)
order by representative_id;
