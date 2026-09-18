CREATE OR REPLACE FUNCTION public.protect_routing_operation_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare route_status text;operation_active boolean;begin
  select status into route_status from routings where id=coalesce(new.routing_id,old.routing_id)and organization_id=coalesce(new.organization_id,old.organization_id);
  if route_status is distinct from 'DRAFT'then raise exception 'Routing operations may only change on draft revisions';end if;
  if tg_op<>'DELETE'then select active into operation_active from operations where id=new.operation_id and organization_id=new.organization_id;if operation_active is distinct from true then raise exception 'Only active canonical operations may be added';end if;end if;
  return case when tg_op='DELETE'then old else new end;
end$function$
;

