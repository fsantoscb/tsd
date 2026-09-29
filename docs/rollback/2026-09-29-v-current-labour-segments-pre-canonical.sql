-- PREPARED ROLLBACK ONLY. DO NOT RUN WITHOUT A SEPARATE PRODUCTION AUTHORIZATION.
-- Captured read-only from Production project eziirebccovlvhaonsgw on 2026-09-29.
-- Original pg_get_viewdef(..., false) MD5: d38ab739730f066374497a372892277c
-- Original owner: postgres
-- Original relacl: {postgres=arwdDxtm/postgres,authenticated=arwd/postgres,service_role=arwdDxtm/postgres}
-- Original reloptions: NULL
-- CREATE OR REPLACE VIEW preserves existing ownership, grants and reloptions;
-- the assertions below refuse to commit if they are not exactly the snapshot.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE VIEW public.v_current_labour_segments AS
WITH ranked AS (
  SELECT r_1.id,
         row_number() OVER (
           PARTITION BY r_1.organization_id,
                        COALESCE(NULLIF(r_1.source_timesheet_id, ''::text), r_1.source_row_key)
           ORDER BY b.imported_at DESC, r_1.created_at DESC
         ) AS rn
  FROM deputy_raw_timesheets r_1
  JOIN deputy_import_batches b ON b.id = r_1.import_batch_id
  WHERE b.status = 'COMPLETED'::text
    AND r_1.row_status = 'ACCEPTED'::text
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
FROM labour_segments s
JOIN ranked r ON r.id = s.source_timesheet_row_id AND r.rn = 1;

DO $$
DECLARE
  actual_owner text;
  actual_acl text;
  actual_reloptions text;
  actual_fingerprint text;
  actual_columns text;
BEGIN
  SELECT pg_get_userbyid(c.relowner), c.relacl::text, c.reloptions::text,
         md5(pg_get_viewdef(c.oid, false))
    INTO actual_owner, actual_acl, actual_reloptions, actual_fingerprint
  FROM pg_class c
  WHERE c.oid = 'public.v_current_labour_segments'::regclass;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
    INTO actual_columns
  FROM pg_attribute a
  WHERE a.attrelid = 'public.v_current_labour_segments'::regclass
    AND a.attnum > 0 AND NOT a.attisdropped;

  IF actual_owner IS DISTINCT FROM 'postgres'
     OR actual_acl IS DISTINCT FROM '{postgres=arwdDxtm/postgres,authenticated=arwd/postgres,service_role=arwdDxtm/postgres}'
     OR actual_reloptions IS NOT NULL
     OR actual_fingerprint IS DISTINCT FROM 'd38ab739730f066374497a372892277c'
     OR actual_columns IS DISTINCT FROM
       'id:uuid,organization_id:uuid,import_batch_id:uuid,source_timesheet_row_id:uuid,person_key:text,area_code:text,segment_start:timestamp with time zone,segment_end:timestamp with time zone,calendar_date:date,operational_date:date,hour_bucket:smallint,shift_code:text,paid_hours:numeric,regular_hours:numeric,overtime_hours:numeric,paid_break_hours:numeric,productive_hours:numeric,approval_status:text,allocation_method:text,week_start:date,calculation_version:text,created_at:timestamp with time zone'
  THEN
    RAISE EXCEPTION 'Labour view rollback fingerprint or metadata mismatch; transaction must not commit';
  END IF;
END $$;

COMMIT;
