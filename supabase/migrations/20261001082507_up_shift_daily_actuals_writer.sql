-- Stage C: local only, depends on Stage A; no backfill or authority activation.
begin;
create table public.up_daily_authority_markers (
 organization_id uuid not null references public.organizations(id),
 operational_date date not null,
 source_snapshot_id uuid not null,
 unique(organization_id,operational_date)
);
alter table public.up_daily_authority_markers owner to postgres;
alter table public.up_daily_authority_markers enable row level security;
revoke all on public.up_daily_authority_markers from public,anon,authenticated;
grant all on public.up_daily_authority_markers to service_role;

create function public.replace_up_shift_daily_actuals_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=public as $writer$
declare
 org uuid; snapshot uuid; from_date date; to_date date; source_row jsonb; cov jsonb;
 daily jsonb; sum_garments numeric; sum_events numeric; maximum timestamptz;
 shift_count integer; daily_count integer; coverage_count integer;
begin
 if jsonb_typeof(p_payload) is distinct from 'object'
  or p_payload->>'contractVersion' is distinct from 'UP_SHIFT_DAILY_V1'
  or coalesce(p_payload->>'organizationId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  or coalesce(p_payload->>'sourceSnapshotId','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  or coalesce(p_payload->>'from','') !~ '^\d{4}-\d{2}-\d{2}$'
  or coalesce(p_payload->>'to','') !~ '^\d{4}-\d{2}-\d{2}$'
  or jsonb_typeof(p_payload->'rows') is distinct from 'array'
  or jsonb_typeof(p_payload->'dailySummaries') is distinct from 'array'
  or jsonb_typeof(p_payload->'coverage') is distinct from 'array' then
  raise exception 'INVALID_UP_SHIFT_PAYLOAD';
 end if;
 org:=(p_payload->>'organizationId')::uuid; snapshot:=(p_payload->>'sourceSnapshotId')::uuid;
 from_date:=(p_payload->>'from')::date; to_date:=(p_payload->>'to')::date;
 if from_date>to_date or to_date-from_date>30 or jsonb_array_length(p_payload->'rows')>124
  or jsonb_array_length(p_payload->'dailySummaries')>31
  or jsonb_array_length(p_payload->'coverage')<>to_date-from_date+1 then raise exception 'INVALID_UP_SHIFT_RANGE';end if;
 perform pg_advisory_xact_lock(hashtextextended('UP_DAILY_AUTHORITY:'||org::text,0));
 if not exists(select 1 from public.organizations where id=org) then raise exception 'INVALID_UP_ORGANIZATION';end if;

 for cov in select value from jsonb_array_elements(p_payload->'coverage') loop
  if jsonb_typeof(cov) is distinct from 'object'
   or cov->'complete' is distinct from 'true'::jsonb
   or jsonb_typeof(cov->'hasActivity') is distinct from 'boolean'
   or coalesce(cov->>'operationalDate','') !~ '^\d{4}-\d{2}-\d{2}$'
   or (cov->>'operationalDate')::date not between from_date and to_date then
   raise exception 'INCOMPLETE_UP_SHIFT_COVERAGE';end if;
 end loop;
 if (select count(distinct value->>'operationalDate') from jsonb_array_elements(p_payload->'coverage'))<>to_date-from_date+1 then
  raise exception 'INCOMPLETE_UP_SHIFT_COVERAGE';end if;

 for source_row in select value from jsonb_array_elements(p_payload->'rows') union all
            select value from jsonb_array_elements(p_payload->'dailySummaries') loop
  if jsonb_typeof(source_row) is distinct from 'object'
   or coalesce(source_row->>'operationalDate','') !~ '^\d{4}-\d{2}-\d{2}$'
   or (source_row->>'operationalDate')::date not between from_date and to_date
   or source_row->>'sourceSnapshotId' is distinct from p_payload->>'sourceSnapshotId'
   or jsonb_typeof(source_row->'garments') is distinct from 'number'
   or (source_row->>'garments')::numeric<0
   or jsonb_typeof(source_row->'sourceEventCount') is distinct from 'number'
   or (source_row->>'sourceEventCount')::numeric<>trunc((source_row->>'sourceEventCount')::numeric)
   or (source_row->>'sourceEventCount')::numeric not between 1 and 9007199254740991
   or coalesce(source_row->>'sourceMaxEventAt','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+10:00$'
   then raise exception 'INVALID_UP_SHIFT_ROW';end if;
  perform (source_row->>'sourceMaxEventAt')::timestamptz;
 end loop;
 for source_row in select value from jsonb_array_elements(p_payload->'rows') loop
  if coalesce(source_row->>'shiftCode','') not in('SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT')
   or source_row->>'calculationVersion' is distinct from 'UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1'
   or source_row ? 'jobs' then raise exception 'INVALID_UP_SHIFT_ROW';end if;
 end loop;
 for source_row in select value from jsonb_array_elements(p_payload->'dailySummaries') loop
  if source_row->>'calculationVersion' is distinct from 'UP_UNDERPRINT_EXIT_DAILY_V1'
   or source_row ? 'shiftCode'
   or jsonb_typeof(source_row->'jobs') is distinct from 'number'
   or (source_row->>'jobs')::numeric<>trunc((source_row->>'jobs')::numeric)
   or (source_row->>'jobs')::numeric not between 0 and 9007199254740991 then raise exception 'INVALID_UP_DAILY_SUMMARY';end if;
 end loop;
 if exists(select 1 from jsonb_array_elements(p_payload->'rows') r group by r->>'operationalDate',r->>'shiftCode' having count(*)>1)
  or exists(select 1 from jsonb_array_elements(p_payload->'dailySummaries') r group by r->>'operationalDate' having count(*)>1) then
  raise exception 'DUPLICATE_UP_SHIFT_GRAIN';end if;

 for cov in select value from jsonb_array_elements(p_payload->'coverage') loop
  select value into daily from jsonb_array_elements(p_payload->'dailySummaries') where value->>'operationalDate'=cov->>'operationalDate';
  select sum((value->>'garments')::numeric),sum((value->>'sourceEventCount')::numeric),
   max((value->>'sourceMaxEventAt')::timestamptz),count(*) into sum_garments,sum_events,maximum,shift_count
   from jsonb_array_elements(p_payload->'rows') where value->>'operationalDate'=cov->>'operationalDate';
  if (cov->>'hasActivity')::boolean then
   if daily is null or shift_count=0 then raise exception 'UP_SHIFT_ACTIVITY_MISMATCH';end if;
   if (daily->>'garments')::numeric<>sum_garments or (daily->>'sourceEventCount')::numeric<>sum_events then raise exception 'UP_SHIFT_RECONCILIATION';end if;
   if (daily->>'sourceMaxEventAt')::timestamptz<>maximum then raise exception 'UP_SHIFT_WATERMARK';end if;
  elsif daily is not null or shift_count<>0 then raise exception 'UP_SHIFT_ACTIVITY_MISMATCH';end if;
 end loop;
 select max((value->>'sourceMaxEventAt')::timestamptz) into maximum from jsonb_array_elements(p_payload->'dailySummaries');
 if not(p_payload ? 'sourceMaxEventAt') or
  (case when p_payload->'sourceMaxEventAt'='null'::jsonb then null else (p_payload->>'sourceMaxEventAt')::timestamptz end) is distinct from maximum then
  raise exception 'UP_SHIFT_GLOBAL_WATERMARK';end if;

 -- Everything above validates before deletion. Exceptions roll back all three tables.
 delete from public.up_shift_daily_actuals where organization_id=org and operational_date between from_date and to_date;
 insert into public.up_shift_daily_actuals(organization_id,operational_date,shift_code,garments,source_event_count,last_source_timestamp,source_snapshot_id,status,source_system,calculation_version,synced_at)
 select org,(r->>'operationalDate')::date,r->>'shiftCode',(r->>'garments')::numeric,(r->>'sourceEventCount')::bigint,(r->>'sourceMaxEventAt')::timestamptz,snapshot,'CURRENT','ORACLE_ISIS_AUDIT',r->>'calculationVersion',now()
 from jsonb_array_elements(p_payload->'rows') r;
 get diagnostics shift_count=row_count;
 delete from public.up_daily_actuals where organization_id=org and operational_date between from_date and to_date;
 insert into public.up_daily_actuals(organization_id,operational_date,garments,jobs,source_event_count,last_source_timestamp,status,source_system,calculation_version,synced_at)
 select org,(r->>'operationalDate')::date,(r->>'garments')::numeric,(r->>'jobs')::bigint,(r->>'sourceEventCount')::bigint,(r->>'sourceMaxEventAt')::timestamptz,'CURRENT','ORACLE_ISIS_AUDIT',r->>'calculationVersion',now()
 from jsonb_array_elements(p_payload->'dailySummaries') r;
 get diagnostics daily_count=row_count;
 delete from public.up_daily_authority_markers where organization_id=org and operational_date between from_date and to_date;
 insert into public.up_daily_authority_markers(organization_id,operational_date,source_snapshot_id)
 select org,(r->>'operationalDate')::date,snapshot from jsonb_array_elements(p_payload->'coverage') r;
 get diagnostics coverage_count=row_count;
 return jsonb_build_object('accepted',daily_count,'acceptedShifts',shift_count,'acceptedCoverage',coverage_count);
end $writer$;
alter function public.replace_up_shift_daily_actuals_v1(jsonb) owner to postgres;
revoke all on function public.replace_up_shift_daily_actuals_v1(jsonb) from public,anon,authenticated;
grant execute on function public.replace_up_shift_daily_actuals_v1(jsonb) to service_role;

-- Exact legacy body plus shared lock and overlap rejection only.
create or replace function public.replace_up_daily_actuals(p_organization_id uuid,p_from date,p_to date,p_rows jsonb)returns bigint language plpgsql security definer set search_path=public as $$declare v_count bigint;begin perform pg_advisory_xact_lock(hashtextextended('UP_DAILY_AUTHORITY:'||p_organization_id::text,0));if exists(select 1 from public.up_daily_authority_markers where organization_id=p_organization_id and operational_date between p_from and p_to)then raise exception 'UP_SHIFT_AUTHORITY_ACTIVE';end if;if p_from is null or p_to is null or p_from>p_to or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>1000 then raise exception 'INVALID_UP_DAILY_PAYLOAD';end if;if exists(select 1 from jsonb_array_elements(p_rows)r where(r->>'operationalDate')::date not between p_from and p_to or coalesce((r->>'garments')::numeric,-1)<0 or coalesce((r->>'jobs')::bigint,-1)<0 or coalesce((r->>'sourceEventCount')::bigint,-1)<0)then raise exception 'INVALID_UP_DAILY_ROW';end if;if exists(select 1 from jsonb_array_elements(p_rows)r group by r->>'operationalDate' having count(*)>1)then raise exception 'DUPLICATE_UP_DAILY_GRAIN';end if;delete from public.up_daily_actuals where organization_id=p_organization_id and operational_date between p_from and p_to;insert into public.up_daily_actuals(organization_id,operational_date,garments,jobs,source_event_count,last_source_timestamp,synced_at,status,source_system,calculation_version)select p_organization_id,(r->>'operationalDate')::date,(r->>'garments')::numeric,(r->>'jobs')::bigint,(r->>'sourceEventCount')::bigint,nullif(r->>'sourceMaxEventAt','')::timestamptz,now(),'CURRENT','ORACLE_ISIS_AUDIT',coalesce(nullif(r->>'calculationVersion',''),'UP_UNDERPRINT_EXIT_DAILY_V1')from jsonb_array_elements(p_rows)r;get diagnostics v_count=row_count;return v_count;end$$;
commit;
