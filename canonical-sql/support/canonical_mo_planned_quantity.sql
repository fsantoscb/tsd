CREATE OR REPLACE FUNCTION public.canonical_mo_planned_quantity(p_mo uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce(sum(ml.planned_quantity)filter(where d.status in('READY','GROUPED')),0)::numeric(14,3)from manufacturing_order_lines ml join production_demand_lines d on d.id=ml.production_demand_line_id where ml.manufacturing_order_id=p_mo$function$
;

