create or replace view public."v_sales_order_release_eligibility" as
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
  GROUP BY s.organization_id, s.source_order_no;;

