create or replace view public."v_active_wip_mo_coverage" as
 WITH canonical AS (
         SELECT v_manufacturing_order_current_operation.organization_id,
            v_manufacturing_order_current_operation.source_order_no,
                CASE
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'DTG_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DTG_PRINT'::text)) THEN 'DTG_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PUTWALL'::text)) THEN 'DTG_PUTWALL'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'DTG_DISPATCH'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'UP_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'UNDERPRINT'::text)) THEN 'UP_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'UP_DISPATCH'::text
                    ELSE NULL::text
                END AS stage_code,
            count(*) AS mo_count,
            (sum(v_manufacturing_order_current_operation.remaining_quantity))::numeric(14,3) AS units
           FROM v_manufacturing_order_current_operation
          GROUP BY v_manufacturing_order_current_operation.organization_id, v_manufacturing_order_current_operation.source_order_no,
                CASE
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'DTG_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DTG_PRINT'::text)) THEN 'DTG_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PUTWALL'::text)) THEN 'DTG_PUTWALL'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'DTG_DISPATCH'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'UP_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'UNDERPRINT'::text)) THEN 'UP_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'UP_DISPATCH'::text
                    ELSE NULL::text
                END
        )
 SELECT l.organization_id,
    l.source_order_no,
    l.stage_code,
    l.product_lines,
    l.units,
    l.line_source_available,
    COALESCE(c.mo_count, (0)::bigint) AS canonical_mos,
    (COALESCE(c.units, (0)::numeric))::numeric(14,3) AS canonical_units,
    ((COALESCE(c.units, (0)::numeric) - l.units))::numeric(14,3) AS unit_difference,
        CASE
            WHEN (COALESCE(c.mo_count, (0)::bigint) > 0) THEN 100.0
            ELSE 0.0
        END AS order_coverage_percent,
    round(((LEAST(COALESCE(c.units, (0)::numeric), l.units) / NULLIF(l.units, (0)::numeric)) * (100)::numeric), 1) AS unit_coverage_percent,
    e.primary_cause,
    e.blocking_cause,
    e.status AS exception_status
   FROM ((v_active_legacy_wip_detail l
     LEFT JOIN canonical c USING (organization_id, source_order_no, stage_code))
     LEFT JOIN active_wip_coverage_exceptions e ON (((e.organization_id = l.organization_id) AND (e.source_system = 'ORACLE_WMS'::text) AND (e.source_order_no = l.source_order_no) AND (e.stage_code = l.stage_code))));;

