create or replace view public."v_production_order_execution" as
 SELECT po.organization_id,
    po.id AS production_order_id,
    po.order_no,
    po.source_order_no,
    po.product_id,
    po.routing_code_snapshot,
    po.routing_name_snapshot,
    po.routing_revision_snapshot,
    po.production_status,
    po.planned_quantity,
    po.actual_quantity,
    po.planned_date,
    po.planned_shift_id,
    po.planner_priority,
    current_op.id AS current_operation_id,
    current_op.sequence AS current_operation_sequence,
    current_op.operation_code_snapshot AS current_operation_code,
    current_op.operation_name_snapshot AS current_operation_name,
    next_op.id AS next_operation_id,
    next_op.sequence AS next_operation_sequence,
    next_op.operation_code_snapshot AS next_operation_code,
    next_op.operation_name_snapshot AS next_operation_name,
    last_op.id AS last_completed_operation_id,
    last_op.sequence AS last_completed_operation_sequence,
    last_op.operation_code_snapshot AS last_completed_operation_code,
    last_op.operation_name_snapshot AS last_completed_operation_name
   FROM (((production_orders po
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['IN_PROGRESS'::text, 'READY'::text, 'PENDING'::text, 'ON_HOLD'::text])))
          ORDER BY
                CASE x.status
                    WHEN 'IN_PROGRESS'::text THEN 0
                    WHEN 'ON_HOLD'::text THEN 1
                    WHEN 'READY'::text THEN 2
                    ELSE 3
                END, x.sequence
         LIMIT 1) current_op ON (true))
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['READY'::text, 'PENDING'::text])) AND ((current_op.sequence IS NULL) OR (x.sequence > current_op.sequence)))
          ORDER BY x.sequence
         LIMIT 1) next_op ON (true))
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['COMPLETED'::text, 'SKIPPED'::text])))
          ORDER BY x.sequence DESC
         LIMIT 1) last_op ON (true));;

