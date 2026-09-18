create or replace view public."v_released_demand_resolution" as
 WITH process_context AS (
         SELECT v_source_task_resolution.organization_id,
            v_source_task_resolution.order_no,
            count(DISTINCT v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_count,
            min(v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_code,
            string_agg(DISTINCT v_source_task_resolution.source_task, ', '::text ORDER BY v_source_task_resolution.source_task) AS source_tasks
           FROM v_source_task_resolution
          WHERE (v_source_task_resolution.source_dataset = 'WORKBANK'::text)
          GROUP BY v_source_task_resolution.organization_id, v_source_task_resolution.order_no
        ), product_context AS (
         SELECT product_source_mappings.organization_id,
            product_source_mappings.source_product_code,
            count(DISTINCT product_source_mappings.product_id) AS product_count,
            (min((product_source_mappings.product_id)::text))::uuid AS product_id
           FROM product_source_mappings
          WHERE ((product_source_mappings.source_system = 'ORACLE_WMS'::text) AND product_source_mappings.active)
          GROUP BY product_source_mappings.organization_id, product_source_mappings.source_product_code
        )
 SELECT l.organization_id,
    l.source_order_no,
    l.source_line_id,
    l.production_units AS source_quantity,
    l.released,
    l.raw_release_value,
    o.source_route_id,
    pc.product_id,
    pctx.process_code AS resolved_process,
        CASE
            WHEN (pctx.process_count = 1) THEN 'UNIQUE_WORKBANK_TASK_PROCESS'::text
            ELSE NULL::text
        END AS process_resolution_rule,
        CASE
            WHEN (pctx.process_count = 1) THEN 'SOURCE_CONFIRMED'::text
            ELSE 'NOT_RESOLVED'::text
        END AS process_provenance,
        CASE
            WHEN ((pc.product_count = 1) AND (pctx.process_count = 1)) THEN resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid)
            ELSE NULL::uuid
        END AS resolved_routing_id,
    e.release_eligibility,
    l.sync_batch_id,
    a.ingestion_run_id,
        CASE
            WHEN ((l.released IS DISTINCT FROM true) OR (l.raw_release_value <> 'Y'::text)) THEN 'RELEASE_NOT_CONFIRMED'::text
            WHEN (e.release_eligibility <> 'READY'::text) THEN 'ELIGIBILITY_BLOCKED'::text
            WHEN (COALESCE(pc.product_count, (0)::bigint) <> 1) THEN 'PRODUCT_UNRESOLVED'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) <> 1) THEN 'PROCESS_UNRESOLVED'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'ROUTING_UNRESOLVED'::text
            ELSE 'ELIGIBLE'::text
        END AS eligibility_status,
        CASE
            WHEN (COALESCE(pc.product_count, (0)::bigint) = 0) THEN 'No active canonical Product mapping'::text
            WHEN (pc.product_count > 1) THEN 'Multiple active canonical Product mappings'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) = 0) THEN 'No mapped source Task process observed'::text
            WHEN (pctx.process_count > 1) THEN 'Multiple source Task processes observed for Sales Order'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'No approved Product + Process Routing'::text
            ELSE NULL::text
        END AS blocker,
    pctx.source_tasks
   FROM (((((v_released_production_demand l
     JOIN v_authoritative_release_lines a ON (((a.organization_id = l.organization_id) AND (a.source_order_no = l.source_order_no) AND (a.source_line_id = l.source_line_id))))
     JOIN v_sales_order_release_eligibility e ON (((e.organization_id = l.organization_id) AND (e.source_order_no = l.source_order_no))))
     LEFT JOIN v_current_orders o ON (((o.organization_id = l.organization_id) AND (o.order_no = l.source_order_no))))
     LEFT JOIN product_context pc ON (((pc.organization_id = l.organization_id) AND (pc.source_product_code = l.source_product_code))))
     LEFT JOIN process_context pctx ON (((pctx.organization_id = l.organization_id) AND (pctx.order_no = l.source_order_no))));;

