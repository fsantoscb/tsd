create or replace view public."v_manufacturing_order_routing_status" as
 SELECT p.organization_id,
    p.manufacturing_order_id,
    p.mo_number,
    p.source_order_no,
    p.routing_code_snapshot,
    p.routing_revision_snapshot,
    p.production_status,
    p.planned_quantity,
    p.actual_quantity,
    p.remaining_quantity,
    p.planned_date,
    p.planner_priority,
    p.current_operation_id,
    p.current_operation_code,
    p.current_operation_name,
    p.next_operation_id,
    p.next_operation_code,
    p.next_operation_name,
    p.last_completed_operation_id,
    p.last_completed_operation_code,
    p.operation_count,
    p.completed_operation_count,
    p.routing_progress_percent,
    COALESCE(s.open_exception_count, (0)::bigint) AS open_exception_count,
    s.last_source_observed_at,
        CASE
            WHEN (COALESCE(s.open_exception_count, (0)::bigint) > 0) THEN 'DEVIATION'::text
            WHEN (s.evidence_count > 0) THEN 'VALIDATED'::text
            ELSE 'AWAITING_EVIDENCE'::text
        END AS validation_status
   FROM (v_manufacturing_order_progress p
     LEFT JOIN v_production_order_routing_status s ON ((s.production_order_id = p.manufacturing_order_id)));;

