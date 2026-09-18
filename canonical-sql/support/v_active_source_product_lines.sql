create or replace view public."v_active_source_product_lines" as
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
   FROM expanded;;

