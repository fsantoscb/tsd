CREATE OR REPLACE FUNCTION public.protect_production_operation_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE'then raise exception 'Production operation snapshots cannot be deleted';end if;
  if(new.organization_id,new.production_order_id,new.source_routing_operation_id,new.source_operation_id,new.sequence,new.operation_code_snapshot,new.operation_name_snapshot,new.work_center_code_snapshot,new.work_center_name_snapshot,new.required,new.setup_minutes_snapshot,new.run_rate_snapshot,new.queue_minutes_snapshot,new.instructions_snapshot)is distinct from(old.organization_id,old.production_order_id,old.source_routing_operation_id,old.source_operation_id,old.sequence,old.operation_code_snapshot,old.operation_name_snapshot,old.work_center_code_snapshot,old.work_center_name_snapshot,old.required,old.setup_minutes_snapshot,old.run_rate_snapshot,old.queue_minutes_snapshot,old.instructions_snapshot)then raise exception 'Production operation definition snapshot is immutable';end if;
  if new.status<>old.status and not((old.status='PENDING'and new.status in('READY','IN_PROGRESS','SKIPPED'))or(old.status='READY'and new.status in('IN_PROGRESS','SKIPPED'))or(old.status='IN_PROGRESS'and new.status in('ON_HOLD','COMPLETED'))or(old.status='ON_HOLD'and new.status in('IN_PROGRESS','SKIPPED')))then raise exception 'Invalid production operation status transition';end if;
  if new.status='IN_PROGRESS'and old.status<>'IN_PROGRESS'then new.started_at:=coalesce(new.started_at,now());end if;
  if new.status in('COMPLETED','SKIPPED')and old.status not in('COMPLETED','SKIPPED')then new.completed_at:=coalesce(new.completed_at,now());end if;
  new.updated_at:=now();return new;
end$function$
;

