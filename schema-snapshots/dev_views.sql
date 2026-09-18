-- public.maintenance_asset_code_reconciliation
CREATE OR REPLACE VIEW public.maintenance_asset_code_reconciliation AS
 SELECT id,
    organization_id,
    name AS current_name,
    asset_code AS current_code,
    NULL::text AS suggested_new_code,
        CASE
            WHEN (asset_code ~ '^[A-Z]{2,5}-[0-9]{3}(-[A-Z]{2,4}-[0-9]{2})?$'::text) THEN NULL::text
            ELSE 'INVALID_FORMAT'::text
        END AS conflict
   FROM maintenance_assets;

-- public.maintenance_asset_current_installations
CREATE OR REPLACE VIEW public.maintenance_asset_current_installations AS
 SELECT i.id,
    i.organization_id,
    i.movement_id,
    i.movable_asset_id,
    i.host_asset_id,
    i.host_system_asset_id,
    i."position",
    i.channel,
    i.installed_at,
    i.removed_at,
    i.movement_reason,
    i.installed_by,
    i.notes,
    i.created_at,
    i.updated_at,
    m.asset_code AS movable_asset_code,
    h.asset_code AS host_asset_code,
    s.asset_code AS host_system_asset_code
   FROM (((maintenance_asset_installations i
     JOIN maintenance_assets m ON ((m.id = i.movable_asset_id)))
     JOIN maintenance_assets h ON ((h.id = i.host_asset_id)))
     LEFT JOIN maintenance_assets s ON ((s.id = i.host_system_asset_id)))
  WHERE (i.removed_at IS NULL);

-- public.maintenance_part_stock_levels
CREATE OR REPLACE VIEW public.maintenance_part_stock_levels AS
 SELECT p.organization_id,
    p.id AS part_id,
    p.part_number,
    p.description,
    p.manufacturer,
    p.unit_cost,
    p.reorder_point,
    l.id AS location_id,
    l.name AS location,
    (COALESCE(sum(t.quantity), (0)::numeric))::numeric(14,2) AS stock_on_hand
   FROM ((maintenance_parts p
     CROSS JOIN maintenance_inventory_locations l)
     LEFT JOIN maintenance_inventory_transactions t ON (((t.part_id = p.id) AND (t.location_id = l.id))))
  WHERE (p.active AND l.active AND (p.organization_id = l.organization_id))
  GROUP BY p.organization_id, p.id, l.id;

-- public.v_active_legacy_wip_detail
CREATE OR REPLACE VIEW public.v_active_legacy_wip_detail AS
 WITH source_rows AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no AS source_order_no,
                CASE
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'SP11'::text) THEN 'DTG_PICKING'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'PCOR'::text) THEN 'DTG_PRINTING'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text) THEN 'DTG_PUTWALL'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_location, ''::text))) ~~ '%UP'::text) THEN 'UP_PRINTING'::text
                    ELSE NULL::text
                END AS stage_code,
            v_current_workbank.production_units AS units,
            v_current_workbank.source_row_id,
            v_current_workbank.product_code,
            ((NULLIF(v_current_workbank.product_code, ''::text) IS NOT NULL) AND (v_current_workbank.product_code !~ '^#?[0-9]+$'::text)) AS line_source_available
           FROM v_current_workbank
          WHERE ((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = ANY (ARRAY['SP11'::text, 'PCOR'::text])) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_location, ''::text))) ~~ '%UP'::text))
        UNION ALL
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS regexp_replace,
            'UP_PICKING'::text,
            v_current_stock.production_units,
            (v_current_stock.id)::text AS id,
            v_current_stock.product,
            false
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
        UNION ALL
         SELECT source_audit_events.organization_id,
            source_audit_events.order_no,
                CASE upper(TRIM(BOTH FROM source_audit_events.to_location))
                    WHEN 'DTGMOVE'::text THEN 'DTG_DISPATCH'::text
                    ELSE 'UP_DISPATCH'::text
                END AS "case",
            source_audit_events.production_units,
            COALESCE(source_audit_events.source_audit_id, (source_audit_events.id)::text) AS "coalesce",
            source_audit_events.product,
            false
           FROM source_audit_events
          WHERE ((upper(TRIM(BOTH FROM COALESCE(source_audit_events.to_location, ''::text))) = ANY (ARRAY['DTGMOVE'::text, 'UPMOVE'::text])) AND (((source_audit_events.event_at AT TIME ZONE 'Australia/Brisbane'::text))::date = ((now() AT TIME ZONE 'Australia/Brisbane'::text))::date))
        )
 SELECT organization_id,
    source_order_no,
    stage_code,
    count(*) AS product_lines,
    (sum(COALESCE(units, (0)::numeric)))::numeric(14,3) AS units,
    bool_or(line_source_available) AS line_source_available
   FROM source_rows
  WHERE ((NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL) AND (stage_code IS NOT NULL))
  GROUP BY organization_id, source_order_no, stage_code;

-- public.v_active_order_process_summary
CREATE OR REPLACE VIEW public.v_active_order_process_summary AS
 WITH x AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no AS source_order_no,
            'DTG'::text AS process_code,
                CASE
                    WHEN bool_or((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text)) THEN 'PWL1'::text
                    WHEN bool_or((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'PCOR'::text)) THEN 'PCOR'::text
                    ELSE 'SP11'::text
                END AS current_stage,
            (sum(v_current_workbank.production_units))::numeric(14,3) AS units,
            min(v_current_workbank.source_due_at) AS due_date,
            min(v_current_workbank.source_priority) AS priority
           FROM v_current_workbank
          WHERE ((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = ANY (ARRAY['SP11'::text, 'PCOR'::text])) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text))
          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no
        UNION ALL
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS regexp_replace,
            'UNDERPRINT'::text,
            'STOCK_UNDERPRINT'::text,
            (sum(v_current_stock.production_units))::numeric(14,3) AS sum,
            NULL::timestamp with time zone,
            NULL::integer
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
          GROUP BY v_current_stock.organization_id, (regexp_replace(v_current_stock.product, '^#'::text, ''::text))
        )
 SELECT organization_id,
    source_order_no,
    process_code,
    current_stage,
    units,
    due_date,
    priority,
    count(*) OVER (PARTITION BY organization_id, source_order_no) AS process_count
   FROM x;

-- public.v_active_source_product_lines
CREATE OR REPLACE VIEW public.v_active_source_product_lines AS
 WITH active AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no AS source_order_no,
            'DTG'::text AS process_code,
            (sum(v_current_workbank.production_units))::numeric(14,3) AS active_units
           FROM v_current_workbank
          WHERE ((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = ANY (ARRAY['SP11'::text, 'PCOR'::text])) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text))
          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no
        UNION ALL
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS regexp_replace,
            'UNDERPRINT'::text,
            (sum(v_current_stock.production_units))::numeric(14,3) AS sum
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
          GROUP BY v_current_stock.organization_id, (regexp_replace(v_current_stock.product, '^#'::text, ''::text))
        UNION ALL
         SELECT screen_print_jobs.organization_id,
            COALESCE(screen_print_jobs.order_no, (screen_print_jobs.id)::text) AS "coalesce",
            'SCREEN_PRINT'::text,
            (sum(GREATEST((screen_print_jobs.planned_quantity - screen_print_jobs.completed_quantity), (0)::numeric)))::numeric(14,3) AS sum
           FROM screen_print_jobs
          WHERE (screen_print_jobs.status <> ALL (ARRAY['completed'::text, 'cancelled'::text]))
          GROUP BY screen_print_jobs.organization_id, COALESCE(screen_print_jobs.order_no, (screen_print_jobs.id)::text)
        ), historical AS (
         SELECT x.organization_id,
            x.source_order_no,
            x.source_line_id,
            x.source_sku,
            x.source_description,
            x.quantity,
            x.rn
           FROM ( SELECT w.organization_id,
                    w.order_no AS source_order_no,
                    w.source_row_id AS source_line_id,
                    w.product_code AS source_sku,
                    w.product_description AS source_description,
                    w.production_units AS quantity,
                    row_number() OVER (PARTITION BY w.organization_id, w.order_no, w.source_row_id ORDER BY w.created_at DESC, w.id DESC) AS rn
                   FROM source_workbank_items w
                  WHERE ((NULLIF(w.source_row_id, ''::text) IS NOT NULL) AND (NULLIF(w.product_code, ''::text) IS NOT NULL) AND (w.product_code !~ '^#?[0-9]+$'::text) AND (w.production_units > (0)::numeric))) x
          WHERE (x.rn = 1)
        ), expanded AS (
         SELECT a.organization_id,
            a.source_order_no,
            a.process_code,
            h.source_line_id,
            h.source_sku,
            h.source_description,
            h.quantity,
            a.active_units
           FROM (active a
             JOIN historical h ON (((h.organization_id = a.organization_id) AND (h.source_order_no = a.source_order_no))))
        UNION ALL
         SELECT a.organization_id,
            a.source_order_no,
            a.process_code,
            ((('MISSING:'::text || a.process_code) || ':'::text) || a.source_order_no),
            NULL::text,
            NULL::text,
            a.active_units,
            a.active_units
           FROM active a
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM historical h
                  WHERE ((h.organization_id = a.organization_id) AND (h.source_order_no = a.source_order_no)))))
        )
 SELECT organization_id,
    source_order_no,
    process_code,
    source_line_id,
    source_sku,
    source_description,
    quantity,
    active_units,
        CASE
            WHEN (source_sku IS NULL) THEN 'SOURCE_LINE_MISSING'::text
            ELSE NULL::text
        END AS source_gap
   FROM expanded;

-- public.v_active_source_product_task_context
CREATE OR REPLACE VIEW public.v_active_source_product_task_context AS
 SELECT l.organization_id,
    l.source_order_no,
    l.process_code,
    l.source_line_id,
    l.source_sku,
    l.source_description,
    l.quantity,
    l.active_units,
    l.source_gap,
    t.source_task,
    t.queue,
    t.from_zone,
    t.process_code AS task_process_code,
    t.operation_code AS task_operation_code,
    t.resolution_status AS task_resolution_status,
    resolve_product_process_routing(l.organization_id, pm.product_id, t.process_code, NULL::uuid) AS resolved_routing_id
   FROM ((v_active_source_product_lines l
     LEFT JOIN LATERAL ( SELECT r.organization_id,
            r.source_dataset,
            r.source_record_key,
            r.order_no,
            r.source_task,
            r.queue,
            r.from_zone,
            r.to_zone,
            r.from_location,
            r.to_location,
            r.production_units,
            r.observed_at,
            r.mapping_id,
            r.production_process_id,
            r.process_code,
            r.operation_id,
            r.operation_code,
            r.resolution_status
           FROM v_source_task_resolution r
          WHERE ((r.organization_id = l.organization_id) AND (r.order_no = l.source_order_no) AND (r.source_dataset = 'WORKBANK'::text))
          ORDER BY r.observed_at DESC, r.source_record_key
         LIMIT 1) t ON (true))
     LEFT JOIN product_source_mappings pm ON (((pm.organization_id = l.organization_id) AND (pm.source_system = 'ORACLE_WMS'::text) AND (pm.source_product_code = l.source_sku) AND pm.active)));

-- public.v_active_wip_coverage_metrics
CREATE OR REPLACE VIEW public.v_active_wip_coverage_metrics AS
 SELECT organization_id,
    stage_code,
    count(*) AS legacy_orders,
    (sum(units))::numeric(14,3) AS legacy_units,
    count(*) FILTER (WHERE (canonical_mos > 0)) AS represented_orders,
    (sum(canonical_mos))::integer AS canonical_mos,
    (sum(canonical_units))::numeric(14,3) AS canonical_units,
    round((((count(*) FILTER (WHERE (canonical_mos > 0)))::numeric / (NULLIF(count(*), 0))::numeric) * (100)::numeric), 1) AS order_coverage_percent,
    round(((sum(LEAST(canonical_units, units)) / NULLIF(sum(units), (0)::numeric)) * (100)::numeric), 1) AS unit_coverage_percent,
    count(*) FILTER (WHERE (canonical_mos = 0)) AS missing_mo_orders,
    (sum(units) FILTER (WHERE (canonical_mos = 0)))::numeric(14,3) AS missing_mo_units,
    (COALESCE(sum(units) FILTER (WHERE (blocking_cause = ANY (ARRAY['PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text]))), (0)::numeric))::numeric(14,3) AS unmapped_units,
    (COALESCE(sum(units) FILTER (WHERE (COALESCE(blocking_cause, 'UNKNOWN'::text) = 'UNKNOWN'::text)), (0)::numeric))::numeric(14,3) AS unknown_units
   FROM v_active_wip_mo_coverage
  GROUP BY organization_id, stage_code;

-- public.v_active_wip_mo_coverage
CREATE OR REPLACE VIEW public.v_active_wip_mo_coverage AS
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
     LEFT JOIN active_wip_coverage_exceptions e ON (((e.organization_id = l.organization_id) AND (e.source_system = 'ORACLE_WMS'::text) AND (e.source_order_no = l.source_order_no) AND (e.stage_code = l.stage_code))));

-- public.v_authoritative_release_lines
CREATE OR REPLACE VIEW public.v_authoritative_release_lines AS
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
          WHERE (latest.organization_id = x.organization_id)))) AND (x.source_presence = 'ACTIVE'::text));

-- public.v_capacity_load
CREATE OR REPLACE VIEW public.v_capacity_load AS
 WITH demand AS (
         SELECT v_production_planning.organization_id,
            v_production_planning.line AS area_code,
            sum(v_production_planning.remaining_units) AS demand_units
           FROM v_production_planning
          WHERE (COALESCE(v_production_planning.planning_status, 'unplanned'::text) <> ALL (ARRAY['completed'::text, 'cancelled'::text]))
          GROUP BY v_production_planning.organization_id, v_production_planning.line
        ), profile_capacity AS (
         SELECT p.organization_id,
            a.code AS area_code,
            sum((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency)) AS daily_capacity,
            sum(((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency) * p.work_days)) AS weekly_capacity
           FROM (capacity_profiles p
             JOIN production_areas a ON ((a.id = p.production_area_id)))
          WHERE p.active
          GROUP BY p.organization_id, a.code
        ), legacy_capacity AS (
         SELECT o.organization_id,
            a.code AS area_code,
            sum(o.daily_capacity) AS daily_capacity,
            sum((o.daily_capacity * o.work_days)) AS weekly_capacity
           FROM (capacity_legacy_overrides o
             JOIN production_areas a ON ((a.id = o.production_area_id)))
          WHERE o.active
          GROUP BY o.organization_id, a.code
        ), capacity AS (
         SELECT profile_capacity.organization_id,
            profile_capacity.area_code,
            profile_capacity.daily_capacity,
            profile_capacity.weekly_capacity
           FROM profile_capacity
        UNION ALL
         SELECT l.organization_id,
            l.area_code,
            l.daily_capacity,
            l.weekly_capacity
           FROM legacy_capacity l
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM profile_capacity p
                  WHERE ((p.organization_id = l.organization_id) AND (p.area_code = l.area_code)))))
        )
 SELECT c.organization_id,
    c.area_code,
    COALESCE(d.demand_units, (0)::numeric) AS demand_units,
    c.daily_capacity,
    c.weekly_capacity,
        CASE
            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric
            ELSE round(((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity) * (100)::numeric), 2)
        END AS load_percent,
    (c.daily_capacity - COALESCE(d.demand_units, (0)::numeric)) AS capacity_gap,
        CASE
            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric
            ELSE round((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity), 2)
        END AS relative_lead_days
   FROM (capacity c
     LEFT JOIN demand d USING (organization_id, area_code));

-- public.v_current_labour_segments
CREATE OR REPLACE VIEW public.v_current_labour_segments AS
 WITH ranked AS (
         SELECT r_1.id,
            row_number() OVER (PARTITION BY r_1.organization_id, COALESCE(NULLIF(r_1.source_timesheet_id, ''::text), r_1.source_row_key) ORDER BY b.imported_at DESC, r_1.created_at DESC) AS rn
           FROM (deputy_raw_timesheets r_1
             JOIN deputy_import_batches b ON ((b.id = r_1.import_batch_id)))
          WHERE ((b.status = 'COMPLETED'::text) AND (r_1.row_status = 'ACCEPTED'::text))
        )
 SELECT s.id,
    s.organization_id,
    s.import_batch_id,
    s.source_timesheet_row_id,
    s.person_key,
    s.area_code,
    s.segment_start,
    s.segment_end,
    s.calendar_date,
    s.operational_date,
    s.hour_bucket,
    s.shift_code,
    s.paid_hours,
    s.regular_hours,
    s.overtime_hours,
    s.paid_break_hours,
    s.productive_hours,
    s.approval_status,
    s.allocation_method,
    s.week_start,
    s.calculation_version,
    s.created_at
   FROM (labour_segments s
     JOIN ranked r ON (((r.id = s.source_timesheet_row_id) AND (r.rn = 1))));

-- public.v_current_orders
CREATE OR REPLACE VIEW public.v_current_orders AS
 SELECT o.id,
    o.organization_id,
    o.sync_batch_id,
    o.order_no,
    o.date_received,
    o.date_due,
    o.date_released,
    o.source_status,
    o.source_sub_status,
    o.customer_code,
    o.customer_name,
    o.ship_to_name,
    o.customer_state,
    o.city,
    o.delivery_desc,
    o.client_so_number,
    o.source_priority,
    o.source_updated_at,
    o.created_at,
    o.site,
    o.source_route_id,
    o.cost_centre,
    o.stop_ship_flag
   FROM (source_orders o
     JOIN v_latest_completed_batch b ON ((b.id = o.sync_batch_id)));

-- public.v_current_stock
CREATE OR REPLACE VIEW public.v_current_stock AS
 SELECT s.id,
    s.organization_id,
    s.sync_batch_id,
    s.product,
    s.pack_id,
    s.location,
    s.source_timestamp,
    s.source_qty,
    s.source_weight,
    s.production_units,
    s.created_at,
    s.source_zone
   FROM (source_stock_items s
     JOIN v_latest_completed_batch b ON ((b.id = s.sync_batch_id)));

-- public.v_current_workbank
CREATE OR REPLACE VIEW public.v_current_workbank AS
 SELECT w.id,
    w.organization_id,
    w.sync_batch_id,
    w.source_row_id,
    w.order_no,
    w.customer_code,
    w.customer_name,
    w.source_due_at,
    w.from_location,
    w.from_zone,
    w.to_location,
    w.from_pack_id,
    w.to_pack_id,
    w.source_priority,
    w.product_code,
    w.product_description,
    w.product_group,
    w.source_qty,
    w.source_weight,
    w.production_units,
    w.queue,
    w.task,
    w.created_at,
    w.prints_per_garment
   FROM (source_workbank_items w
     JOIN v_latest_completed_batch b ON ((b.id = w.sync_batch_id)));

-- public.v_daily_plans
CREATE OR REPLACE VIEW public.v_daily_plans AS
 SELECT p.id,
    p.organization_id,
    p.production_date,
    p.shift_template_id,
    p.production_area_id,
    p.status,
    p.version,
    p.created_by,
    p.published_by,
    p.published_at,
    p.closed_by,
    p.closed_at,
    p.created_at,
    p.updated_at,
    s.name AS shift_name,
    a.code AS area_code,
    a.name AS area_name,
    count(i.id) AS item_count,
    COALESCE(sum(i.planned_units), (0)::numeric) AS planned_units
   FROM (((production_plans p
     JOIN shift_templates s ON ((s.id = p.shift_template_id)))
     JOIN production_areas a ON ((a.id = p.production_area_id)))
     LEFT JOIN production_plan_items i ON ((i.production_plan_id = p.id)))
  GROUP BY p.id, s.name, a.code, a.name;

-- public.v_dtg_operational_orders
CREATE OR REPLACE VIEW public.v_dtg_operational_orders AS
 SELECT w.organization_id,
    w.order_no,
    max(COALESCE(w.customer_name, o.customer_name)) AS customer_name,
    max(o.delivery_desc) AS screen,
    max(o.source_status) AS status,
    max(COALESCE(w.source_priority, o.source_priority)) AS priority,
    min(COALESCE(w.source_due_at, o.date_due)) AS date_due,
    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((max(o.date_released) AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,
    count(*) AS item_count,
    (count(*))::numeric AS remaining_units,
    NULL::timestamp with time zone AS last_movement,
    string_agg(DISTINCT COALESCE(NULLIF(w.to_location, ''::text), w.from_location), ', '::text ORDER BY COALESCE(NULLIF(w.to_location, ''::text), w.from_location)) AS putwall_locations,
    'At DTG'::text AS progress_label,
    sum(w.prints_per_garment) AS total_prints,
    sum(
        CASE
            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text)) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS adult_prints,
    sum(
        CASE
            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text)) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS kids_prints,
    sum(
        CASE
            WHEN (NOT ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text))) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS unclassified_prints
   FROM (v_current_workbank w
     LEFT JOIN v_current_orders o ON (((o.organization_id = w.organization_id) AND (o.order_no = w.order_no))))
  WHERE (upper(COALESCE(w.from_zone, ''::text)) = 'DTGS'::text)
  GROUP BY w.organization_id, w.order_no;

-- public.v_dtg_order_history
CREATE OR REPLACE VIEW public.v_dtg_order_history AS
 SELECT order_no,
    count(*) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS printed,
    min(event_at) FILTER (WHERE ((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text))) AS first_pick,
    min(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS first_print,
    max(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS last_print
   FROM source_audit_events
  WHERE (((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text)) OR ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text)))
  GROUP BY order_no;

-- public.v_e56_mo_pilot_reconciliation
CREATE OR REPLACE VIEW public.v_e56_mo_pilot_reconciliation AS
 WITH expected AS (
         SELECT r_1.organization_id,
            r_1.source_order_no,
            r_1.resolved_routing_id,
            (sum(r_1.source_quantity))::numeric(14,3) AS expected_quantity,
            count(*) AS expected_lines
           FROM (v_released_demand_resolution r_1
             JOIN e56_mo_pilot_orders p ON (((p.organization_id = r_1.organization_id) AND (p.source_order_no = r_1.source_order_no))))
          WHERE (r_1.eligibility_status = 'ELIGIBLE'::text)
          GROUP BY r_1.organization_id, r_1.source_order_no, r_1.resolved_routing_id
        ), represented AS (
         SELECT d.organization_id,
            d.source_order_no,
            d.routing_revision_id,
            (sum(ml.planned_quantity))::numeric(14,3) AS represented_quantity,
            count(*) AS represented_lines,
            count(DISTINCT ml.manufacturing_order_id) AS mo_count
           FROM (production_demand_lines d
             JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
          WHERE (d.source_order_line_id ~~ 'E56:%'::text)
          GROUP BY d.organization_id, d.source_order_no, d.routing_revision_id
        ), exceptions AS (
         SELECT e56_mo_pilot_exceptions.organization_id,
            e56_mo_pilot_exceptions.source_order_no,
            e56_mo_pilot_exceptions.routing_id,
            (sum(e56_mo_pilot_exceptions.quantity))::numeric(14,3) AS exception_quantity
           FROM e56_mo_pilot_exceptions
          WHERE (e56_mo_pilot_exceptions.exception_code = 'MO_ALREADY_IN_PROGRESS'::text)
          GROUP BY e56_mo_pilot_exceptions.organization_id, e56_mo_pilot_exceptions.source_order_no, e56_mo_pilot_exceptions.routing_id
        )
 SELECT e.organization_id,
    e.source_order_no,
    e.resolved_routing_id,
    e.expected_quantity,
    e.expected_lines,
    COALESCE(r.represented_quantity, (0)::numeric) AS represented_quantity,
    COALESCE(r.represented_lines, (0)::bigint) AS represented_lines,
    COALESCE(r.mo_count, (0)::bigint) AS mo_count,
    ((e.expected_quantity - COALESCE(r.represented_quantity, (0)::numeric)) - COALESCE(x.exception_quantity, (0)::numeric)) AS unexplained_difference,
        CASE
            WHEN ((e.expected_quantity = (COALESCE(r.represented_quantity, (0)::numeric) + COALESCE(x.exception_quantity, (0)::numeric))) AND (COALESCE(r.mo_count, (0)::bigint) <= 1)) THEN 'PASS'::text
            ELSE 'FAIL'::text
        END AS result,
    COALESCE(x.exception_quantity, (0)::numeric) AS exception_quantity
   FROM ((expected e
     LEFT JOIN represented r ON (((r.organization_id = e.organization_id) AND (r.source_order_no = e.source_order_no) AND (r.routing_revision_id = e.resolved_routing_id))))
     LEFT JOIN exceptions x ON (((x.organization_id = e.organization_id) AND (x.source_order_no = e.source_order_no) AND (x.routing_id = e.resolved_routing_id))));

-- public.v_e61_exception_decomposition
CREATE OR REPLACE VIEW public.v_e61_exception_decomposition AS
 WITH wb AS (
         SELECT c.id AS classification_id,
            count(DISTINCT upper(TRIM(BOTH FROM w.product_group))) FILTER (WHERE (NULLIF(TRIM(BOTH FROM w.product_group), ''::text) IS NOT NULL)) AS group_count,
            min(upper(TRIM(BOTH FROM w.product_group))) FILTER (WHERE (NULLIF(TRIM(BOTH FROM w.product_group), ''::text) IS NOT NULL)) AS product_group,
            string_agg(DISTINCT w.task, ', '::text ORDER BY w.task) AS tasks,
            string_agg(DISTINCT w.queue, ', '::text ORDER BY w.queue) AS queues,
            string_agg(DISTINCT w.from_zone, ', '::text ORDER BY w.from_zone) AS from_zones,
            string_agg(DISTINCT w.to_location, ', '::text ORDER BY w.to_location) AS to_locations,
            min(NULLIF(TRIM(BOTH FROM w.product_description), ''::text)) AS product_description
           FROM (e6_scope_classifications c
             LEFT JOIN v_current_workbank w ON (((w.organization_id = c.organization_id) AND (w.order_no = c.source_order_no) AND (upper(TRIM(BOTH FROM w.product_code)) = upper(TRIM(BOTH FROM c.source_product_code))))))
          WHERE (c.scope_classification = 'CONTROLLED_EXCEPTION'::text)
          GROUP BY c.id
        ), blockers AS (
         SELECT c.id AS classification_id,
            string_agg(DISTINCT b_1.blocker, '+'::text ORDER BY b_1.blocker) AS blockers,
            count(DISTINCT b_1.blocker) AS blocker_count
           FROM (e6_scope_classifications c
             LEFT JOIN v_release_blockers b_1 ON (((b_1.organization_id = c.organization_id) AND (b_1.source_order_no = c.source_order_no))))
          WHERE (c.scope_classification = 'CONTROLLED_EXCEPTION'::text)
          GROUP BY c.id
        ), base AS (
         SELECT c.id,
            c.run_id,
            c.organization_id,
            c.snapshot_run_id,
            c.source_order_no,
            c.source_line_id,
            c.source_product_code,
            c.product_id,
            c.routing_id,
            c.process_code,
            c.source_tasks,
            c.quantity,
            c.scope_classification,
            c.reason_code,
            c.reason_detail,
            c.created_at,
            a.released,
            a.raw_release_value,
            a.source_description,
            COALESCE(a.source_description, p.description, wb.product_description) AS candidate_description,
            p.sku AS canonical_product,
            p.description AS canonical_description,
            r.code AS routing_code,
            e.release_eligibility,
            wb.product_group,
            wb.tasks,
            wb.queues,
            wb.from_zones,
            wb.to_locations,
            bl.blockers,
            COALESCE(bl.blocker_count, (0)::bigint) AS blocker_count,
                CASE
                    WHEN (c.process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text])) THEN c.process_code
                    WHEN ((wb.group_count = 1) AND (wb.product_group = 'UNDERPRINT'::text)) THEN 'UNDERPRINT'::text
                    WHEN ((wb.group_count = 1) AND (wb.product_group = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))) THEN 'DTG'::text
                    ELSE 'UNKNOWN'::text
                END AS deterministic_process
           FROM ((((((e6_scope_classifications c
             JOIN v_authoritative_release_lines a ON (((a.organization_id = c.organization_id) AND (a.source_order_no = c.source_order_no) AND (a.source_line_id = c.source_line_id) AND (a.ingestion_run_id = c.snapshot_run_id))))
             LEFT JOIN products p ON ((p.id = c.product_id)))
             LEFT JOIN routings r ON ((r.id = c.routing_id)))
             LEFT JOIN v_sales_order_release_eligibility e ON (((e.organization_id = c.organization_id) AND (e.source_order_no = c.source_order_no))))
             LEFT JOIN wb ON ((wb.classification_id = c.id)))
             LEFT JOIN blockers bl ON ((bl.classification_id = c.id)))
          WHERE (c.scope_classification = 'CONTROLLED_EXCEPTION'::text)
        )
 SELECT id,
    run_id,
    organization_id,
    snapshot_run_id,
    source_order_no,
    source_line_id,
    source_product_code,
    product_id,
    routing_id,
    process_code,
    source_tasks,
    quantity,
    scope_classification,
    reason_code,
    reason_detail,
    created_at,
    released,
    raw_release_value,
    source_description,
    candidate_description,
    canonical_product,
    canonical_description,
    routing_code,
    release_eligibility,
    product_group,
    tasks,
    queues,
    from_zones,
    to_locations,
    blockers,
    blocker_count,
    deterministic_process,
        CASE
            WHEN ((reason_code = 'ELIGIBILITY_BLOCKED'::text) AND (blocker_count > 0)) THEN ('KNOWN_ELIGIBILITY_BLOCKER:'::text || blockers)
            WHEN (reason_code = 'ELIGIBILITY_BLOCKED'::text) THEN 'TRUE_ELIGIBILITY_UNRESOLVED'::text
            WHEN (reason_code = 'INVALID_ZERO_QUANTITY'::text) THEN 'OTHER_EXPLICIT_CONTROLLED_EXCEPTION:INVALID_ZERO_QUANTITY'::text
            WHEN ((reason_code = 'PRODUCT_UNRESOLVED'::text) AND (deterministic_process = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))) THEN ('TRUE_PRODUCT_UNRESOLVED:'::text || deterministic_process)
            WHEN ((reason_code = 'PROCESS_UNRESOLVED'::text) AND (product_id IS NOT NULL) AND (deterministic_process = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))) THEN ('ROUTING_UNRESOLVED:'::text || deterministic_process)
            WHEN ((reason_code = 'PROCESS_UNRESOLVED'::text) AND (product_id IS NOT NULL)) THEN 'TRUE_PROCESS_UNRESOLVED'::text
            WHEN ((reason_code = 'PRODUCT_UNRESOLVED'::text) AND (deterministic_process = 'UNKNOWN'::text)) THEN 'PRODUCT_AND_PROCESS_UNRESOLVED'::text
            ELSE ('OTHER_EXPLICIT_CONTROLLED_EXCEPTION:'::text || reason_code)
        END AS exception_category,
        CASE
            WHEN ((reason_code = 'ELIGIBILITY_BLOCKED'::text) AND (blocker_count > 0)) THEN 'SAFE_EXCLUSION'::text
            WHEN (reason_code = 'INVALID_ZERO_QUANTITY'::text) THEN 'SAFE_EXCLUSION'::text
            ELSE 'BLOCKING_EXCEPTION'::text
        END AS readiness_group,
        CASE
            WHEN (deterministic_process = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text])) THEN deterministic_process
            ELSE 'UNKNOWN'::text
        END AS process_scope
   FROM base b;

-- public.v_e61_exception_summary
CREATE OR REPLACE VIEW public.v_e61_exception_summary AS
 SELECT run_id,
    exception_category,
    readiness_group,
    process_scope,
    count(*) AS lines,
    (sum(quantity))::numeric(14,3) AS quantity,
    count(DISTINCT source_product_code) AS unique_skus,
    count(DISTINCT source_order_no) AS unique_sales_orders
   FROM v_e61_exception_decomposition
  GROUP BY run_id, exception_category, readiness_group, process_scope;

-- public.v_e62_resolution_dry_run
CREATE OR REPLACE VIEW public.v_e62_resolution_dry_run AS
 WITH product_context AS (
         SELECT product_source_mappings.organization_id,
            product_source_mappings.source_product_code,
            count(DISTINCT product_source_mappings.product_id) AS product_count,
            (min((product_source_mappings.product_id)::text))::uuid AS product_id
           FROM product_source_mappings
          WHERE ((product_source_mappings.source_system = 'ORACLE_WMS'::text) AND product_source_mappings.active)
          GROUP BY product_source_mappings.organization_id, product_source_mappings.source_product_code
        )
 SELECT c.run_id,
    c.organization_id,
    c.snapshot_run_id,
    c.source_order_no,
    c.source_line_id,
    c.source_product_code,
    c.quantity,
    c.reason_code,
    pc.product_id,
    p.process_code,
    p.confidence AS process_confidence,
    p.resolution_rule,
    p.conflict_count,
        CASE
            WHEN (pc.product_count = 1) THEN 'SOURCE_CONFIRMED'::text
            WHEN (pc.product_count > 1) THEN 'AMBIGUOUS'::text
            ELSE 'UNRESOLVED'::text
        END AS product_confidence,
        CASE
            WHEN ((pc.product_count = 1) AND (p.process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))) THEN resolve_product_process_routing(c.organization_id, pc.product_id, p.process_code, NULL::uuid)
            ELSE NULL::uuid
        END AS routing_id,
        CASE
            WHEN ((pc.product_count > 1) OR (p.confidence = 'AMBIGUOUS'::text)) THEN 'AMBIGUOUS'::text
            WHEN ((pc.product_count = 1) AND (p.process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text])) AND (resolve_product_process_routing(c.organization_id, pc.product_id, p.process_code, NULL::uuid) IS NOT NULL)) THEN 'RESOLVED_SUPPORTED'::text
            ELSE 'UNRESOLVED'::text
        END AS resolution_status
   FROM ((e6_scope_classifications c
     LEFT JOIN product_context pc ON (((pc.organization_id = c.organization_id) AND (pc.source_product_code = c.source_product_code))))
     CROSS JOIN LATERAL resolve_canonical_process_context(c.organization_id, c.source_order_no, c.source_product_code) p(process_code, confidence, resolution_rule, conflict_count))
  WHERE ((c.scope_classification = 'CONTROLLED_EXCEPTION'::text) AND (c.reason_code = ANY (ARRAY['PRODUCT_UNRESOLVED'::text, 'PROCESS_UNRESOLVED'::text])));

-- public.v_e6_reconciliation
CREATE OR REPLACE VIEW public.v_e6_reconciliation AS
 SELECT c.run_id,
    c.scope_classification,
    count(*) AS lines,
    (sum(c.quantity))::numeric(14,3) AS quantity,
    count(*) FILTER (WHERE (ml.id IS NOT NULL)) AS mapped_lines,
    (COALESCE(sum(c.quantity) FILTER (WHERE (ml.id IS NOT NULL)), (0)::numeric))::numeric(14,3) AS represented_quantity
   FROM ((e6_scope_classifications c
     LEFT JOIN LATERAL ( SELECT d_1.id
           FROM production_demand_lines d_1
          WHERE ((d_1.organization_id = c.organization_id) AND (d_1.source_system = 'ORACLE_WMS'::text) AND (d_1.source_order_no = c.source_order_no) AND (d_1.source_order_line_id = ANY (ARRAY[('E56:'::text || c.source_line_id), ('E6:'::text || c.source_line_id)])))
         LIMIT 1) d ON (true))
     LEFT JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
  GROUP BY c.run_id, c.scope_classification;

-- public.v_e6_scope_report
CREATE OR REPLACE VIEW public.v_e6_scope_report AS
 SELECT run_id,
    scope_classification,
    COALESCE(process_code, 'UNRESOLVED'::text) AS process_code,
    count(*) AS lines,
    (sum(quantity))::numeric(14,3) AS quantity,
    count(DISTINCT source_order_no) AS unique_sales_orders,
    count(DISTINCT product_id) AS unique_products
   FROM e6_scope_classifications
  GROUP BY run_id, scope_classification, COALESCE(process_code, 'UNRESOLVED'::text);

-- public.v_flow_operation_detail
CREATE OR REPLACE VIEW public.v_flow_operation_detail AS
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
    m.operation_count,
    m.completed_operation_count,
    m.routing_progress_percent,
    m.open_exception_count,
    m.last_source_observed_at,
    m.validation_status,
    o.customer_name,
    o.ship_to_name,
    o.date_due,
    COALESCE((o.date_due)::date, m.planned_date) AS due_date,
    GREATEST(0, (CURRENT_DATE - COALESCE((o.date_due)::date, m.planned_date, CURRENT_DATE))) AS age_days,
    o.source_priority,
    COALESCE(( SELECT jsonb_agg(jsonb_build_object('sku', p.sku, 'description', p.description, 'planned_quantity', l.planned_quantity, 'actual_quantity', l.actual_quantity) ORDER BY l.sequence) AS jsonb_agg
           FROM (manufacturing_order_lines l
             LEFT JOIN products p ON ((p.id = l.product_id)))
          WHERE (l.manufacturing_order_id = m.manufacturing_order_id)), '[]'::jsonb) AS product_mix
   FROM (v_manufacturing_order_routing_status m
     LEFT JOIN v_current_orders o ON (((o.organization_id = m.organization_id) AND (o.order_no = m.source_order_no))));

-- public.v_flow_operation_summary
CREATE OR REPLACE VIEW public.v_flow_operation_summary AS
 SELECT organization_id,
    routing_code_snapshot,
    current_operation_code,
    sum(remaining_quantity) AS units,
    count(*) AS mo_count,
    count(DISTINCT source_order_no) AS so_count,
    round(avg(age_days), 1) AS average_age,
    max(age_days) AS oldest_age,
    count(*) FILTER (WHERE ((COALESCE(planner_priority, source_priority, 999) <= 10) OR (age_days > 4))) AS critical_priority_count
   FROM v_flow_operation_detail
  WHERE ((production_status <> ALL (ARRAY['COMPLETED'::text, 'CANCELLED'::text])) AND (current_operation_code IS NOT NULL))
  GROUP BY organization_id, routing_code_snapshot, current_operation_code;

-- public.v_kpi_dashboard
CREATE OR REPLACE VIEW public.v_kpi_dashboard AS
 SELECT d.id AS definition_id,
    d.organization_id,
    d.code,
    d.name,
    d.category,
    d.unit,
    d.data_readiness_status,
    d.dashboard_priority,
    r.value,
    r.numerator,
    r.denominator,
    r.status,
    r.data_quality_status,
    r.production_area_id,
    a.code AS area_code,
    r.source_refresh_at,
    r.calculated_at
   FROM ((kpi_definitions d
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.kpi_definition_id,
            x.period_start,
            x.period_end,
            x.production_date,
            x.production_area_id,
            x.shift_id,
            x.machine_id,
            x.operator_id,
            x.order_no,
            x.product_code,
            x.numerator,
            x.denominator,
            x.value,
            x.target_value,
            x.status,
            x.data_quality_status,
            x.source_refresh_at,
            x.calculated_at
           FROM kpi_results x
          WHERE (x.kpi_definition_id = d.id)
          ORDER BY x.calculated_at DESC
         LIMIT 1) r ON (true))
     LEFT JOIN production_areas a ON ((a.id = r.production_area_id)));

-- public.v_kpi_trends
CREATE OR REPLACE VIEW public.v_kpi_trends AS
 WITH daily_base AS (
         SELECT DISTINCT ON (r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid)) r.organization_id,
            r.kpi_definition_id,
            r.production_area_id,
            r.production_date,
            r.value
           FROM kpi_results r
          WHERE (r.value IS NOT NULL)
          ORDER BY r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid), r.calculated_at DESC
        ), periods AS (
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'DAILY'::text AS period_type,
            daily_base.production_date AS period_start,
            daily_base.production_date AS period_end,
            (1)::bigint AS points,
            daily_base.value AS latest_value,
            daily_base.value AS average_value,
            daily_base.value AS minimum_value,
            daily_base.value AS maximum_value
           FROM daily_base
        UNION ALL
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'WEEKLY'::text,
            (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,
            ((date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone) + '6 days'::interval))::date AS date,
            count(*) AS count,
            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,
            avg(daily_base.value) AS avg,
            min(daily_base.value) AS min,
            max(daily_base.value) AS max
           FROM daily_base
          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))
        UNION ALL
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'MONTHLY'::text,
            (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,
            ((date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone) + '1 mon -1 days'::interval))::date AS date,
            count(*) AS count,
            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,
            avg(daily_base.value) AS avg,
            min(daily_base.value) AS min,
            max(daily_base.value) AS max
           FROM daily_base
          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))
        ), compared AS (
         SELECT p.organization_id,
            p.kpi_definition_id,
            p.production_area_id,
            p.period_type,
            p.period_start,
            p.period_end,
            p.points,
            p.latest_value,
            p.average_value,
            p.minimum_value,
            p.maximum_value,
            lag(p.latest_value) OVER (PARTITION BY p.organization_id, p.kpi_definition_id, p.production_area_id, p.period_type ORDER BY p.period_start) AS previous_value
           FROM periods p
        )
 SELECT organization_id,
    kpi_definition_id,
    production_area_id,
    period_type,
    period_start,
    period_end,
    points,
    latest_value,
    average_value,
    minimum_value,
    maximum_value,
    previous_value,
    (latest_value - previous_value) AS absolute_change,
        CASE
            WHEN (previous_value = (0)::numeric) THEN NULL::numeric
            ELSE round((((latest_value - previous_value) / abs(previous_value)) * (100)::numeric), 2)
        END AS percentage_change
   FROM compared c;

-- public.v_latest_completed_batch
CREATE OR REPLACE VIEW public.v_latest_completed_batch AS
 SELECT DISTINCT ON (organization_id) id,
    organization_id,
    started_at,
    completed_at,
    status,
    orders_count,
    workbank_count,
    stock_count,
    audit_new_count,
    error_message,
    connector_version,
    created_at
   FROM sync_batches
  WHERE (status = 'completed'::text)
  ORDER BY organization_id, completed_at DESC;

-- public.v_latest_production_reconciliation
CREATE OR REPLACE VIEW public.v_latest_production_reconciliation AS
 SELECT DISTINCT ON (organization_id) id,
    organization_id,
    sync_batch_id,
    status,
    quantity_tolerance,
    total_orders,
    matched_orders,
    mismatched_orders,
    missing_canonical_orders,
    missing_legacy_orders,
    comparable_quantity_orders,
    quantity_matched_orders,
    match_rate,
    started_at,
    completed_at,
    error_message,
    created_at
   FROM production_reconciliation_runs
  WHERE (status = 'COMPLETED'::text)
  ORDER BY organization_id, completed_at DESC;

-- public.v_latest_production_reconciliation_items
CREATE OR REPLACE VIEW public.v_latest_production_reconciliation_items AS
 SELECT i.id,
    i.organization_id,
    i.reconciliation_run_id,
    i.order_no,
    i.legacy_area,
    i.expected_operation_code,
    i.canonical_operation_code,
    i.legacy_remaining_quantity,
    i.canonical_remaining_quantity,
    i.quantity_variance,
    i.presence_result,
    i.operation_result,
    i.quantity_result,
    i.overall_result,
    i.detail,
    i.created_at
   FROM (production_reconciliation_items i
     JOIN v_latest_production_reconciliation r ON ((r.id = i.reconciliation_run_id)));

-- public.v_manufacturing_order_current_operation
CREATE OR REPLACE VIEW public.v_manufacturing_order_current_operation AS
 SELECT e.organization_id,
    e.production_order_id AS manufacturing_order_id,
    po.mo_number,
    COALESCE(e.source_order_no, e.order_no) AS source_order_no,
    po.routing_code_snapshot,
    po.routing_revision_snapshot,
    e.production_status,
    e.planned_quantity,
    e.actual_quantity,
    GREATEST((COALESCE(e.planned_quantity, (0)::numeric) - COALESCE(e.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    e.planned_date,
    e.planner_priority,
    e.current_operation_id,
    e.current_operation_code,
    e.current_operation_name,
    e.next_operation_id,
    e.next_operation_code,
    e.next_operation_name,
    e.last_completed_operation_id,
    e.last_completed_operation_code
   FROM (v_production_order_execution e
     JOIN production_orders po ON ((po.id = e.production_order_id)))
  WHERE (po.source_routing_id IS NOT NULL);

-- public.v_manufacturing_order_product_mix
CREATE OR REPLACE VIEW public.v_manufacturing_order_product_mix AS
 SELECT po.organization_id,
    po.id AS manufacturing_order_id,
    po.mo_number,
    po.source_order_no,
    po.routing_code_snapshot,
    l.product_id,
    p.sku,
    p.description,
    (sum(l.planned_quantity))::numeric(14,3) AS planned_quantity,
    round(((sum(l.planned_quantity) / NULLIF(po.planned_quantity, (0)::numeric)) * (100)::numeric), 1) AS mix_percent
   FROM ((production_orders po
     JOIN manufacturing_order_lines l ON ((l.manufacturing_order_id = po.id)))
     LEFT JOIN products p ON (((p.id = l.product_id) AND (p.organization_id = l.organization_id))))
  GROUP BY po.organization_id, po.id, po.mo_number, po.source_order_no, po.routing_code_snapshot, l.product_id, p.sku, p.description, po.planned_quantity;

-- public.v_manufacturing_order_progress
CREATE OR REPLACE VIEW public.v_manufacturing_order_progress AS
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
  GROUP BY m.organization_id, m.manufacturing_order_id, m.mo_number, m.source_order_no, m.routing_code_snapshot, m.routing_revision_snapshot, m.production_status, m.planned_quantity, m.actual_quantity, m.remaining_quantity, m.planned_date, m.planner_priority, m.current_operation_id, m.current_operation_code, m.current_operation_name, m.next_operation_id, m.next_operation_code, m.next_operation_name, m.last_completed_operation_id, m.last_completed_operation_code;

-- public.v_manufacturing_order_routing_status
CREATE OR REPLACE VIEW public.v_manufacturing_order_routing_status AS
 SELECT p.organization_id,
    p.manufacturing_order_id,
    p.mo_number,
    p.source_order_no,
    p.routing_code_snapshot,
    p.routing_revision_snapshot,
    p.production_status,
    p.planned_quantity,
    p.actual_quantity,
    p.remaining_quantity,
    p.planned_date,
    p.planner_priority,
    p.current_operation_id,
    p.current_operation_code,
    p.current_operation_name,
    p.next_operation_id,
    p.next_operation_code,
    p.next_operation_name,
    p.last_completed_operation_id,
    p.last_completed_operation_code,
    p.operation_count,
    p.completed_operation_count,
    p.routing_progress_percent,
    COALESCE(s.open_exception_count, (0)::bigint) AS open_exception_count,
    s.last_source_observed_at,
        CASE
            WHEN (COALESCE(s.open_exception_count, (0)::bigint) > 0) THEN 'DEVIATION'::text
            WHEN (s.evidence_count > 0) THEN 'VALIDATED'::text
            ELSE 'AWAITING_EVIDENCE'::text
        END AS validation_status
   FROM (v_manufacturing_order_progress p
     LEFT JOIN v_production_order_routing_status s ON ((s.production_order_id = p.manufacturing_order_id)));

-- public.v_mo_backfill_pilot_reconciliation
CREATE OR REPLACE VIEW public.v_mo_backfill_pilot_reconciliation AS
 WITH expected AS (
         SELECT d.organization_id,
            d.source_order_no,
            count(DISTINCT d.routing_revision_id) AS expected_mos,
            string_agg(DISTINCT r.code, ', '::text ORDER BY r.code) AS expected_routings,
            (sum(d.quantity))::numeric(14,3) AS expected_qty
           FROM (production_demand_lines d
             JOIN routings r ON ((r.id = d.routing_revision_id)))
          WHERE (d.source_order_line_id ~~ 'E51:%'::text)
          GROUP BY d.organization_id, d.source_order_no
        ), actual AS (
         SELECT po.organization_id,
            po.source_order_no,
            count(*) AS actual_mos,
            (sum(po.planned_quantity))::numeric(14,3) AS actual_qty,
            string_agg(DISTINCT po.routing_code_snapshot, ', '::text ORDER BY po.routing_code_snapshot) AS actual_routings
           FROM production_orders po
          WHERE (po.source_routing_id IS NOT NULL)
          GROUP BY po.organization_id, po.source_order_no
        )
 SELECT p.organization_id,
    p.source_order_no,
    p.selection_reason,
    e.expected_routings,
    e.expected_mos,
    COALESCE(a.actual_mos, (0)::bigint) AS actual_mos,
    e.expected_qty,
    (COALESCE(a.actual_qty, (0)::numeric))::numeric(14,3) AS actual_qty,
        CASE
            WHEN ((e.expected_mos = COALESCE(a.actual_mos, (0)::bigint)) AND (e.expected_qty = COALESCE(a.actual_qty, (0)::numeric)) AND (e.expected_routings = a.actual_routings)) THEN 'PASS'::text
            ELSE 'FAIL'::text
        END AS result
   FROM ((mo_backfill_pilot_orders p
     LEFT JOIN expected e USING (organization_id, source_order_no))
     LEFT JOIN actual a USING (organization_id, source_order_no));

-- public.v_mo_grouping_reconciliation
CREATE OR REPLACE VIEW public.v_mo_grouping_reconciliation AS
 WITH expected AS (
         SELECT x.organization_id,
            x.source_system,
            x.source_order_no,
            count(*) AS source_line_count,
            count(DISTINCT x.routing_revision_id) FILTER (WHERE (x.resolution_status = 'RESOLVED'::text)) AS expected_mo_count,
            jsonb_object_agg(COALESCE(r.code, x.resolution_status), x.quantity_by_route) AS expected_quantity_by_routing
           FROM (( SELECT d.organization_id,
                    d.source_system,
                    d.source_order_no,
                    d.routing_revision_id,
                    d.resolution_status,
                    sum(d.quantity) AS quantity_by_route
                   FROM production_demand_lines d
                  GROUP BY d.organization_id, d.source_system, d.source_order_no, d.routing_revision_id, d.resolution_status) x
             LEFT JOIN routings r ON ((r.id = x.routing_revision_id)))
          GROUP BY x.organization_id, x.source_system, x.source_order_no
        ), actual AS (
         SELECT production_orders.organization_id,
            production_orders.source_system,
            production_orders.source_order_no,
            count(*) AS actual_mo_count,
            sum(production_orders.planned_quantity) AS actual_quantity
           FROM production_orders
          WHERE (production_orders.source_routing_id IS NOT NULL)
          GROUP BY production_orders.organization_id, production_orders.source_system, production_orders.source_order_no
        )
 SELECT e.organization_id,
    e.source_system,
    e.source_order_no,
    e.source_line_count,
    e.expected_mo_count,
    e.expected_quantity_by_routing,
    COALESCE(a.actual_mo_count, (0)::bigint) AS actual_mo_count,
    (e.expected_mo_count - COALESCE(a.actual_mo_count, (0)::bigint)) AS mo_difference,
    COALESCE(a.actual_quantity, (0)::numeric) AS actual_quantity
   FROM (expected e
     LEFT JOIN actual a USING (organization_id, source_system, source_order_no));

-- public.v_oracle_line_ingestion_status
CREATE OR REPLACE VIEW public.v_oracle_line_ingestion_status AS
 SELECT id,
    organization_id,
    sync_batch_id,
    agent_id,
    batch_size,
    status,
    snapshot_status,
    last_order_no,
    last_line_number,
    batches_completed,
    rows_processed,
    started_at,
    updated_at,
    completed_at,
    error,
    COALESCE(( SELECT sum(b.inserted_count) AS sum
           FROM oracle_line_ingestion_batches b
          WHERE (b.ingestion_run_id = r.id)), (0)::bigint) AS inserted_count,
    COALESCE(( SELECT sum(b.updated_count) AS sum
           FROM oracle_line_ingestion_batches b
          WHERE (b.ingestion_run_id = r.id)), (0)::bigint) AS updated_count,
    COALESCE(( SELECT sum(b.unchanged_count) AS sum
           FROM oracle_line_ingestion_batches b
          WHERE (b.ingestion_run_id = r.id)), (0)::bigint) AS unchanged_count,
    ( SELECT count(*) AS count
           FROM oracle_line_ingestion_staging s
          WHERE ((s.ingestion_run_id = r.id) AND (s.raw_release_value <> ALL (ARRAY['Y'::text, 'N'::text])))) AS unknown_released_values
   FROM oracle_line_ingestion_runs r;

-- public.v_order_stage_summary
CREATE OR REPLACE VIEW public.v_order_stage_summary AS
 WITH classified AS (
         SELECT w.id,
            w.organization_id,
            w.sync_batch_id,
            w.source_row_id,
            w.order_no,
            w.customer_code,
            w.customer_name,
            w.source_due_at,
            w.from_location,
            w.from_zone,
            w.to_location,
            w.from_pack_id,
            w.to_pack_id,
            w.source_priority,
            w.product_code,
            w.product_description,
            w.product_group,
            w.source_qty,
            w.source_weight,
            w.production_units,
            w.queue,
            w.task,
            w.created_at,
            COALESCE(mapped.code, 'UNMAPPED'::text) AS stage_code,
            COALESCE(mapped.name, 'Unmapped'::text) AS stage_name,
            (w.production_units * COALESCE(rule.multiplier, (1)::numeric)) AS converted_units
           FROM ((v_current_workbank w
             LEFT JOIN LATERAL ( SELECT a.code,
                    a.name
                   FROM (production_stage_mappings m
                     JOIN production_areas a ON ((a.id = m.production_area_id)))
                  WHERE ((m.organization_id = w.organization_id) AND m.active AND a.active AND
                        CASE m.source_field
                            WHEN 'from_zone'::text THEN (COALESCE(w.from_zone, ''::text) ~~* m.match_pattern)
                            WHEN 'from_location'::text THEN (COALESCE(w.from_location, ''::text) ~~* m.match_pattern)
                            ELSE NULL::boolean
                        END)
                  ORDER BY m.priority
                 LIMIT 1) mapped ON (true))
             LEFT JOIN LATERAL ( SELECT r.multiplier
                   FROM quantity_conversion_rules r
                  WHERE ((r.organization_id = w.organization_id) AND r.active AND (COALESCE(w.product_group, ''::text) ~~* r.product_group_pattern))
                  ORDER BY r.priority
                 LIMIT 1) rule ON (true))
        )
 SELECT organization_id,
    order_no,
    max(customer_name) AS customer_name,
    min(source_due_at) AS due_at,
    stage_code,
    max(stage_name) AS stage_name,
    count(*) AS item_count,
    sum(converted_units) AS production_units,
    GREATEST(0, (CURRENT_DATE - COALESCE((min(source_due_at))::date, CURRENT_DATE))) AS age_days
   FROM classified
  GROUP BY organization_id, order_no, stage_code;

-- public.v_product_mix_classification
CREATE OR REPLACE VIEW public.v_product_mix_classification AS
 SELECT p.organization_id,
    p.id AS product_id,
    p.sku,
    p.description,
    COALESCE(f.code, 'UNMAPPED'::text) AS product_family_code,
    COALESCE(t.code, 'UNMAPPED'::text) AS product_type_code,
    p.decoration_method,
    p.active
   FROM ((products p
     LEFT JOIN product_families f ON (((f.id = p.product_family_id) AND (f.organization_id = p.organization_id))))
     LEFT JOIN product_types t ON (((t.id = p.product_type_id) AND (t.organization_id = p.organization_id))));

-- public.v_product_routing_mapping_gaps
CREATE OR REPLACE VIEW public.v_product_routing_mapping_gaps AS
 SELECT organization_id,
    source_product_code,
    max(source_description) AS source_description,
    resolution_status,
    count(DISTINCT source_order_no) AS order_count,
    count(*) AS source_line_count,
    (sum(quantity))::numeric(14,3) AS units
   FROM production_demand_lines d
  WHERE (resolution_status = ANY (ARRAY['PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'ROUTING_INACTIVE'::text]))
  GROUP BY organization_id, source_product_code, resolution_status;

-- public.v_production_flow_canonical
CREATE OR REPLACE VIEW public.v_production_flow_canonical AS
 WITH classified AS (
         SELECT p.organization_id,
            p.production_order_id,
            p.order_no,
            p.source_order_no,
            p.routing_code_snapshot,
            p.production_status,
            p.planned_quantity,
            p.actual_quantity,
            p.current_operation_id,
            p.current_operation_sequence,
            p.current_operation_code,
            p.current_operation_name,
            p.next_operation_id,
            p.next_operation_code,
            p.next_operation_name,
            p.last_completed_operation_id,
            p.last_completed_operation_code,
            p.last_completed_operation_name,
            p.remaining_quantity,
            p.operation_count,
            p.completed_operation_count,
            p.evidence_count,
            p.open_exception_count,
            p.last_source_observed_at,
                CASE
                    WHEN (p.routing_code_snapshot ~~* 'DTG%'::text) THEN 'DTG'::text
                    WHEN ((p.routing_code_snapshot ~~* 'UNDERPRINT%'::text) OR (p.routing_code_snapshot ~~* 'UP%'::text)) THEN 'UNDERPRINT'::text
                    WHEN (p.routing_code_snapshot ~~* 'SCREEN%'::text) THEN 'SCREEN_PRINT'::text
                    ELSE NULL::text
                END AS process_code
           FROM v_production_order_progress p
        ), normalized AS (
         SELECT classified.organization_id,
            classified.production_order_id,
            classified.order_no,
            classified.source_order_no,
            classified.routing_code_snapshot,
            classified.production_status,
            classified.planned_quantity,
            classified.actual_quantity,
            classified.current_operation_id,
            classified.current_operation_sequence,
            classified.current_operation_code,
            classified.current_operation_name,
            classified.next_operation_id,
            classified.next_operation_code,
            classified.next_operation_name,
            classified.last_completed_operation_id,
            classified.last_completed_operation_code,
            classified.last_completed_operation_name,
            classified.remaining_quantity,
            classified.operation_count,
            classified.completed_operation_count,
            classified.evidence_count,
            classified.open_exception_count,
            classified.last_source_observed_at,
            classified.process_code,
                CASE
                    WHEN ((classified.process_code = 'DTG'::text) AND (classified.current_operation_code = 'PICKING'::text)) THEN 'DTG_PICKING'::text
                    WHEN ((classified.process_code = 'DTG'::text) AND (classified.current_operation_code = ANY (ARRAY['DTG_PRINT'::text, 'DTG_PRINTING'::text]))) THEN 'DTG_PRINTING'::text
                    WHEN ((classified.process_code = 'DTG'::text) AND (classified.current_operation_code = 'PUTWALL'::text)) THEN 'DTG_PUTWALL'::text
                    WHEN ((classified.process_code = 'DTG'::text) AND (classified.current_operation_code = 'DISPATCH'::text)) THEN 'DTG_DISPATCH'::text
                    WHEN ((classified.process_code = 'UNDERPRINT'::text) AND (classified.current_operation_code = 'PICKING'::text)) THEN 'UP_PICKING'::text
                    WHEN ((classified.process_code = 'UNDERPRINT'::text) AND (classified.current_operation_code = 'UNDERPRINT'::text)) THEN 'UP_PRINTING'::text
                    WHEN ((classified.process_code = 'UNDERPRINT'::text) AND (classified.current_operation_code = 'DISPATCH'::text)) THEN 'UP_DISPATCH'::text
                    WHEN (classified.process_code = 'SCREEN_PRINT'::text) THEN classified.current_operation_code
                    ELSE NULL::text
                END AS stage_code
           FROM classified
        )
 SELECT organization_id,
    process_code,
    stage_code,
    (count(DISTINCT production_order_id))::integer AS orders,
    (sum(remaining_quantity))::numeric(14,3) AS units,
    (count(*) FILTER (WHERE (open_exception_count > 0)))::integer AS orders_with_deviations,
    (count(*) FILTER (WHERE (evidence_count = 0)))::integer AS orders_without_evidence
   FROM normalized
  WHERE ((process_code IS NOT NULL) AND (stage_code IS NOT NULL))
  GROUP BY organization_id, process_code, stage_code;

-- public.v_production_flow_legacy_snapshot
CREATE OR REPLACE VIEW public.v_production_flow_legacy_snapshot AS
 WITH stages AS (
         SELECT v_current_workbank.organization_id,
            'DTG_PICKING'::text AS stage_code,
            v_current_workbank.order_no,
            v_current_workbank.production_units
           FROM v_current_workbank
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'SP11'::text)
        UNION ALL
         SELECT v_current_workbank.organization_id,
            'DTG_PRINTING'::text,
            v_current_workbank.order_no,
            v_current_workbank.production_units
           FROM v_current_workbank
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'PCOR'::text)
        UNION ALL
         SELECT v_current_workbank.organization_id,
            'DTG_PUTWALL'::text,
            v_current_workbank.order_no,
            v_current_workbank.production_units
           FROM v_current_workbank
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text)
        UNION ALL
         SELECT source_audit_events.organization_id,
            'DTG_DISPATCH'::text,
            source_audit_events.order_no,
            source_audit_events.production_units
           FROM source_audit_events
          WHERE ((upper(TRIM(BOTH FROM COALESCE(source_audit_events.to_location, ''::text))) = 'DTGMOVE'::text) AND (((source_audit_events.event_at AT TIME ZONE 'Australia/Brisbane'::text))::date = ((now() AT TIME ZONE 'Australia/Brisbane'::text))::date))
        UNION ALL
         SELECT v_current_stock.organization_id,
            'UP_PICKING'::text,
            v_current_stock.product,
            v_current_stock.production_units
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
        UNION ALL
         SELECT v_current_workbank.organization_id,
            'UP_PRINTING'::text,
            v_current_workbank.order_no,
            v_current_workbank.production_units
           FROM v_current_workbank
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_location, ''::text))) ~~ '%UP'::text)
        UNION ALL
         SELECT source_audit_events.organization_id,
            'UP_DISPATCH'::text,
            source_audit_events.order_no,
            source_audit_events.production_units
           FROM source_audit_events
          WHERE ((upper(TRIM(BOTH FROM COALESCE(source_audit_events.to_location, ''::text))) = 'UPMOVE'::text) AND (((source_audit_events.event_at AT TIME ZONE 'Australia/Brisbane'::text))::date = ((now() AT TIME ZONE 'Australia/Brisbane'::text))::date))
        )
 SELECT organization_id,
    stage_code,
    (count(DISTINCT order_no))::integer AS orders,
    (sum(COALESCE(production_units, (0)::numeric)))::numeric(14,3) AS units
   FROM stages
  GROUP BY organization_id, stage_code;

-- public.v_production_flow_routing_reconciliation
CREATE OR REPLACE VIEW public.v_production_flow_routing_reconciliation AS
 WITH stages(stage_code, routing_prefix, operation_code) AS (
         VALUES ('DTG_PICKING'::text,'DTG%'::text,'PICKING'::text), ('DTG_PRINTING'::text,'DTG%'::text,'DTG_PRINT'::text), ('DTG_PUTWALL'::text,'DTG%'::text,'PUTWALL'::text), ('DTG_DISPATCH'::text,'DTG%'::text,'DISPATCH'::text), ('UP_PICKING'::text,'UNDERPRINT%'::text,'PICKING'::text), ('UP_PRINTING'::text,'UNDERPRINT%'::text,'UNDERPRINT'::text), ('UP_DISPATCH'::text,'UNDERPRINT%'::text,'DISPATCH'::text)
        ), orgs AS (
         SELECT organizations.id AS organization_id
           FROM organizations
        ), r AS (
         SELECT o.organization_id,
            s.stage_code,
            COALESCE(sum(f.units), (0)::numeric) AS units,
            COALESCE(sum(f.mo_count), (0)::numeric) AS orders
           FROM ((orgs o
             CROSS JOIN stages s)
             LEFT JOIN v_flow_operation_summary f ON (((f.organization_id = o.organization_id) AND (f.routing_code_snapshot ~~* s.routing_prefix) AND (f.current_operation_code = s.operation_code))))
          GROUP BY o.organization_id, s.stage_code
        ), l AS (
         SELECT v_production_flow_legacy_snapshot.organization_id,
            v_production_flow_legacy_snapshot.stage_code,
            v_production_flow_legacy_snapshot.units,
            v_production_flow_legacy_snapshot.orders
           FROM v_production_flow_legacy_snapshot
        )
 SELECT r.organization_id,
    r.stage_code,
    COALESCE(l.units, (0)::numeric) AS legacy_units,
    r.units AS routing_units,
    (r.units - COALESCE(l.units, (0)::numeric)) AS unit_difference,
    COALESCE(l.orders, 0) AS legacy_orders,
    r.orders AS routing_orders,
    (r.orders - (COALESCE(l.orders, 0))::numeric) AS order_difference,
        CASE
            WHEN ((r.units = COALESCE(l.units, (0)::numeric)) AND (r.orders = (COALESCE(l.orders, 0))::numeric)) THEN 'MATCH'::text
            WHEN ((r.orders = (0)::numeric) AND (COALESCE(l.orders, 0) > 0)) THEN 'MISSING_MO'::text
            WHEN (r.units > COALESCE(l.units, (0)::numeric)) THEN 'DOUBLE_COUNT'::text
            ELSE 'UNKNOWN'::text
        END AS difference_category
   FROM (r
     LEFT JOIN l USING (organization_id, stage_code));

-- public.v_production_order_current_operation
CREATE OR REPLACE VIEW public.v_production_order_current_operation AS
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
   FROM v_production_order_execution e;

-- public.v_production_order_execution
CREATE OR REPLACE VIEW public.v_production_order_execution AS
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
         LIMIT 1) last_op ON (true));

-- public.v_production_order_progress
CREATE OR REPLACE VIEW public.v_production_order_progress AS
 SELECT c.organization_id,
    c.production_order_id,
    c.order_no,
    c.source_order_no,
    c.routing_code_snapshot,
    c.production_status,
    c.planned_quantity,
    c.actual_quantity,
    c.current_operation_id,
    c.current_operation_sequence,
    c.current_operation_code,
    c.current_operation_name,
    c.next_operation_id,
    c.next_operation_code,
    c.next_operation_name,
    c.last_completed_operation_id,
    c.last_completed_operation_code,
    c.last_completed_operation_name,
    GREATEST((COALESCE(c.planned_quantity, (0)::numeric) - COALESCE(c.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    s.operation_count,
    s.completed_operation_count,
    s.evidence_count,
    s.open_exception_count,
    s.last_source_observed_at
   FROM (v_production_order_current_operation c
     JOIN v_production_order_routing_status s USING (organization_id, production_order_id));

-- public.v_production_order_routing_status
CREATE OR REPLACE VIEW public.v_production_order_routing_status AS
 SELECT po.organization_id,
    po.id AS production_order_id,
    po.order_no,
    po.source_order_no,
    po.production_status,
    count(poo.id) AS operation_count,
    count(poo.id) FILTER (WHERE (poo.status = 'COMPLETED'::text)) AS completed_operation_count,
    count(e.id) AS evidence_count,
    count(ex.id) FILTER (WHERE (ex.status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text]))) AS open_exception_count,
    max(e.observed_at) AS last_source_observed_at
   FROM (((production_orders po
     LEFT JOIN production_order_operations poo ON ((poo.production_order_id = po.id)))
     LEFT JOIN production_order_operation_evidence e ON ((e.production_order_id = po.id)))
     LEFT JOIN production_routing_exceptions ex ON ((ex.production_order_id = po.id)))
  GROUP BY po.organization_id, po.id, po.order_no, po.source_order_no, po.production_status;

-- public.v_production_planning
CREATE OR REPLACE VIEW public.v_production_planning AS
 WITH queues AS (
         SELECT v_up_operational_orders.organization_id,
            v_up_operational_orders.order_no,
            'UP'::text AS line,
            v_up_operational_orders.customer_name,
            v_up_operational_orders.screen,
            v_up_operational_orders.status AS source_status,
            v_up_operational_orders.priority AS source_priority,
            v_up_operational_orders.age_days,
            v_up_operational_orders.remaining_units,
            v_up_operational_orders.total_prints
           FROM v_up_operational_orders
        UNION ALL
         SELECT v_dtg_operational_orders.organization_id,
            v_dtg_operational_orders.order_no,
            'DTG'::text,
            v_dtg_operational_orders.customer_name,
            v_dtg_operational_orders.screen,
            v_dtg_operational_orders.status,
            v_dtg_operational_orders.priority,
            v_dtg_operational_orders.age_days,
            v_dtg_operational_orders.remaining_units,
            v_dtg_operational_orders.total_prints
           FROM v_dtg_operational_orders
        )
 SELECT q.organization_id,
    q.order_no,
    q.line,
    q.customer_name,
    q.screen,
    q.source_status,
    q.source_priority,
    q.age_days,
    q.remaining_units,
    q.total_prints,
    p.id AS production_order_id,
    p.planner_priority,
    COALESCE(p.planner_priority, q.source_priority) AS effective_priority,
    p.planned_date,
    p.planned_shift_id,
    s.name AS planned_shift,
    p.planning_status,
    p.special_instruction,
    p.planner_note,
    p.blocked_reason,
    p.updated_at
   FROM ((queues q
     LEFT JOIN production_orders p ON (((p.organization_id = q.organization_id) AND (p.order_no = q.order_no) AND (p.source_routing_id IS NULL))))
     LEFT JOIN shift_templates s ON ((s.id = p.planned_shift_id)));

-- public.v_production_reconciliation_gate
CREATE OR REPLACE VIEW public.v_production_reconciliation_gate AS
 SELECT id,
    organization_id,
    sync_batch_id,
    status,
    quantity_tolerance,
    total_orders,
    matched_orders,
    mismatched_orders,
    missing_canonical_orders,
    missing_legacy_orders,
    comparable_quantity_orders,
    quantity_matched_orders,
    match_rate,
    started_at,
    completed_at,
    error_message,
    created_at,
        CASE
            WHEN (total_orders = 0) THEN 'NO_DATA'::text
            WHEN (missing_canonical_orders > 0) THEN 'BLOCKED_MISSING_CANONICAL'::text
            WHEN (match_rate >= (98)::numeric) THEN 'READY_FOR_UI_PILOT'::text
            WHEN (match_rate >= (90)::numeric) THEN 'REVIEW_REQUIRED'::text
            ELSE 'NOT_READY'::text
        END AS migration_gate
   FROM v_latest_production_reconciliation r;

-- public.v_release_blockers
CREATE OR REPLACE VIEW public.v_release_blockers AS
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
  WHERE (v_sales_order_release_state.release_status = ANY (ARRAY['SOURCE_DATA_INVALID'::text, 'UNKNOWN_RELEASE_STATUS'::text]));

-- public.v_release_queue
CREATE OR REPLACE VIEW public.v_release_queue AS
 WITH c AS (
         SELECT l.organization_id,
            l.source_order_no,
            array_agg(DISTINCT l.task_process_code) FILTER (WHERE (l.task_process_code IS NOT NULL)) AS detected_processes,
            array_agg(DISTINCT r.code) FILTER (WHERE (r.code IS NOT NULL)) AS resolved_routings,
            round((((count(*) FILTER (WHERE (l.resolved_routing_id IS NOT NULL)))::numeric / (NULLIF(count(*), 0))::numeric) * (100)::numeric), 1) AS routing_coverage_percent
           FROM (v_active_source_product_task_context l
             LEFT JOIN routings r ON ((r.id = l.resolved_routing_id)))
          GROUP BY l.organization_id, l.source_order_no
        ), m AS (
         SELECT production_orders.organization_id,
            production_orders.source_order_no,
            count(*) AS mo_count
           FROM production_orders
          WHERE (production_orders.source_order_no IS NOT NULL)
          GROUP BY production_orders.organization_id, production_orders.source_order_no
        )
 SELECT s.organization_id,
    s.source_order_no,
    COALESCE(NULLIF(s.ship_to_name, ''::text), s.customer_name) AS customer,
    s.date_received,
    s.date_due,
    s.source_status,
    s.release_status,
    e.release_eligibility,
    e.release_blockers,
    s.production_units,
    s.product_lines,
    s.released_units,
    s.unreleased_units,
    s.released_lines,
    s.unreleased_lines,
    COALESCE(c.detected_processes, '{}'::text[]) AS detected_processes,
    COALESCE(c.resolved_routings, '{}'::text[]) AS resolved_routings,
    COALESCE(c.routing_coverage_percent, (0)::numeric) AS routing_coverage_percent,
    s.source_priority,
    s.date_released,
    b.completed_at AS last_source_sync,
    COALESCE(m.mo_count, (0)::bigint) AS mo_count,
        CASE
            WHEN (s.release_status = 'PARTIALLY_RELEASED'::text) THEN 'PARTIALLY_RELEASED'::text
            WHEN ((s.release_status = 'RELEASED'::text) AND (s.date_released >= (now() - '7 days'::interval))) THEN 'RECENTLY_RELEASED'::text
            WHEN ((e.release_eligibility = 'READY'::text) AND (s.release_status = 'UNRELEASED'::text)) THEN 'READY_FOR_RELEASE'::text
            WHEN (e.release_eligibility = 'BLOCKED'::text) THEN 'BLOCKED'::text
            ELSE 'EXCEPTIONS'::text
        END AS queue_bucket,
    s.sync_batch_id
   FROM ((((v_sales_order_release_state s
     JOIN v_sales_order_release_eligibility e USING (organization_id, source_order_no))
     LEFT JOIN c USING (organization_id, source_order_no))
     LEFT JOIN m USING (organization_id, source_order_no))
     LEFT JOIN sync_batches b ON ((b.id = s.sync_batch_id)));

-- public.v_release_reactivation_candidates
CREATE OR REPLACE VIEW public.v_release_reactivation_candidates AS
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
   FROM candidates c;

-- public.v_release_revocation_candidates
CREATE OR REPLACE VIEW public.v_release_revocation_candidates AS
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
  WHERE ((s.released = false) AND (s.raw_release_value = 'N'::text));

-- public.v_release_revocation_mo_dry_run
CREATE OR REPLACE VIEW public.v_release_revocation_mo_dry_run AS
 WITH revoked AS (
         SELECT v_release_revocation_candidates.organization_id,
            v_release_revocation_candidates.manufacturing_order_id,
            min(v_release_revocation_candidates.mo_number) AS mo_number,
            min(v_release_revocation_candidates.mo_status) AS mo_status,
            (sum(v_release_revocation_candidates.mapped_quantity))::numeric(14,3) AS revoked_qty,
            (count(*))::integer AS lines_removed
           FROM v_release_revocation_candidates
          WHERE ((v_release_revocation_candidates.demand_status <> 'CANCELLED'::text) AND v_release_revocation_candidates.valid_at_creation AND (v_release_revocation_candidates.recommended_action = 'WITHDRAWN_FROM_PLANNED_DEMAND'::text))
          GROUP BY v_release_revocation_candidates.organization_id, v_release_revocation_candidates.manufacturing_order_id
        ), remaining AS (
         SELECT ml.manufacturing_order_id,
            (COALESCE(sum(ml.planned_quantity) FILTER (WHERE ((d.status <> 'CANCELLED'::text) AND (r_1.production_demand_line_id IS NULL))), (0)::numeric))::numeric(14,3) AS released_qty_remaining
           FROM (((manufacturing_order_lines ml
             JOIN production_demand_lines d ON ((d.id = ml.production_demand_line_id)))
             JOIN revoked x ON ((x.manufacturing_order_id = ml.manufacturing_order_id)))
             LEFT JOIN v_release_revocation_candidates r_1 ON (((r_1.production_demand_line_id = d.id) AND r_1.valid_at_creation AND (r_1.recommended_action = 'WITHDRAWN_FROM_PLANNED_DEMAND'::text))))
          GROUP BY ml.manufacturing_order_id
        )
 SELECT r.organization_id,
    r.manufacturing_order_id,
    r.mo_number,
    r.mo_status,
    p.planned_quantity AS current_qty,
    m.released_qty_remaining,
    r.revoked_qty,
    r.lines_removed,
    m.released_qty_remaining AS new_qty
   FROM ((revoked r
     JOIN remaining m USING (manufacturing_order_id))
     JOIN production_orders p ON ((p.id = r.manufacturing_order_id)));

-- public.v_released_demand_resolution
CREATE OR REPLACE VIEW public.v_released_demand_resolution AS
 WITH process_context AS (
         SELECT v_source_task_resolution.organization_id,
            v_source_task_resolution.order_no,
            count(DISTINCT v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_count,
            min(v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_code,
            string_agg(DISTINCT v_source_task_resolution.source_task, ', '::text ORDER BY v_source_task_resolution.source_task) AS source_tasks
           FROM v_source_task_resolution
          WHERE (v_source_task_resolution.source_dataset = 'WORKBANK'::text)
          GROUP BY v_source_task_resolution.organization_id, v_source_task_resolution.order_no
        ), product_context AS (
         SELECT product_source_mappings.organization_id,
            product_source_mappings.source_product_code,
            count(DISTINCT product_source_mappings.product_id) AS product_count,
            (min((product_source_mappings.product_id)::text))::uuid AS product_id
           FROM product_source_mappings
          WHERE ((product_source_mappings.source_system = 'ORACLE_WMS'::text) AND product_source_mappings.active)
          GROUP BY product_source_mappings.organization_id, product_source_mappings.source_product_code
        )
 SELECT l.organization_id,
    l.source_order_no,
    l.source_line_id,
    l.production_units AS source_quantity,
    l.released,
    l.raw_release_value,
    o.source_route_id,
    pc.product_id,
    pctx.process_code AS resolved_process,
        CASE
            WHEN (pctx.process_count = 1) THEN 'UNIQUE_WORKBANK_TASK_PROCESS'::text
            ELSE NULL::text
        END AS process_resolution_rule,
        CASE
            WHEN (pctx.process_count = 1) THEN 'SOURCE_CONFIRMED'::text
            ELSE 'NOT_RESOLVED'::text
        END AS process_provenance,
        CASE
            WHEN ((pc.product_count = 1) AND (pctx.process_count = 1)) THEN resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid)
            ELSE NULL::uuid
        END AS resolved_routing_id,
    e.release_eligibility,
    l.sync_batch_id,
    a.ingestion_run_id,
        CASE
            WHEN ((l.released IS DISTINCT FROM true) OR (l.raw_release_value <> 'Y'::text)) THEN 'RELEASE_NOT_CONFIRMED'::text
            WHEN (e.release_eligibility <> 'READY'::text) THEN 'ELIGIBILITY_BLOCKED'::text
            WHEN (COALESCE(pc.product_count, (0)::bigint) <> 1) THEN 'PRODUCT_UNRESOLVED'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) <> 1) THEN 'PROCESS_UNRESOLVED'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'ROUTING_UNRESOLVED'::text
            ELSE 'ELIGIBLE'::text
        END AS eligibility_status,
        CASE
            WHEN (COALESCE(pc.product_count, (0)::bigint) = 0) THEN 'No active canonical Product mapping'::text
            WHEN (pc.product_count > 1) THEN 'Multiple active canonical Product mappings'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) = 0) THEN 'No mapped source Task process observed'::text
            WHEN (pctx.process_count > 1) THEN 'Multiple source Task processes observed for Sales Order'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'No approved Product + Process Routing'::text
            ELSE NULL::text
        END AS blocker,
    pctx.source_tasks
   FROM (((((v_released_production_demand l
     JOIN v_authoritative_release_lines a ON (((a.organization_id = l.organization_id) AND (a.source_order_no = l.source_order_no) AND (a.source_line_id = l.source_line_id))))
     JOIN v_sales_order_release_eligibility e ON (((e.organization_id = l.organization_id) AND (e.source_order_no = l.source_order_no))))
     LEFT JOIN v_current_orders o ON (((o.organization_id = l.organization_id) AND (o.order_no = l.source_order_no))))
     LEFT JOIN product_context pc ON (((pc.organization_id = l.organization_id) AND (pc.source_product_code = l.source_product_code))))
     LEFT JOIN process_context pctx ON (((pctx.organization_id = l.organization_id) AND (pctx.order_no = l.source_order_no))));

-- public.v_released_production_demand
CREATE OR REPLACE VIEW public.v_released_production_demand AS
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
  WHERE ((l.released = true) AND (l.raw_release_value = 'Y'::text) AND (e.release_eligibility <> 'NOT_APPLICABLE'::text));

-- public.v_routing_coverage_metrics
CREATE OR REPLACE VIEW public.v_routing_coverage_metrics AS
 WITH detail AS (
         SELECT v_routing_product_coverage.organization_id,
            v_routing_product_coverage.process_code,
            (sum(v_routing_product_coverage.active_lines))::integer AS active_source_lines,
            (sum(v_routing_product_coverage.active_units))::numeric(14,3) AS active_units,
            count(*) FILTER (WHERE (v_routing_product_coverage.current_product_id IS NOT NULL)) AS products_mapped,
            count(*) FILTER (WHERE ((v_routing_product_coverage.current_product_id IS NULL) AND (v_routing_product_coverage.source_sku IS NOT NULL))) AS products_unmapped,
            (sum(v_routing_product_coverage.active_lines) FILTER (WHERE (v_routing_product_coverage.current_routing_id IS NOT NULL)))::integer AS lines_with_routing,
            (sum(v_routing_product_coverage.active_lines) FILTER (WHERE (v_routing_product_coverage.current_routing_id IS NULL)))::integer AS lines_without_routing,
            (sum(v_routing_product_coverage.active_units) FILTER (WHERE (v_routing_product_coverage.current_routing_id IS NOT NULL)))::numeric(14,3) AS units_with_routing,
            (sum(v_routing_product_coverage.active_units) FILTER (WHERE (v_routing_product_coverage.current_routing_id IS NULL)))::numeric(14,3) AS units_without_routing,
            count(*) FILTER (WHERE (v_routing_product_coverage.reason_unmapped IS NOT NULL)) AS unresolved_products,
            count(*) FILTER (WHERE (v_routing_product_coverage.reason_unmapped = 'UNKNOWN'::text)) AS unknown_gaps
           FROM v_routing_product_coverage
          GROUP BY v_routing_product_coverage.organization_id, v_routing_product_coverage.process_code
        )
 SELECT detail.organization_id,
    detail.process_code,
    detail.active_source_lines,
    detail.active_units,
    detail.products_mapped,
    detail.products_unmapped,
    detail.lines_with_routing,
    detail.lines_without_routing,
    detail.units_with_routing,
    detail.units_without_routing,
    detail.unresolved_products,
    detail.unknown_gaps,
    round((((detail.lines_with_routing)::numeric / (NULLIF(detail.active_source_lines, 0))::numeric) * (100)::numeric), 1) AS line_coverage_percent,
    round(((detail.units_with_routing / NULLIF(detail.active_units, (0)::numeric)) * (100)::numeric), 1) AS unit_coverage_percent
   FROM detail
UNION ALL
 SELECT detail.organization_id,
    'TOTAL'::text AS process_code,
    (sum(detail.active_source_lines))::integer AS active_source_lines,
    (sum(detail.active_units))::numeric(14,3) AS active_units,
    (sum(detail.products_mapped))::bigint AS products_mapped,
    (sum(detail.products_unmapped))::bigint AS products_unmapped,
    (sum(detail.lines_with_routing))::integer AS lines_with_routing,
    (sum(detail.lines_without_routing))::integer AS lines_without_routing,
    (sum(detail.units_with_routing))::numeric(14,3) AS units_with_routing,
    (sum(detail.units_without_routing))::numeric(14,3) AS units_without_routing,
    (sum(detail.unresolved_products))::bigint AS unresolved_products,
    (sum(detail.unknown_gaps))::bigint AS unknown_gaps,
    round((((sum(detail.lines_with_routing))::numeric / (NULLIF(sum(detail.active_source_lines), 0))::numeric) * (100)::numeric), 1) AS line_coverage_percent,
    round(((sum(detail.units_with_routing) / NULLIF(sum(detail.active_units), (0)::numeric)) * (100)::numeric), 1) AS unit_coverage_percent
   FROM detail
  GROUP BY detail.organization_id;

-- public.v_routing_master
CREATE OR REPLACE VIEW public.v_routing_master AS
 SELECT r.organization_id,
    r.id AS routing_id,
    r.code,
    r.name,
    r.revision,
    r.status,
    r.effective_from,
    r.effective_to,
    r.active,
    ro.id AS routing_operation_id,
    ro.sequence,
    o.code AS operation_code,
    o.name AS operation_name,
    w.code AS work_center_code,
    ro.required,
    ro.setup_minutes,
    ro.run_rate,
    ro.queue_minutes,
    ro.instructions
   FROM (((routings r
     LEFT JOIN routing_operations ro ON (((ro.routing_id = r.id) AND (ro.organization_id = r.organization_id))))
     LEFT JOIN operations o ON (((o.id = ro.operation_id) AND (o.organization_id = r.organization_id))))
     LEFT JOIN work_centers w ON (((w.id = ro.work_center_id) AND (w.organization_id = r.organization_id))));

-- public.v_routing_product_coverage
CREATE OR REPLACE VIEW public.v_routing_product_coverage AS
 SELECT l.organization_id,
    l.process_code,
    l.source_sku,
    max(l.source_description) AS description,
    count(DISTINCT l.source_order_no) AS active_orders,
    count(*) AS active_lines,
    (sum(l.quantity))::numeric(14,3) AS active_units,
        CASE
            WHEN (max(l.source_description) ~~* ANY (ARRAY['%GIRL%'::text, '%BOY%'::text, '%KID%'::text, '%YOUTH%'::text])) THEN 'Kids T-Shirts'::text
            WHEN (max(l.source_description) ~~* ANY (ARRAY['%HOOD%'::text, '%SWEAT%'::text])) THEN 'Hoodies / Sweatshirts'::text
            WHEN (max(l.source_description) ~~* '%TOTE%'::text) THEN 'Totes'::text
            WHEN (max(l.source_description) ~~* ANY (ARRAY['%MENS T%'::text, '%WOMENS T%'::text, '% T -%'::text])) THEN 'Adult T-Shirts'::text
            WHEN (l.source_sku IS NULL) THEN 'Unmapped'::text
            ELSE 'Other'::text
        END AS suggested_product_family,
    p.id AS current_product_id,
    p.sku AS current_product,
    pf.name AS current_product_family,
    pt.name AS current_product_type,
    r.id AS current_routing_id,
    r.code AS current_routing,
        CASE
            WHEN (l.source_sku IS NULL) THEN 'SOURCE_LINE_MISSING'::text
            WHEN (p.id IS NULL) THEN 'PRODUCT_UNMAPPED'::text
            WHEN (pra.routing_id IS NULL) THEN 'ROUTING_REQUIRED'::text
            WHEN (NOT pra.approved) THEN 'ROUTING_NOT_APPROVED'::text
            ELSE NULL::text
        END AS reason_unmapped
   FROM ((((((v_active_source_product_lines l
     LEFT JOIN product_source_mappings pm ON (((pm.organization_id = l.organization_id) AND (pm.source_system = 'ORACLE_WMS'::text) AND (pm.source_product_code = l.source_sku) AND pm.active)))
     LEFT JOIN products p ON (((p.id = pm.product_id) AND (p.organization_id = l.organization_id) AND p.active)))
     LEFT JOIN product_families pf ON ((pf.id = p.product_family_id)))
     LEFT JOIN product_types pt ON ((pt.id = p.product_type_id)))
     LEFT JOIN product_routing_assignments pra ON (((pra.organization_id = l.organization_id) AND (pra.product_id = p.id) AND (pra.process_code = l.process_code))))
     LEFT JOIN routings r ON (((r.id = pra.routing_id) AND r.active AND (r.status = 'ACTIVE'::text))))
  GROUP BY l.organization_id, l.process_code, l.source_sku, p.id, p.sku, pf.name, pt.name, r.id, r.code, pra.routing_id, pra.approved;

-- public.v_sales_order_release_eligibility
CREATE OR REPLACE VIEW public.v_sales_order_release_eligibility AS
 SELECT s.organization_id,
    s.source_order_no,
        CASE
            WHEN bool_or((b.blocker = 'NO_PRODUCTION_DEMAND'::text)) THEN 'NOT_APPLICABLE'::text
            WHEN (count(b.blocker) > 0) THEN 'BLOCKED'::text
            ELSE 'READY'::text
        END AS release_eligibility,
    COALESCE(array_agg(b.blocker ORDER BY b.blocker) FILTER (WHERE (b.blocker IS NOT NULL)), '{}'::text[]) AS release_blockers
   FROM (v_sales_order_release_state s
     LEFT JOIN v_release_blockers b USING (organization_id, source_order_no))
  GROUP BY s.organization_id, s.source_order_no;

-- public.v_sales_order_release_state
CREATE OR REPLACE VIEW public.v_sales_order_release_state AS
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
     LEFT JOIN l ON (((l.organization_id = o.organization_id) AND (l.source_order_no = o.order_no))));

-- public.v_source_operation_evidence
CREATE OR REPLACE VIEW public.v_source_operation_evidence AS
 WITH source_values AS (
         SELECT a.organization_id,
            a.order_no,
            'AUDIT'::text AS source_dataset,
            COALESCE(a.source_audit_id, a.raw_hash, (a.id)::text) AS source_record_key,
            a.id AS source_audit_event_id,
            a.event_at AS observed_at,
            a.production_units AS quantity,
            v.source_field,
            v.source_value
           FROM (source_audit_events a
             CROSS JOIN LATERAL ( VALUES ('queue'::text,a.queue), ('task'::text,a.task), ('from_zone'::text,a.from_zone), ('to_zone'::text,a.to_zone), ('from_location'::text,a.from_location), ('to_location'::text,a.to_location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        UNION ALL
         SELECT w.organization_id,
            w.order_no,
            'WORKBANK'::text,
            COALESCE(w.source_row_id, (w.id)::text) AS "coalesce",
            NULL::uuid AS uuid,
            w.created_at,
            w.production_units,
            v.source_field,
            v.source_value
           FROM (v_current_workbank w
             CROSS JOIN LATERAL ( VALUES ('queue'::text,w.queue), ('task'::text,w.task), ('from_zone'::text,w.from_zone), ('from_location'::text,w.from_location), ('to_location'::text,w.to_location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        UNION ALL
         SELECT s.organization_id,
            regexp_replace(s.product, '^#'::text, ''::text) AS regexp_replace,
            'STOCK'::text,
            (s.id)::text AS id,
            NULL::uuid AS uuid,
            COALESCE(s.source_timestamp, s.created_at) AS "coalesce",
            s.production_units,
            v.source_field,
            v.source_value
           FROM (v_current_stock s
             CROSS JOIN LATERAL ( VALUES ('source_zone'::text,s.source_zone), ('location'::text,s.location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        ), ranked AS (
         SELECT sv.organization_id,
            sv.order_no,
            sv.source_dataset,
            sv.source_record_key,
            sv.source_audit_event_id,
            sv.observed_at,
            sv.quantity,
            sv.source_field,
            sv.source_value,
            m.id AS source_mapping_id,
            m.operation_id,
            m.completion_semantics,
            row_number() OVER (PARTITION BY sv.organization_id, sv.source_dataset, sv.source_record_key, sv.source_field ORDER BY m.priority, m.id) AS mapping_rank
           FROM (source_values sv
             JOIN source_operation_mappings m ON (((m.organization_id = sv.organization_id) AND m.active AND (m.source_dataset = sv.source_dataset) AND (m.source_field = sv.source_field) AND source_value_matches(sv.source_value, m.match_type, m.match_value))))
        )
 SELECT organization_id,
    order_no,
    source_dataset,
    source_record_key,
    source_audit_event_id,
    observed_at,
    quantity,
    source_field,
    source_value,
    source_mapping_id,
    operation_id,
    completion_semantics
   FROM ranked
  WHERE (mapping_rank = 1);

-- public.v_source_operational_code_observations
CREATE OR REPLACE VIEW public.v_source_operational_code_observations AS
 SELECT w.organization_id,
    w.sync_batch_id,
    w.order_no,
    w.product_code,
    w.queue AS source_operational_code,
    'queue'::text AS source_field,
    w.task,
    w.from_zone,
    w.from_location,
    w.to_location,
    w.production_units,
    m.manufacturing_process,
    m.operational_stage,
    m.release_status,
    m.eligibility_status,
    m.blocker_reason,
    m.mo_scope,
    m.confidence
   FROM (source_workbank_items w
     LEFT JOIN source_operational_code_mappings m ON (((m.organization_id = w.organization_id) AND (m.source_dataset = 'WORKBANK'::text) AND (m.source_field = 'queue'::text) AND (m.source_operational_code = upper(TRIM(BOTH FROM COALESCE(w.queue, ''::text)))) AND m.active)))
UNION ALL
 SELECT w.organization_id,
    w.sync_batch_id,
    w.order_no,
    w.product_code,
    w.to_location AS source_operational_code,
    'to_location'::text AS source_field,
    w.task,
    w.from_zone,
    w.from_location,
    w.to_location,
    w.production_units,
    m.manufacturing_process,
    m.operational_stage,
    m.release_status,
    m.eligibility_status,
    m.blocker_reason,
    m.mo_scope,
    m.confidence
   FROM (source_workbank_items w
     JOIN source_operational_code_mappings m ON (((m.organization_id = w.organization_id) AND (m.source_dataset = 'WORKBANK'::text) AND (m.source_field = 'to_location'::text) AND (m.source_operational_code = upper(TRIM(BOTH FROM COALESCE(w.to_location, ''::text)))) AND m.active)));

-- public.v_source_reconciliation
CREATE OR REPLACE VIEW public.v_source_reconciliation AS
 SELECT organization_id,
    id AS sync_batch_id,
    completed_at,
    orders_count AS batch_orders,
    ( SELECT count(*) AS count
           FROM source_orders o
          WHERE (o.sync_batch_id = b.id)) AS current_orders,
    workbank_count AS batch_workbank,
    ( SELECT count(*) AS count
           FROM source_workbank_items w
          WHERE (w.sync_batch_id = b.id)) AS current_workbank,
    stock_count AS batch_stock,
    ( SELECT count(*) AS count
           FROM source_stock_items s
          WHERE (s.sync_batch_id = b.id)) AS current_stock,
    audit_new_count
   FROM v_latest_completed_batch b;

-- public.v_source_task_mapping_coverage
CREATE OR REPLACE VIEW public.v_source_task_mapping_coverage AS
 SELECT organization_id,
    source_dataset,
    upper(TRIM(BOTH FROM source_task)) AS source_task,
    upper(TRIM(BOTH FROM COALESCE(queue, ''::text))) AS queue,
    upper(TRIM(BOTH FROM COALESCE(from_zone, ''::text))) AS from_zone,
    resolution_status,
    process_code,
    operation_code,
    count(*) AS records,
    count(DISTINCT order_no) AS orders,
    (sum(production_units))::numeric(14,3) AS units
   FROM v_source_task_resolution
  GROUP BY organization_id, source_dataset, (upper(TRIM(BOTH FROM source_task))), (upper(TRIM(BOTH FROM COALESCE(queue, ''::text)))), (upper(TRIM(BOTH FROM COALESCE(from_zone, ''::text)))), resolution_status, process_code, operation_code;

-- public.v_source_task_observations
CREATE OR REPLACE VIEW public.v_source_task_observations AS
 SELECT w.organization_id,
    'WORKBANK'::text AS source_dataset,
    w.source_row_id AS source_record_key,
    w.order_no,
    w.task AS source_task,
    w.queue,
    w.from_zone,
    NULL::text AS to_zone,
    w.from_location,
    w.to_location,
    w.production_units,
    w.created_at AS observed_at
   FROM v_current_workbank w
  WHERE (NULLIF(TRIM(BOTH FROM w.task), ''::text) IS NOT NULL)
UNION ALL
 SELECT a.organization_id,
    'AUDIT'::text AS source_dataset,
    COALESCE(a.source_audit_id, (a.id)::text) AS source_record_key,
    a.order_no,
    a.task AS source_task,
    a.queue,
    a.from_zone,
    a.to_zone,
    a.from_location,
    a.to_location,
    a.production_units,
    a.event_at AS observed_at
   FROM source_audit_events a
  WHERE (NULLIF(TRIM(BOTH FROM a.task), ''::text) IS NOT NULL);

-- public.v_source_task_resolution
CREATE OR REPLACE VIEW public.v_source_task_resolution AS
 SELECT s.organization_id,
    s.source_dataset,
    s.source_record_key,
    s.order_no,
    s.source_task,
    s.queue,
    s.from_zone,
    s.to_zone,
    s.from_location,
    s.to_location,
    s.production_units,
    s.observed_at,
    r.mapping_id,
    r.production_process_id,
    r.process_code,
    r.operation_id,
    r.operation_code,
        CASE
            WHEN (r.mapping_id IS NULL) THEN 'TASK_UNMAPPED'::text
            WHEN (r.operation_id IS NULL) THEN 'PROCESS_ONLY'::text
            ELSE 'PROCESS_AND_OPERATION'::text
        END AS resolution_status
   FROM (v_source_task_observations s
     LEFT JOIN LATERAL resolve_source_task_context(s.organization_id, s.source_dataset, s.source_task, s.queue, s.from_zone, s.to_zone, s.from_location, s.to_location) r(mapping_id, production_process_id, process_code, operation_id, operation_code) ON (true));

-- public.v_underprint_source_line_gap_analysis
CREATE OR REPLACE VIEW public.v_underprint_source_line_gap_analysis AS
 WITH up AS (
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS source_order_no,
            (sum(v_current_stock.production_units))::numeric(14,3) AS units,
            string_agg(DISTINCT v_current_stock.pack_id, ', '::text ORDER BY v_current_stock.pack_id) AS pack_ids
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
          GROUP BY v_current_stock.organization_id, (regexp_replace(v_current_stock.product, '^#'::text, ''::text))
        ), hist AS (
         SELECT source_workbank_items.organization_id,
            source_workbank_items.order_no,
            count(*) FILTER (WHERE (source_workbank_items.product_code !~ '^#?[0-9]+$'::text)) AS line_count
           FROM source_workbank_items
          GROUP BY source_workbank_items.organization_id, source_workbank_items.order_no
        ), audit AS (
         SELECT source_audit_events.organization_id,
            source_audit_events.order_no,
            count(*) AS event_count,
            count(DISTINCT source_audit_events.product) FILTER (WHERE (source_audit_events.product !~ '^#?[0-9]+$'::text)) AS product_count
           FROM source_audit_events
          GROUP BY source_audit_events.organization_id, source_audit_events.order_no
        )
 SELECT u.organization_id,
    u.source_order_no,
    COALESCE(o.ship_to_name, o.customer_name) AS customer,
    'Stock Underprint'::text AS current_source_stage,
    u.units,
    (o.order_no IS NOT NULL) AS header_available,
    COALESCE(h.line_count, (0)::bigint) AS available_source_lines,
    u.pack_ids,
    COALESCE(h.line_count, (0)::bigint) AS workbank_lines,
    COALESCE(a.event_count, (0)::bigint) AS audit_events,
    COALESCE(a.product_count, (0)::bigint) AS audit_products,
        CASE
            WHEN (COALESCE(a.product_count, (0)::bigint) > 0) THEN 'SOURCE_LINE_ALREADY_CLOSED'::text
            ELSE 'PACK_LEVEL_ONLY'::text
        END AS category,
        CASE
            WHEN (COALESCE(a.product_count, (0)::bigint) > 0) THEN 'Audit has product observations, but no complete line set or line quantities remain.'::text
            ELSE 'Only pack-level stock and Sales Order header are available.'::text
        END AS reason,
    'Obtain authoritative Oracle Sales Order line query keyed by Sales Order and validate it against pack totals.'::text AS recommendation
   FROM (((up u
     LEFT JOIN hist h ON (((h.organization_id = u.organization_id) AND (h.order_no = u.source_order_no))))
     LEFT JOIN v_current_orders o ON (((o.organization_id = u.organization_id) AND (o.order_no = u.source_order_no))))
     LEFT JOIN audit a ON (((a.organization_id = u.organization_id) AND (a.order_no = u.source_order_no))))
  WHERE (COALESCE(h.line_count, (0)::bigint) = 0);

-- public.v_up_operational_orders
CREATE OR REPLACE VIEW public.v_up_operational_orders AS
 WITH stock AS (
         SELECT s_1.organization_id,
            regexp_replace(s_1.product, '^#'::text, ''::text) AS order_no,
            count(*) AS box_count,
            sum(s_1.production_units) AS remaining_units,
            min(s_1.source_timestamp) AS last_movement
           FROM v_current_stock s_1
          WHERE (upper(COALESCE(s_1.location, ''::text)) = 'UNDERPRINT'::text)
          GROUP BY s_1.organization_id, (regexp_replace(s_1.product, '^#'::text, ''::text))
        ), putwall AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no,
            string_agg(DISTINCT COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location), ', '::text ORDER BY COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location)) AS putwall_locations
           FROM v_current_workbank
          WHERE (upper(COALESCE(v_current_workbank.from_zone, ''::text)) = 'PWL1'::text)
          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no
        )
 SELECT s.organization_id,
    s.order_no,
    o.customer_name,
    o.delivery_desc AS screen,
    o.source_status AS status,
    o.source_priority AS priority,
    o.date_due,
    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((o.date_released AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,
    s.box_count AS item_count,
    s.remaining_units,
    s.last_movement,
    p.putwall_locations,
    'At UP'::text AS progress_label,
    NULL::numeric AS total_prints,
    NULL::numeric AS adult_prints,
    NULL::numeric AS kids_prints,
    NULL::numeric AS unclassified_prints
   FROM ((stock s
     LEFT JOIN v_current_orders o ON (((o.organization_id = s.organization_id) AND (o.order_no = s.order_no))))
     LEFT JOIN putwall p ON (((p.organization_id = s.organization_id) AND (p.order_no = s.order_no))));

-- public.v_up_operator_daily_productivity
CREATE OR REPLACE VIEW public.v_up_operator_daily_productivity AS
 SELECT p.organization_id,
    p.operational_date,
    p.shift_code,
    COALESCE(NULLIF(TRIM(BOTH FROM a.username), ''::text), 'UNASSIGNED'::text) AS operator,
    sum(p.quantity) AS output,
    count(DISTINCT COALESCE(NULLIF(a.from_pack_id, ''::text), NULLIF(a.to_pack_id, ''::text), NULLIF(a.order_no, ''::text), a.source_audit_id)) AS pid,
    max((EXTRACT(epoch FROM
        CASE
            WHEN s.cross_midnight THEN (('2000-01-02 00:00:00'::timestamp without time zone + (s.end_time)::interval) - ('2000-01-01 00:00:00'::timestamp without time zone + (s.start_time)::interval))
            ELSE (('2000-01-01 00:00:00'::timestamp without time zone + (s.end_time)::interval) - ('2000-01-01 00:00:00'::timestamp without time zone + (s.start_time)::interval))
        END) / (3600)::numeric)) AS hours
   FROM ((production_events p
     JOIN source_audit_events a ON (((a.organization_id = p.organization_id) AND (COALESCE(a.source_audit_id, a.raw_hash) = p.source_record_key))))
     LEFT JOIN shift_rules s ON (((s.organization_id = p.organization_id) AND (s.shift_code = p.shift_code) AND ((s.weekday)::numeric = EXTRACT(isodow FROM p.operational_date)) AND s.active AND (s.effective_from <= p.operational_date) AND ((s.effective_to IS NULL) OR (s.effective_to >= p.operational_date)))))
  WHERE ((p.area = 'UP'::text) AND (p.metric = 'UP_OUT'::text) AND (COALESCE(a.username, ''::text) !~* '^DTG[0-9]+$'::text))
  GROUP BY p.organization_id, p.operational_date, p.shift_code, COALESCE(NULLIF(TRIM(BOTH FROM a.username), ''::text), 'UNASSIGNED'::text);

