create or replace view public."v_manufacturing_order_current_operation" as
 SELECT e.organization_id,
    e.production_order_id AS manufacturing_order_id,
    po.mo_number,
    COALESCE(e.source_order_no, e.order_no) AS source_order_no,
    po.routing_code_snapshot,
    po.routing_revision_snapshot,
    e.production_status,
    e.planned_quantity,
    e.actual_quantity,
    GREATEST((COALESCE(e.planned_quantity, (0)::numeric) - COALESCE(e.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    e.planned_date,
    e.planner_priority,
    e.current_operation_id,
    e.current_operation_code,
    e.current_operation_name,
    e.next_operation_id,
    e.next_operation_code,
    e.next_operation_name,
    e.last_completed_operation_id,
    e.last_completed_operation_code
   FROM (v_production_order_execution e
     JOIN production_orders po ON ((po.id = e.production_order_id)))
  WHERE (po.source_routing_id IS NOT NULL);;

