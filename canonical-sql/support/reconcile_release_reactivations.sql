CREATE OR REPLACE FUNCTION public.reconcile_release_reactivations(p_organization_id uuid, p_snapshot_run_id uuid DEFAULT NULL::uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_snapshot uuid;v_at timestamptz;r record;detected integer:=0;restored integer:=0;qty numeric:=0;events integer:=0;exceptions integer:=0;mos integer:=0;
begin
 select id,completed_at into v_snapshot,v_at from oracle_line_ingestion_runs
 where id=coalesce(p_snapshot_run_id,(select id from oracle_line_ingestion_runs x where x.organization_id=p_organization_id and x.status='COMPLETED' and x.snapshot_status='COMPLETE' order by x.completed_at desc,x.id desc limit 1))
  and organization_id=p_organization_id and status='COMPLETED' and snapshot_status='COMPLETE';
 if v_snapshot is null then raise exception 'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;
 create temp table if not exists e68_mos(id uuid primary key)on commit drop;truncate e68_mos;
 for r in select * from v_release_reactivation_candidates where organization_id=p_organization_id and reactivation_snapshot_run_id=v_snapshot loop
  detected:=detected+1;
  if r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then
   if p_apply then
    update production_demand_lines set status='GROUPED',updated_at=now() where id=r.production_demand_line_id and status='CANCELLED';
    if found then restored:=restored+1;qty:=qty+r.mapped_quantity;insert into e68_mos values(r.manufacturing_order_id)on conflict do nothing;end if;
   end if;
  else exceptions:=exceptions+1;end if;
  if p_apply then
   insert into production_demand_release_events(id,organization_id,production_demand_line_id,manufacturing_order_line_id,manufacturing_order_id,event_type,action,original_mapping_at,original_snapshot_run_id,original_released,original_raw_release_value,event_snapshot_run_id,event_at,previous_release_value,current_release_value,mapped_quantity,executed_quantity,mo_status,created_at)
   values(gen_random_uuid(),r.organization_id,r.production_demand_line_id,r.manufacturing_order_line_id,r.manufacturing_order_id,
    case when r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then 'RELEASE_REACTIVATED' else 'RE_RELEASED_REQUIRES_RECONCILIATION' end,
    r.recommended_action,r.original_mapping_at,r.original_snapshot_run_id,true,'Y',v_snapshot,v_at,'N','Y',r.mapped_quantity,coalesce(r.executed_quantity,0),r.mo_status,now())
   on conflict(production_demand_line_id,event_type,event_snapshot_run_id)do nothing;
   if found then events:=events+1;end if;
  end if;
 end loop;
 if p_apply then
  update production_orders po set planned_quantity=canonical_mo_planned_quantity(po.id),updated_at=now()
   from e68_mos m where po.id=m.id;
  update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()
   from production_orders po join e68_mos m on m.id=po.id
   where op.production_order_id=po.id and op.status in('PENDING','READY');
  select count(*)into mos from e68_mos;
 end if;
 return jsonb_build_object('snapshotRunId',v_snapshot,'apply',p_apply,'linesDetected',detected,'linesReactivated',restored,'quantityRestored',qty,'mosRecalculated',mos,'controlledExceptions',exceptions,'eventsCreated',events);
end$function$
;

