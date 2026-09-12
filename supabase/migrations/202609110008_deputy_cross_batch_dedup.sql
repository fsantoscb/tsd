create or replace view v_current_labour_segments with(security_invoker=true)as
with ranked as(
 select r.id,row_number()over(partition by r.organization_id,coalesce(nullif(r.source_timesheet_id,''),r.source_row_key)order by b.imported_at desc,r.created_at desc)rn
 from deputy_raw_timesheets r join deputy_import_batches b on b.id=r.import_batch_id
 where b.status='COMPLETED'and r.row_status='ACCEPTED'
)
select s.*from labour_segments s join ranked r on r.id=s.source_timesheet_row_id and r.rn=1;
revoke all on v_current_labour_segments from anon,authenticated;grant select on v_current_labour_segments to service_role;
