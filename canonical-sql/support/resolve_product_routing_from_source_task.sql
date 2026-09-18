CREATE OR REPLACE FUNCTION public.resolve_product_routing_from_source_task(p_organization_id uuid, p_product_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select resolve_product_process_routing(p_organization_id,p_product_id,r.process_code,p_order_line_override)from resolve_source_task_context(p_organization_id,p_source_dataset,p_source_task,p_queue,p_from_zone,p_to_zone,p_from_location,p_to_location)r where r.process_code is not null limit 1$function$
;

