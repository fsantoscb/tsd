create or replace view public."v_sales_order_release_state" as
 WITH l AS (
         SELECT v_authoritative_release_lines.organization_id,
            v_authoritative_release_lines.source_order_no,
            count(*) AS line_count,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released = true)) AS released_lines,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released = false)) AS unreleased_lines,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released IS NULL)) AS unknown_lines,
            sum(v_authoritative_release_lines.production_units) AS production_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released = true)) AS released_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released = false)) AS unreleased_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released IS NULL)) AS unknown_units,
            (array_agg(v_authoritative_release_lines.sync_batch_id))[1] AS sync_batch_id
           FROM v_authoritative_release_lines
          GROUP BY v_authoritative_release_lines.organization_id, v_authoritative_release_lines.source_order_no
        )
 SELECT o.organization_id,
    o.order_no AS source_order_no,
    o.customer_name,
    o.ship_to_name,
    o.date_received,
    o.date_due,
    o.date_released,
    o.source_status,
    o.source_sub_status,
    o.source_route_id,
    o.cost_centre,
    o.stop_ship_flag,
    o.source_priority,
    COALESCE(l.sync_batch_id, o.sync_batch_id) AS sync_batch_id,
    COALESCE(l.line_count, (0)::bigint) AS product_lines,
    COALESCE(l.production_units, (0)::numeric) AS production_units,
    COALESCE(l.released_lines, (0)::bigint) AS released_lines,
    COALESCE(l.unreleased_lines, (0)::bigint) AS unreleased_lines,
    COALESCE(l.released_units, (0)::numeric) AS released_units,
    COALESCE(l.unreleased_units, (0)::numeric) AS unreleased_units,
        CASE
            WHEN (COALESCE(l.line_count, (0)::bigint) = 0) THEN 'SOURCE_DATA_INVALID'::text
            WHEN (l.unknown_lines > 0) THEN 'UNKNOWN_RELEASE_STATUS'::text
            WHEN ((l.released_lines > 0) AND (l.unreleased_lines > 0)) THEN 'PARTIALLY_RELEASED'::text
            WHEN (l.released_lines = l.line_count) THEN 'RELEASED'::text
            WHEN (l.unreleased_lines = l.line_count) THEN 'UNRELEASED'::text
            ELSE 'SOURCE_DATA_INVALID'::text
        END AS release_status,
    COALESCE(l.unknown_lines, (0)::bigint) AS unknown_lines,
    COALESCE(l.unknown_units, (0)::numeric) AS unknown_units
   FROM (v_current_orders o
     LEFT JOIN l ON (((l.organization_id = o.organization_id) AND (l.source_order_no = o.order_no))));;

