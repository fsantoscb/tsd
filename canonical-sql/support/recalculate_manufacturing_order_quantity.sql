CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_quantity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare mo uuid:=coalesce(new.manufacturing_order_id,old.manufacturing_order_id);q numeric;begin q:=canonical_mo_planned_quantity(mo);update production_orders set planned_quantity=q,updated_at=now()where id=mo;update production_order_operations set planned_quantity=q,updated_at=now()where q>0 and production_order_id=mo and status in('PENDING','READY');return coalesce(new,old);end$function$
;

