CREATE OR REPLACE FUNCTION public.copy_production_order_operations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.source_routing_id is null or exists(select 1 from production_order_operations where production_order_id=new.id)then return new;end if;
  insert into production_order_operations(organization_id,production_order_id,source_routing_operation_id,source_operation_id,sequence,operation_code_snapshot,operation_name_snapshot,work_center_code_snapshot,work_center_name_snapshot,required,setup_minutes_snapshot,run_rate_snapshot,queue_minutes_snapshot,instructions_snapshot,planned_quantity,planned_date,planned_shift_id)
  select new.organization_id,new.id,ro.id,o.id,ro.sequence,o.code,o.name,w.code,w.name,ro.required,ro.setup_minutes,ro.run_rate,ro.queue_minutes,ro.instructions,new.planned_quantity,new.planned_date,new.planned_shift_id
  from routing_operations ro join operations o on o.id=ro.operation_id and o.organization_id=ro.organization_id left join work_centers w on w.id=ro.work_center_id and w.organization_id=ro.organization_id
  where ro.routing_id=new.source_routing_id and ro.organization_id=new.organization_id order by ro.sequence;
  return new;
end$function$
;

