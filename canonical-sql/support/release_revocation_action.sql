CREATE OR REPLACE FUNCTION public.release_revocation_action(p_status text, p_executed numeric, p_valid boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$select case when p_valid is not true then case when p_valid is false then'INVALID_AT_CREATION'else'CANNOT_PROVE'end when p_status='COMPLETED'then'RELEASE_REVOKED_AFTER_COMPLETION'when p_status='IN_PROGRESS'or coalesce(p_executed,0)>0 then'RELEASE_REVOKED_AFTER_PRODUCTION_START'when p_status in('PLANNED','PENDING','READY','RELEASED')then'WITHDRAWN_FROM_PLANNED_DEMAND'when p_status='CANCELLED'then'CANCELLED_MO_REVIEW_REQUIRED'else'CANNOT_PROVE'end$function$
;

