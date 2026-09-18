create or replace view public."v_release_blockers" as
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'NOT_APPROVED'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.cost_centre, ''::text))) = 'NOTAPPRO'::text)
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'ROUTE_ID_NO'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.source_route_id, ''::text))) = 'NO'::text)
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'STOP_SHIP'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.stop_ship_flag, ''::text))) = ANY (ARRAY['Y'::text, 'YES'::text, '1'::text, 'TRUE'::text]))
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'NO_PRODUCTION_DEMAND'::text AS blocker
   FROM v_sales_order_release_state
  WHERE ((v_sales_order_release_state.product_lines > 0) AND (v_sales_order_release_state.production_units <= (0)::numeric))
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    v_sales_order_release_state.release_status AS blocker
   FROM v_sales_order_release_state
  WHERE (v_sales_order_release_state.release_status = ANY (ARRAY['SOURCE_DATA_INVALID'::text, 'UNKNOWN_RELEASE_STATUS'::text]));;

