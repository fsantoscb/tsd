CREATE OR REPLACE FUNCTION public.validate_product_default_routing()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if new.default_routing_id is not null and not exists(select 1 from routings r where r.id=new.default_routing_id and r.organization_id=new.organization_id and r.status='ACTIVE'and r.active and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date))then raise exception 'Product default routing must be active, effective and in the same organization';end if;return new;
end$function$
;

