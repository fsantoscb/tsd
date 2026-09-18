CREATE OR REPLACE FUNCTION public.release_reactivation_action(p_status text, p_executed numeric, p_eligible boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
select case
 when p_eligible is not true then 'RELEASE_REACTIVATION_BLOCKED'
 when p_status='COMPLETED' then 'RELEASE_REACTIVATED_AFTER_COMPLETION'
 when p_status='IN_PROGRESS' or coalesce(p_executed,0)>0 then 'RELEASE_REACTIVATED_AFTER_PRODUCTION_START'
 when p_status='PLANNED' then 'RESTORED_TO_PLANNED_DEMAND'
 when p_status='CANCELLED' then 'RELEASE_REACTIVATED_MO_CANCELLED'
 else 'INCREMENTAL_RECONCILIATION_REQUIRED'
end$function$
;

