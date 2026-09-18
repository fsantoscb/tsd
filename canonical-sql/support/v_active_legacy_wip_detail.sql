create or replace view public."v_active_legacy_wip_detail" as
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
  GROUP BY organization_id, source_order_no, stage_code;;

