CREATE OR REPLACE FUNCTION public.protect_active_operation_deactivation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if old.active and not new.active and exists(select 1 from routing_operations ro join routings r on r.id=ro.routing_id and r.organization_id=ro.organization_id where ro.operation_id=old.id and ro.organization_id=old.organization_id and r.status='ACTIVE')then raise exception 'Operation is used by an active routing revision';end if;return new;
end$function$
;

