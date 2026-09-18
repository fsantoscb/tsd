create or replace view public."v_source_task_resolution" as
 SELECT s.organization_id,
    s.source_dataset,
    s.source_record_key,
    s.order_no,
    s.source_task,
    s.queue,
    s.from_zone,
    s.to_zone,
    s.from_location,
    s.to_location,
    s.production_units,
    s.observed_at,
    r.mapping_id,
    r.production_process_id,
    r.process_code,
    r.operation_id,
    r.operation_code,
        CASE
            WHEN (r.mapping_id IS NULL) THEN 'TASK_UNMAPPED'::text
            WHEN (r.operation_id IS NULL) THEN 'PROCESS_ONLY'::text
            ELSE 'PROCESS_AND_OPERATION'::text
        END AS resolution_status
   FROM (v_source_task_observations s
     LEFT JOIN LATERAL resolve_source_task_context(s.organization_id, s.source_dataset, s.source_task, s.queue, s.from_zone, s.to_zone, s.from_location, s.to_location) r(mapping_id, production_process_id, process_code, operation_id, operation_code) ON (true));;

