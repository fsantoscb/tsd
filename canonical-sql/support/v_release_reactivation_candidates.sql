create or replace view public."v_release_reactivation_candidates" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.completed_at
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.status = 'COMPLETED'::text) AND (oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC, oracle_line_ingestion_runs.id DESC
        ), candidates AS (
         SELECT s.organization_id,
            s.source_order_no,
            s.source_line_id,
            s.production_units AS source_quantity,
            l.id AS reactivation_snapshot_run_id,
            l.completed_at AS reactivation_at,
            d.id AS production_demand_line_id,
            d.status AS demand_status,
            ml.id AS manufacturing_order_line_id,
            ml.manufacturing_order_id,
            ml.planned_quantity AS mapped_quantity,
            ml.actual_quantity AS executed_quantity,
            ml.created_at AS original_mapping_at,
            po.mo_number,
            po.production_status AS mo_status,
            ((d.resolution_status = 'RESOLVED'::text) AND (d.product_id IS NOT NULL) AND (d.routing_revision_id IS NOT NULL) AND (d.product_id = ml.product_id) AND (d.routing_revision_id = ml.routing_revision_id) AND (d.routing_revision_id = po.source_routing_id)) AS currently_eligible,
            rev.original_snapshot_run_id,
            rev.event_snapshot_run_id AS revocation_snapshot_run_id
           FROM (((((latest l
             JOIN oracle_line_ingestion_staging s ON ((s.ingestion_run_id = l.id)))
             JOIN production_demand_lines d ON (((d.organization_id = s.organization_id) AND (d.source_order_no = s.source_order_no) AND ((d.source_order_line_id = ('E56:'::text || s.source_line_id)) OR (d.source_order_line_id = ('E6:'::text || s.source_line_id))))))
             JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
             JOIN production_orders po ON ((po.id = ml.manufacturing_order_id)))
             JOIN LATERAL ( SELECT e.original_snapshot_run_id,
                    e.event_snapshot_run_id
                   FROM production_demand_release_events e
                  WHERE ((e.production_demand_line_id = d.id) AND (e.event_type = 'RELEASE_REVOKED_AFTER_MAPPING'::text))
                  ORDER BY e.event_at DESC, e.id DESC
                 LIMIT 1) rev ON (true))
          WHERE ((s.released = true) AND (s.raw_release_value = 'Y'::text) AND (d.status = 'CANCELLED'::text))
        )
 SELECT organization_id,
    source_order_no,
    source_line_id,
    source_quantity,
    reactivation_snapshot_run_id,
    reactivation_at,
    production_demand_line_id,
    demand_status,
    manufacturing_order_line_id,
    manufacturing_order_id,
    mapped_quantity,
    executed_quantity,
    original_mapping_at,
    mo_number,
    mo_status,
    currently_eligible,
    original_snapshot_run_id,
    revocation_snapshot_run_id,
    release_reactivation_action(mo_status, executed_quantity, currently_eligible) AS recommended_action
   FROM candidates c;;

