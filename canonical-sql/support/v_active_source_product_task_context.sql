create or replace view public."v_active_source_product_task_context" as
 SELECT l.organization_id,
    l.source_order_no,
    l.process_code,
    l.source_line_id,
    l.source_sku,
    l.source_description,
    l.quantity,
    l.active_units,
    l.source_gap,
    t.source_task,
    t.queue,
    t.from_zone,
    t.process_code AS task_process_code,
    t.operation_code AS task_operation_code,
    t.resolution_status AS task_resolution_status,
    resolve_product_process_routing(l.organization_id, pm.product_id, t.process_code, NULL::uuid) AS resolved_routing_id
   FROM ((v_active_source_product_lines l
     LEFT JOIN LATERAL ( SELECT r.organization_id,
            r.source_dataset,
            r.source_record_key,
            r.order_no,
            r.source_task,
            r.queue,
            r.from_zone,
            r.to_zone,
            r.from_location,
            r.to_location,
            r.production_units,
            r.observed_at,
            r.mapping_id,
            r.production_process_id,
            r.process_code,
            r.operation_id,
            r.operation_code,
            r.resolution_status
           FROM v_source_task_resolution r
          WHERE ((r.organization_id = l.organization_id) AND (r.order_no = l.source_order_no) AND (r.source_dataset = 'WORKBANK'::text))
          ORDER BY r.observed_at DESC, r.source_record_key
         LIMIT 1) t ON (true))
     LEFT JOIN product_source_mappings pm ON (((pm.organization_id = l.organization_id) AND (pm.source_system = 'ORACLE_WMS'::text) AND (pm.source_product_code = l.source_sku) AND pm.active)));;

