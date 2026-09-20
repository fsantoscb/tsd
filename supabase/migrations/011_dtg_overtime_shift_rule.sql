begin;

alter table public.shift_rules
  drop constraint if exists shift_rules_shift_code_check;

alter table public.shift_rules
  add constraint shift_rules_shift_code_check
  check (shift_code = any (array['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OVERTIME'::text]));

alter table public.production_daily_actuals
  drop constraint if exists production_daily_actuals_shift_code_check;

alter table public.production_daily_actuals
  add constraint production_daily_actuals_shift_code_check
  check (shift_code = any (array['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OVERTIME'::text, 'OUT_OF_SHIFT'::text]));

create or replace function public.replace_dtg_daily_actuals(p_organization_id uuid,p_from date,p_to date,p_rows jsonb)
returns bigint language plpgsql security definer set search_path=public as $$
declare v_count bigint;
begin
  if p_from is null or p_to is null or p_from>p_to or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>10000 then raise exception 'INVALID_DTG_DAILY_PAYLOAD'; end if;
  if exists(select 1 from jsonb_array_elements(p_rows)r where (r->>'operationalDate')::date not between p_from and p_to or coalesce(r->>'process','')<>'DTG' or coalesce(r->>'shiftCode','') not in ('SHIFT_1','SHIFT_2','SHIFT_3','OVERTIME','OUT_OF_SHIFT') or coalesce((r->>'garments')::numeric,-1)<0 or coalesce((r->>'prints')::numeric,-1)<0) then raise exception 'INVALID_DTG_DAILY_ROW'; end if;
  if exists(select 1 from jsonb_array_elements(p_rows)r group by r->>'operationalDate',upper(coalesce(nullif(trim(r->>'machineCode'),''),'UNATTRIBUTED')),r->>'shiftCode' having count(*)>1) then raise exception 'DUPLICATE_DTG_DAILY_GRAIN'; end if;
  delete from public.production_daily_actuals where organization_id=p_organization_id and process='DTG' and operational_date between p_from and p_to;
  insert into public.production_daily_actuals(organization_id,operational_date,process,machine_code,shift_code,garments,prints,source_event_count,source_min_audit_id,source_max_audit_id,source_max_event_at,source_system,calculation_version,refreshed_at)
  select p_organization_id,(r->>'operationalDate')::date,'DTG',upper(coalesce(nullif(trim(r->>'machineCode'),''),'UNATTRIBUTED')),r->>'shiftCode',(r->>'garments')::bigint,(r->>'prints')::numeric,(r->>'sourceEventCount')::bigint,nullif(r->>'sourceMinAuditId','')::bigint,nullif(r->>'sourceMaxAuditId','')::bigint,nullif(r->>'sourceMaxEventAt','')::timestamptz,'ORACLE_ISIS_AUDIT',coalesce(nullif(r->>'calculationVersion',''),'DTG_PCOR_SHIFT_V2'),now() from jsonb_array_elements(p_rows)r;
  get diagnostics v_count=row_count;
  return v_count;
end$$;

revoke all on function public.replace_dtg_daily_actuals(uuid,date,date,jsonb) from public,anon,authenticated;
grant execute on function public.replace_dtg_daily_actuals(uuid,date,date,jsonb) to service_role;

commit;
