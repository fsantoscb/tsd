create or replace view public."v_production_order_current_operation" as
 SELECT organization_id,
    production_order_id,
    order_no,
    source_order_no,
    routing_code_snapshot,
    production_status,
    planned_quantity,
    actual_quantity,
    current_operation_id,
    current_operation_sequence,
    current_operation_code,
    current_operation_name,
    next_operation_id,
    next_operation_code,
    next_operation_name,
    last_completed_operation_id,
    last_completed_operation_code,
    last_completed_operation_name
   FROM v_production_order_execution e;;

