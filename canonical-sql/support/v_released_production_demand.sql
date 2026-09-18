create or replace view public."v_released_production_demand" as
 SELECT (md5((((((l.organization_id)::text || '|'::text) || l.source_order_no) || '|'::text) || l.source_line_id)))::uuid AS id,
    l.organization_id,
    l.sync_batch_id,
    l.source_system,
    l.source_order_no,
    l.source_line_id,
    l.source_product_code,
    l.source_description,
    l.production_units,
    l.released,
    NULL::timestamp with time zone AS date_released,
    l.raw_release_value,
    l.source_updated_at AS created_at,
    l.source_line_status,
    l.quantity_processed,
    l.source_weight,
    l.stock_reserved_flag,
    l.source_updated_at,
    'SOURCE_CONFIRMED'::text AS release_provenance
   FROM (v_authoritative_release_lines l
     JOIN v_sales_order_release_eligibility e USING (organization_id, source_order_no))
  WHERE ((l.released = true) AND (l.raw_release_value = 'Y'::text) AND (e.release_eligibility <> 'NOT_APPLICABLE'::text));;

