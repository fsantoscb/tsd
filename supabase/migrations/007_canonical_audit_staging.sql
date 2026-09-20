create or replace function public.stage_audit_backfill(
  p_organization_id uuid,
  p_events jsonb
) returns bigint
language plpgsql
security definer
set search_path=public
set statement_timeout='0'
as $$
declare
  v_affected bigint:=0;
begin
  if jsonb_typeof(p_events)<>'array' or jsonb_array_length(p_events)>5000 then
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
  on conflict(organization_id,source_audit_id) do update set
    order_no=excluded.order_no,
    username=excluded.username,
    from_zone=excluded.from_zone,
    to_zone=excluded.to_zone,
    from_location=excluded.from_location,
    to_location=excluded.to_location,
    product=excluded.product,
    from_pack_id=excluded.from_pack_id,
    to_pack_id=excluded.to_pack_id,
    source_qty=excluded.source_qty,
    source_weight=excluded.source_weight,
    production_units=excluded.production_units,
    event_at=excluded.event_at,
    raw_hash=excluded.raw_hash,
    queue=excluded.queue,
    task=excluded.task;

  get diagnostics v_affected=row_count;
  return v_affected;
end
$$;

revoke all on function public.stage_audit_backfill(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.stage_audit_backfill(uuid,jsonb) to service_role;
