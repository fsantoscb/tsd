create or replace view public."v_release_revocation_candidates" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.completed_at
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.status = 'COMPLETED'::text) AND (oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC, oracle_line_ingestion_runs.id DESC
        )
 SELECT s.organization_id,
    s.source_order_no,
    s.source_line_id,
    s.production_units AS source_quantity,
    l.id AS revocation_snapshot_run_id,
    l.completed_at AS revocation_at,
    d.id AS production_demand_line_id,
    d.status AS demand_status,
    ml.id AS manufacturing_order_line_id,
    ml.manufacturing_order_id,
    ml.planned_quantity AS mapped_quantity,
    ml.actual_quantity AS executed_quantity,
    ml.created_at AS original_mapping_at,
    po.mo_number,
    po.production_status AS mo_status,
    o.id AS original_snapshot_run_id,
    o.released AS original_released,
    o.raw_release_value AS original_raw_release_value,
    ((o.released = true) AND (o.raw_release_value = 'Y'::text)) AS valid_at_creation,
    release_revocation_action(po.production_status, ml.actual_quantity, ((o.released = true) AND (o.raw_release_value = 'Y'::text))) AS recommended_action
   FROM (((((latest l
     JOIN oracle_line_ingestion_staging s ON ((s.ingestion_run_id = l.id)))
     JOIN production_demand_lines d ON (((d.organization_id = s.organization_id) AND (d.source_order_no = s.source_order_no) AND ((d.source_order_line_id = ('E56:'::text || s.source_line_id)) OR (d.source_order_line_id = ('E6:'::text || s.source_line_id))))))
     JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
     JOIN production_orders po ON ((po.id = ml.manufacturing_order_id)))
     LEFT JOIN LATERAL ( SELECT r.id,
            x.released,
            x.raw_release_value
           FROM (oracle_line_ingestion_runs r
             JOIN oracle_line_ingestion_staging x ON (((x.ingestion_run_id = r.id) AND (x.organization_id = s.organization_id) AND (x.source_order_no = s.source_order_no) AND (x.source_line_id = s.source_line_id))))
          WHERE ((r.status = 'COMPLETED'::text) AND (r.snapshot_status = 'COMPLETE'::text) AND (r.completed_at <= ml.created_at))
          ORDER BY r.completed_at DESC, r.id DESC
         LIMIT 1) o ON (true))
  WHERE ((s.released = false) AND (s.raw_release_value = 'N'::text));;

