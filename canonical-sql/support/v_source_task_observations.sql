create or replace view public."v_source_task_observations" as
 SELECT w.organization_id,
    'WORKBANK'::text AS source_dataset,
    w.source_row_id AS source_record_key,
    w.order_no,
    w.task AS source_task,
    w.queue,
    w.from_zone,
    NULL::text AS to_zone,
    w.from_location,
    w.to_location,
    w.production_units,
    w.created_at AS observed_at
   FROM v_current_workbank w
  WHERE (NULLIF(TRIM(BOTH FROM w.task), ''::text) IS NOT NULL)
UNION ALL
 SELECT a.organization_id,
    'AUDIT'::text AS source_dataset,
    COALESCE(a.source_audit_id, (a.id)::text) AS source_record_key,
    a.order_no,
    a.task AS source_task,
    a.queue,
    a.from_zone,
    a.to_zone,
    a.from_location,
    a.to_location,
    a.production_units,
    a.event_at AS observed_at
   FROM source_audit_events a
  WHERE (NULLIF(TRIM(BOTH FROM a.task), ''::text) IS NOT NULL);;

