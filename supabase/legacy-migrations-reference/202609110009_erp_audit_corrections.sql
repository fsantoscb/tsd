create or replace function rebuild_production_events(p_organization_id uuid) returns integer
language plpgsql security definer set search_path=public as $$
declare affected integer;
begin
  delete from production_events where organization_id=p_organization_id and source='ORACLE_AUDIT';
  insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)
  select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone 'Australia/Brisbane',(a.event_at at time zone 'Australia/Brisbane')::date,
    case when r.cross_midnight and (a.event_at at time zone 'Australia/Brisbane')::time<r.end_time then (a.event_at at time zone 'Australia/Brisbane')::date-1 else (a.event_at at time zone 'Australia/Brisbane')::date end,
    extract(hour from a.event_at at time zone 'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,m.quantity,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then 'OUT_OF_SHIFT' else 'COMPLETE' end,'ERP_KPI_V2'
  from source_audit_events a
  cross join lateral (
    select * from (values
      ('DTG'::text,'DTG_PRINT'::text,coalesce(a.production_units,0),'prints'::text,upper(coalesce(a.from_zone,''))='DTGS' and upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_IN',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_zone,''))='DTGS' and upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_OUT',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_zone,''))='PWL1' and upper(coalesce(a.to_zone,''))<>'PWL1'),
      ('UP','UP_IN',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.to_location,'')) like '%UNDERPRINT%'),
      ('UP','UP_OUT',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_location,'')) like '%UNDERPRINT%' and upper(coalesce(a.to_location,'')) not like '%UNDERPRINT%')
    ) v(area,metric,quantity,unit,accepted) where accepted and quantity>0
  ) m
  left join lateral (select s.* from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone 'Australia/Brisbane')::date and (s.effective_to is null or s.effective_to>=(a.event_at at time zone 'Australia/Brisbane')::date) and s.weekday=extract(isodow from case when s.cross_midnight and (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time then (a.event_at at time zone 'Australia/Brisbane')::date-1 else (a.event_at at time zone 'Australia/Brisbane')::date end) and (case when s.cross_midnight then (a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time or (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time else (a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time and (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time end) order by s.effective_from desc limit 1) r on true
  where a.organization_id=p_organization_id;
  get diagnostics affected=row_count;
  return affected;
end$$;
revoke all on function rebuild_production_events(uuid) from public,anon,authenticated;
grant execute on function rebuild_production_events(uuid) to service_role;