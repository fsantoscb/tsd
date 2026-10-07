-- UNAPPLIED recovery artifact. Use only under separately approved activation.
-- Preserve selection versions/tombstones, all generations/segments and evidence.
begin;
revoke execute on function public.labour_v3_select_cohort_v1(jsonb) from service_role;
revoke execute on function public.labour_v3_certify_window_v1(uuid,date,date) from service_role;
commit;
