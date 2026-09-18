CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_actual()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin update production_orders set actual_quantity=(select coalesce(sum(actual_quantity),0)from manufacturing_order_lines where manufacturing_order_id=new.manufacturing_order_id),updated_at=now()where id=new.manufacturing_order_id;return new;end$function$
;

