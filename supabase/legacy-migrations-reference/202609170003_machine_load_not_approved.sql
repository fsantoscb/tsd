create or replace view v_machine_load_not_approved with (security_invoker=true) as
with order_process as (
  select l.organization_id,l.sync_batch_id,l.order_no,
    bool_or(upper(trim(l.group_code)) in ('DTG_1','DTG_2')) has_dtg,
    bool_or(upper(trim(l.group_code))='UNDERPRINT') has_underprint,
    bool_or(upper(trim(l.group_code)) not in ('DTG_1','DTG_2','UNDERPRINT')) has_other
  from v_current_release_order_lines l
  join v_release_queue q on q.organization_id=l.organization_id and q.sync_batch_id=l.sync_batch_id and q.order_no=l.order_no and q.release_status='NOT_APPROVED'
  where l.qty_lcd>0 group by l.organization_id,l.sync_batch_id,l.order_no
)
select l.organization_id,l.sync_batch_id,l.order_no,l.line_number,l.product,l.client,l.product_name,l.group_code source_process_code,l.qty_lcd process_quantity,
  'PROCESS_QUANTITY'::text quantity_semantics,q.customer_name,q.date_due,q.source_priority,q.site,q.route_id release_route_evidence,
  null::uuid routing_id,null::text routing_code,null::integer routing_revision,null::text machine_group,
  case when upper(trim(l.group_code)) in('DTG_1','DTG_2')then'DTG' when upper(trim(l.group_code))='UNDERPRINT'then'UNDERPRINT' when upper(trim(l.group_code))='UV PRINT'then'UV' when upper(trim(l.group_code))='HATS'then'HATS' when upper(trim(l.group_code))='FINISHED'then'FINISHED' when upper(trim(l.group_code))='STICKERS'then'STICKERS' when upper(trim(l.group_code))='VISUAL'then'VISUAL' when upper(trim(l.group_code))='PROD'then'PRODUCTION' when upper(trim(l.group_code))='CUSTOM EMB'then'CUSTOM EMB' when upper(trim(l.group_code))='EYEWEAR'then'EYEWEAR' else'UNRESOLVED'end process,
  case when upper(trim(l.group_code)) in('DTG_1','DTG_2')then'DTG' when upper(trim(l.group_code))='UNDERPRINT'then'UNDERPRINT' else null end machine_load_bucket,
  case when(op.has_dtg::integer+op.has_underprint::integer)=1 and not op.has_other then'RESOLVED' when(op.has_dtg or op.has_underprint)and(op.has_other or(op.has_dtg and op.has_underprint))then'AMBIGUOUS' else'UNRESOLVED'end routing_resolution,
  'NOT_APPROVED'::text release_status,q.release_blockers,q.snapshot_completed_at
from v_current_release_order_lines l
join v_release_queue q on q.organization_id=l.organization_id and q.sync_batch_id=l.sync_batch_id and q.order_no=l.order_no and q.release_status='NOT_APPROVED'
join order_process op on op.organization_id=l.organization_id and op.sync_batch_id=l.sync_batch_id and op.order_no=l.order_no
where l.qty_lcd>0;
revoke all on v_machine_load_not_approved from anon,authenticated;
grant select on v_machine_load_not_approved to service_role;
