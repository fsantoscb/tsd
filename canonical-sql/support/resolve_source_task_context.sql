CREATE OR REPLACE FUNCTION public.resolve_source_task_context(p_organization_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text)
 RETURNS TABLE(mapping_id uuid, production_process_id uuid, process_code text, operation_id uuid, operation_code text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select m.id,m.production_process_id,p.code,m.operation_id,o.code from source_task_mappings m join production_processes p on p.id=m.production_process_id and p.organization_id=m.organization_id left join operations o on o.id=m.operation_id and o.organization_id=m.organization_id where m.organization_id=p_organization_id and m.source_system='ORACLE_WMS'and m.source_dataset=upper(p_source_dataset)and m.active and source_value_matches(p_source_task,m.match_type,m.source_task)and(m.context_field is null or source_value_matches(case m.context_field when'queue'then p_queue when'from_zone'then p_from_zone when'to_zone'then p_to_zone when'from_location'then p_from_location when'to_location'then p_to_location end,m.context_match_type,m.context_value))order by(case when m.context_field is not null then 0 else 1 end),m.priority,m.id limit 1$function$
;

