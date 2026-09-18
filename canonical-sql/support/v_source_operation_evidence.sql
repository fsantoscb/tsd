create or replace view public."v_source_operation_evidence" as
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
  WHERE (mapping_rank = 1);;

