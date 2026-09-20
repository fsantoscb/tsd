create or replace function public.ingest_audit_backfill(
  p_organization_id uuid,
  p_events jsonb,
  p_rebuild boolean default false
) returns bigint
language plpgsql
security definer
set search_path=public
as $$
declare
  v_inserted bigint:=0;
  v_affected bigint:=0;
begin
  if jsonb_typeof(p_events)<>'array' or jsonb_array_length(p_events)>1000 then
    raise exception 'INVALID_BACKFILL_PAYLOAD';
  end if;

  insert into public.source_audit_events(
    organization_id,source_audit_id,order_no,username,from_zone,to_zone,
    from_location,to_location,product,from_pack_id,to_pack_id,source_qty,
    source_weight,production_units,event_at,raw_hash,queue,task
  )
  select p_organization_id,event->>'sourceAuditId',coalesce(event->>'orderNo',''),
    event->>'username',event->>'fromZone',event->>'toZone',event->>'fromLocation',
    event->>'toLocation',event->>'product',event->>'fromPackId',event->>'toPackId',
    nullif(event->>'sourceQty','')::numeric,nullif(event->>'sourceWeight','')::numeric,
    coalesce(nullif(event->>'productionUnits','')::numeric,0),
    (event->>'eventAt')::timestamptz,event->>'rawHash',event->>'queue',event->>'task'
  from jsonb_array_elements(p_events) event
  on conflict do nothing;

  if p_rebuild then
    delete from public.production_events
    where organization_id=p_organization_id
      and source='ORACLE_AUDIT'
      and metric='DTG_PRINT';
  end if;

  insert into public.production_events(
    organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,
    operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,
    source_mode,source_record_key,quality_status,calculation_version
  )
  select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,
    a.event_at,a.event_at at time zone 'Australia/Brisbane',
    (a.event_at at time zone 'Australia/Brisbane')::date,
    (a.event_at at time zone 'Australia/Brisbane')::date,
    extract(hour from a.event_at at time zone 'Australia/Brisbane')::smallint,
    coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,a.production_units,m.unit,
    'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),
    case when r.shift_code is null then 'OUT_OF_SHIFT' else 'COMPLETE' end,
    case when m.metric='DTG_PRINT' then 'ERP_KPI_V2_DTG_ZONE_TRANSITION' else 'ERP_KPI_V1' end
  from public.source_audit_events a
  cross join lateral(
    select * from(values
      ('DTG'::text,'DTG_PRINT'::text,'prints'::text,upper(coalesce(a.from_zone,''))='DTGS' and upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_IN','garments',upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_OUT','garments',upper(coalesce(a.from_zone,''))='PWL1'),
      ('UP','UP_IN','garments',upper(coalesce(a.to_location,'')) like '%UNDERPRINT%'),
      ('UP','UP_OUT','garments',upper(coalesce(a.from_location,'')) like '%UNDERPRINT%' and upper(coalesce(a.to_location,'')) not like '%UNDERPRINT%')
    ) v(area,metric,unit,accepted) where accepted
  ) m
  left join lateral(
    select s.* from public.shift_rules s
    where s.organization_id=a.organization_id and s.active
      and s.effective_from<=(a.event_at at time zone 'Australia/Brisbane')::date
      and(s.effective_to is null or s.effective_to>=(a.event_at at time zone 'Australia/Brisbane')::date)
      and s.weekday=extract(isodow from(a.event_at at time zone 'Australia/Brisbane')::date)
      and(case when s.cross_midnight
        then(a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time or(a.event_at at time zone 'Australia/Brisbane')::time<s.end_time
        else(a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time and(a.event_at at time zone 'Australia/Brisbane')::time<s.end_time end)
    order by s.effective_from desc limit 1
  ) r on true
  where a.organization_id=p_organization_id
    and a.production_units>0
    and(
      (m.metric='DTG_PRINT' and p_rebuild)
      or a.raw_hash in(select event->>'rawHash' from jsonb_array_elements(p_events) event)
    )
  on conflict do nothing;
  get diagnostics v_inserted=row_count;
  return v_inserted;
end
$$;

revoke all on function public.ingest_audit_backfill(uuid,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.ingest_audit_backfill(uuid,jsonb,boolean) to service_role;
