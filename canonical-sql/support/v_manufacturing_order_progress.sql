create or replace view public."v_manufacturing_order_progress" as
 SELECT m.organization_id,
    m.manufacturing_order_id,
    m.mo_number,
    m.source_order_no,
    m.routing_code_snapshot,
    m.routing_revision_snapshot,
    m.production_status,
    m.planned_quantity,
    m.actual_quantity,
    m.remaining_quantity,
    m.planned_date,
    m.planner_priority,
    m.current_operation_id,
    m.current_operation_code,
    m.current_operation_name,
    m.next_operation_id,
    m.next_operation_code,
    m.next_operation_name,
    m.last_completed_operation_id,
    m.last_completed_operation_code,
    count(op.id) AS operation_count,
    count(op.id) FILTER (WHERE (op.status = 'COMPLETED'::text)) AS completed_operation_count,
    round((((count(op.id) FILTER (WHERE (op.status = 'COMPLETED'::text)))::numeric / (NULLIF(count(op.id), 0))::numeric) * (100)::numeric), 1) AS routing_progress_percent
   FROM (v_manufacturing_order_current_operation m
     LEFT JOIN production_order_operations op ON ((op.production_order_id = m.manufacturing_order_id)))
  GROUP BY m.organization_id, m.manufacturing_order_id, m.mo_number, m.source_order_no, m.routing_code_snapshot, m.routing_revision_snapshot, m.production_status, m.planned_quantity, m.actual_quantity, m.remaining_quantity, m.planned_date, m.planner_priority, m.current_operation_id, m.current_operation_code, m.current_operation_name, m.next_operation_id, m.next_operation_code, m.next_operation_name, m.last_completed_operation_id, m.last_completed_operation_code;;

