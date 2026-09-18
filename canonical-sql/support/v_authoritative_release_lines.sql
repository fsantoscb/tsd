create or replace view public."v_authoritative_release_lines" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.sync_batch_id
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text) AND (oracle_line_ingestion_runs.status = 'COMPLETED'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC
        )
 SELECT s.organization_id,
    l.sync_batch_id,
    'ORACLE_WMS'::text AS source_system,
    s.source_order_no,
    s.source_line_id,
    s.source_product_code,
    s.source_description,
    s.production_units,
    s.released,
    s.raw_release_value,
    s.source_line_status,
    s.quantity_processed,
    s.source_weight,
    s.stock_reserved_flag,
    s.source_updated_at,
    l.id AS ingestion_run_id,
    s.source_routing,
    s.source_operational_code,
    s.source_operational_codes,
    s.operational_code_conflict,
    s.process_origin_code,
    s.process_origin_codes,
    s.process_origin_conflict,
    s.process_origin_at
   FROM (oracle_line_ingestion_staging s
     JOIN latest l ON ((l.id = s.ingestion_run_id)))
UNION ALL
 SELECT x.organization_id,
    x.sync_batch_id,
    x.source_system,
    x.source_order_no,
    x.source_line_id,
    x.source_product_code,
    x.source_description,
    x.production_units,
    x.released,
    x.raw_release_value,
    x.source_line_status,
    x.quantity_processed,
    x.source_weight,
    x.stock_reserved_flag,
    x.source_updated_at,
    x.ingestion_run_id,
    x.source_routing,
    x.source_operational_code,
    x.source_operational_codes,
    x.operational_code_conflict,
    x.process_origin_code,
    x.process_origin_codes,
    x.process_origin_conflict,
    x.process_origin_at
   FROM source_order_release_lines x
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM latest
          WHERE (latest.organization_id = x.organization_id)))) AND (x.source_presence = 'ACTIVE'::text));;

