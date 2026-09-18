create or replace view public."v_production_order_routing_status" as
 SELECT po.organization_id,
    po.id AS production_order_id,
    po.order_no,
    po.source_order_no,
    po.production_status,
    count(poo.id) AS operation_count,
    count(poo.id) FILTER (WHERE (poo.status = 'COMPLETED'::text)) AS completed_operation_count,
    count(e.id) AS evidence_count,
    count(ex.id) FILTER (WHERE (ex.status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text]))) AS open_exception_count,
    max(e.observed_at) AS last_source_observed_at
   FROM (((production_orders po
     LEFT JOIN production_order_operations poo ON ((poo.production_order_id = po.id)))
     LEFT JOIN production_order_operation_evidence e ON ((e.production_order_id = po.id)))
     LEFT JOIN production_routing_exceptions ex ON ((ex.production_order_id = po.id)))
  GROUP BY po.organization_id, po.id, po.order_no, po.source_order_no, po.production_status;;

