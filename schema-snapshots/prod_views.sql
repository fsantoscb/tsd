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
    o.route_id,
    o.cost_centre,
    o.stop_ship_flag,
    o.release_source_status
   FROM (source_orders o
     JOIN v_latest_completed_batch b ON ((b.id = o.sync_batch_id)));

-- public.v_current_release_order_lines
CREATE OR REPLACE VIEW public.v_current_release_order_lines AS
 SELECT l.id,
    l.organization_id,
    l.sync_batch_id,
    l.order_no,
    l.line_number,
    l.product,
    l.client,
    l.qty_lcd,
    l.orig_ref3,
    l.group_code,
    l.product_name,
    l.source_updated_at,
    l.created_at
   FROM (source_release_order_lines l
     JOIN v_latest_completed_batch b ON ((b.id = l.sync_batch_id)));

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

-- public.v_machine_load_not_approved
CREATE OR REPLACE VIEW public.v_machine_load_not_approved AS
 WITH order_process AS (
         SELECT l_1.organization_id,
            l_1.sync_batch_id,
            l_1.order_no,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))) AS has_dtg,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = 'UNDERPRINT'::text)) AS has_underprint,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) <> ALL (ARRAY['DTG_1'::text, 'DTG_2'::text, 'UNDERPRINT'::text]))) AS has_other
           FROM (v_current_release_order_lines l_1
             JOIN v_release_queue q_1 ON (((q_1.organization_id = l_1.organization_id) AND (q_1.sync_batch_id = l_1.sync_batch_id) AND (q_1.order_no = l_1.order_no) AND (q_1.release_status = 'NOT_APPROVED'::text))))
          WHERE (l_1.qty_lcd > (0)::numeric)
          GROUP BY l_1.organization_id, l_1.sync_batch_id, l_1.order_no
        )
 SELECT l.organization_id,
    l.sync_batch_id,
    l.order_no,
    l.line_number,
    l.product,
    l.client,
    l.product_name,
    l.group_code AS source_process_code,
    l.qty_lcd AS process_quantity,
    'PROCESS_QUANTITY'::text AS quantity_semantics,
    q.customer_name,
    q.date_due,
    q.source_priority,
    q.site,
    q.route_id AS release_route_evidence,
    NULL::uuid AS routing_id,
    NULL::text AS routing_code,
    NULL::integer AS routing_revision,
    NULL::text AS machine_group,
        CASE
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UV PRINT'::text) THEN 'UV'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'HATS'::text) THEN 'HATS'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'FINISHED'::text) THEN 'FINISHED'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'STICKERS'::text) THEN 'STICKERS'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'VISUAL'::text) THEN 'VISUAL'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'PROD'::text) THEN 'PRODUCTION'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'CUSTOM EMB'::text) THEN 'CUSTOM EMB'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'EYEWEAR'::text) THEN 'EYEWEAR'::text
            ELSE 'UNRESOLVED'::text
        END AS process,
        CASE
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text
            ELSE NULL::text
        END AS machine_load_bucket,
        CASE
            WHEN ((((op.has_dtg)::integer + (op.has_underprint)::integer) = 1) AND (NOT op.has_other)) THEN 'RESOLVED'::text
            WHEN ((op.has_dtg OR op.has_underprint) AND (op.has_other OR (op.has_dtg AND op.has_underprint))) THEN 'AMBIGUOUS'::text
            ELSE 'UNRESOLVED'::text
        END AS routing_resolution,
    'NOT_APPROVED'::text AS release_status,
    q.release_blockers,
    q.snapshot_completed_at
   FROM ((v_current_release_order_lines l
     JOIN v_release_queue q ON (((q.organization_id = l.organization_id) AND (q.sync_batch_id = l.sync_batch_id) AND (q.order_no = l.order_no) AND (q.release_status = 'NOT_APPROVED'::text))))
     JOIN order_process op ON (((op.organization_id = l.organization_id) AND (op.sync_batch_id = l.sync_batch_id) AND (op.order_no = l.order_no))))
  WHERE (l.qty_lcd > (0)::numeric);

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
            'DTG'::text AS line,
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
     LEFT JOIN production_orders p ON (((p.organization_id = q.organization_id) AND (p.order_no = q.order_no))))
     LEFT JOIN shift_templates s ON ((s.id = p.planned_shift_id)));

-- public.v_release_queue
CREATE OR REPLACE VIEW public.v_release_queue AS
 SELECT id,
    organization_id,
    sync_batch_id,
    order_no,
    date_received,
    date_due,
    date_released,
    source_status,
    source_sub_status,
    customer_code,
    customer_name,
    ship_to_name,
    customer_state,
    city,
    delivery_desc,
    client_so_number,
    source_priority,
    source_updated_at,
    created_at,
    site,
    route_id,
    cost_centre,
    stop_ship_flag,
    release_source_status,
    snapshot_completed_at,
    dtg_qty,
    underprint_qty,
    uv_qty,
    hats_qty,
    finished_qty,
    stickers_qty,
    visual_qty,
    production_qty,
    custom_emb_qty,
    eyewear_qty,
    total_process_qty,
    release_blockers,
    diagnostic_status,
    release_status
   FROM v_release_queue_all
  WHERE (total_process_qty > (0)::numeric);

-- public.v_release_queue_all
CREATE OR REPLACE VIEW public.v_release_queue_all AS
 WITH process_qty AS (
         SELECT v_current_release_order_lines.organization_id,
            v_current_release_order_lines.sync_batch_id,
            v_current_release_order_lines.order_no,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))), (0)::numeric) AS dtg_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'UNDERPRINT'::text)), (0)::numeric) AS underprint_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'UV PRINT'::text)), (0)::numeric) AS uv_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'HATS'::text)), (0)::numeric) AS hats_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'FINISHED'::text)), (0)::numeric) AS finished_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'STICKERS'::text)), (0)::numeric) AS stickers_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'VISUAL'::text)), (0)::numeric) AS visual_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'PROD'::text)), (0)::numeric) AS production_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'CUSTOM EMB'::text)), (0)::numeric) AS custom_emb_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'EYEWEAR'::text)), (0)::numeric) AS eyewear_qty
           FROM v_current_release_order_lines
          GROUP BY v_current_release_order_lines.organization_id, v_current_release_order_lines.sync_batch_id, v_current_release_order_lines.order_no
        ), evidence AS (
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
            o.route_id,
            o.cost_centre,
            o.stop_ship_flag,
            o.release_source_status,
            b.completed_at AS snapshot_completed_at,
            COALESCE(p.dtg_qty, (0)::numeric) AS dtg_qty,
            COALESCE(p.underprint_qty, (0)::numeric) AS underprint_qty,
            COALESCE(p.uv_qty, (0)::numeric) AS uv_qty,
            COALESCE(p.hats_qty, (0)::numeric) AS hats_qty,
            COALESCE(p.finished_qty, (0)::numeric) AS finished_qty,
            COALESCE(p.stickers_qty, (0)::numeric) AS stickers_qty,
            COALESCE(p.visual_qty, (0)::numeric) AS visual_qty,
            COALESCE(p.production_qty, (0)::numeric) AS production_qty,
            COALESCE(p.custom_emb_qty, (0)::numeric) AS custom_emb_qty,
            COALESCE(p.eyewear_qty, (0)::numeric) AS eyewear_qty
           FROM ((v_current_orders o
             JOIN v_latest_completed_batch b ON ((b.id = o.sync_batch_id)))
             LEFT JOIN process_qty p ON (((p.organization_id = o.organization_id) AND (p.sync_batch_id = o.sync_batch_id) AND (p.order_no = o.order_no))))
          WHERE ((o.site = 'B'::text) AND (o.order_no ~~ '13%'::text) AND (o.release_source_status = '1'::text) AND ((o.date_due >= (now() - '30 days'::interval)) AND (o.date_due <= (now() + '30 days'::interval))))
        ), resolved AS (
         SELECT e.id,
            e.organization_id,
            e.sync_batch_id,
            e.order_no,
            e.date_received,
            e.date_due,
            e.date_released,
            e.source_status,
            e.source_sub_status,
            e.customer_code,
            e.customer_name,
            e.ship_to_name,
            e.customer_state,
            e.city,
            e.delivery_desc,
            e.client_so_number,
            e.source_priority,
            e.source_updated_at,
            e.created_at,
            e.site,
            e.route_id,
            e.cost_centre,
            e.stop_ship_flag,
            e.release_source_status,
            e.snapshot_completed_at,
            e.dtg_qty,
            e.underprint_qty,
            e.uv_qty,
            e.hats_qty,
            e.finished_qty,
            e.stickers_qty,
            e.visual_qty,
            e.production_qty,
            e.custom_emb_qty,
            e.eyewear_qty,
            (((((((((e.dtg_qty + e.underprint_qty) + e.uv_qty) + e.hats_qty) + e.finished_qty) + e.stickers_qty) + e.visual_qty) + e.production_qty) + e.custom_emb_qty) + e.eyewear_qty) AS total_process_qty,
            array_remove(ARRAY[
                CASE
                    WHEN (upper(TRIM(BOTH FROM e.route_id)) = 'NO'::text) THEN 'ROUTE_BLOCKED'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN (upper(TRIM(BOTH FROM e.stop_ship_flag)) = 'Y'::text) THEN 'STOP_SHIP'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN (e.custom_emb_qty > (0)::numeric) THEN 'CUSTOM_EMB'::text
                    ELSE NULL::text
                END], NULL::text) AS release_blockers
           FROM evidence e
        )
 SELECT id,
    organization_id,
    sync_batch_id,
    order_no,
    date_received,
    date_due,
    date_released,
    source_status,
    source_sub_status,
    customer_code,
    customer_name,
    ship_to_name,
    customer_state,
    city,
    delivery_desc,
    client_so_number,
    source_priority,
    source_updated_at,
    created_at,
    site,
    route_id,
    cost_centre,
    stop_ship_flag,
    release_source_status,
    snapshot_completed_at,
    dtg_qty,
    underprint_qty,
    uv_qty,
    hats_qty,
    finished_qty,
    stickers_qty,
    visual_qty,
    production_qty,
    custom_emb_qty,
    eyewear_qty,
    total_process_qty,
    release_blockers,
        CASE
            WHEN (total_process_qty <= (0)::numeric) THEN 'ZERO_PRODUCTION_QTY'::text
            ELSE NULL::text
        END AS diagnostic_status,
        CASE
            WHEN ((route_id IS NULL) OR (TRIM(BOTH FROM route_id) = ''::text) OR (stop_ship_flag IS NULL) OR (TRIM(BOTH FROM stop_ship_flag) = ''::text) OR (date_due IS NULL) OR (release_source_status IS NULL)) THEN 'UNKNOWN'::text
            WHEN (upper(TRIM(BOTH FROM COALESCE(cost_centre, ''::text))) = 'NOTAPPRO'::text) THEN 'NOT_APPROVED'::text
            WHEN (cardinality(release_blockers) > 0) THEN 'BLOCKED'::text
            WHEN ((date_due)::date > (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date + 7)) THEN 'FUTURE_DUE'::text
            ELSE 'ELIGIBLE'::text
        END AS release_status
   FROM resolved r;

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
            WHEN r.cross_midnight THEN ((r.end_time - r.start_time) + '24:00:00'::interval)
            ELSE (r.end_time - r.start_time)
        END) / (3600)::numeric)) AS hours
   FROM ((production_events p
     JOIN source_audit_events a ON (((a.organization_id = p.organization_id) AND (COALESCE(a.source_audit_id, a.raw_hash) = p.source_record_key))))
     LEFT JOIN shift_rules r ON (((r.organization_id = p.organization_id) AND (r.shift_code = p.shift_code) AND ((r.weekday)::numeric = EXTRACT(isodow FROM p.operational_date)) AND r.active AND (r.effective_from <= p.operational_date) AND ((r.effective_to IS NULL) OR (r.effective_to >= p.operational_date)))))
  WHERE ((p.area = 'UP'::text) AND (p.metric = 'UP_OUT'::text))
  GROUP BY p.organization_id, p.operational_date, p.shift_code, COALESCE(NULLIF(TRIM(BOTH FROM a.username), ''::text), 'UNASSIGNED'::text);

