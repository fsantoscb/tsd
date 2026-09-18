create or replace view public."v_production_order_progress" as
 SELECT c.organization_id,
    c.production_order_id,
    c.order_no,
    c.source_order_no,
    c.routing_code_snapshot,
    c.production_status,
    c.planned_quantity,
    c.actual_quantity,
    c.current_operation_id,
    c.current_operation_sequence,
    c.current_operation_code,
    c.current_operation_name,
    c.next_operation_id,
    c.next_operation_code,
    c.next_operation_name,
    c.last_completed_operation_id,
    c.last_completed_operation_code,
    c.last_completed_operation_name,
    GREATEST((COALESCE(c.planned_quantity, (0)::numeric) - COALESCE(c.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    s.operation_count,
    s.completed_operation_count,
    s.evidence_count,
    s.open_exception_count,
    s.last_source_observed_at
   FROM (v_production_order_current_operation c
     JOIN v_production_order_routing_status s USING (organization_id, production_order_id));;

