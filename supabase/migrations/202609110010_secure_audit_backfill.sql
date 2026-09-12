create or replace function public.ingest_audit_backfill(
  p_organization_id uuid,
  p_events jsonb,
  p_rebuild boolean default false
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rebuilt bigint := 0;
begin
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 1000 then
    raise exception 'INVALID_BACKFILL_PAYLOAD';
  end if;

  insert into public.source_audit_events (
    organization_id, source_audit_id, order_no, username, from_zone, to_zone,
    from_location, to_location, product, from_pack_id, to_pack_id, source_qty,
    source_weight, production_units, event_at, raw_hash
  )
  select
    p_organization_id,
    event->>'sourceAuditId',
    coalesce(event->>'orderNo', ''),
    event->>'username', event->>'fromZone', event->>'toZone',
    event->>'fromLocation', event->>'toLocation', event->>'product',
    event->>'fromPackId', event->>'toPackId',
    nullif(event->>'sourceQty', '')::numeric,
    nullif(event->>'sourceWeight', '')::numeric,
    coalesce(nullif(event->>'productionUnits', '')::numeric, 0),
    (event->>'eventAt')::timestamptz,
    event->>'rawHash'
  from jsonb_array_elements(p_events) as event
  on conflict (organization_id, source_audit_id) do nothing;

  if p_rebuild then
    select public.rebuild_production_events(p_organization_id) into v_rebuilt;
  end if;
  return v_rebuilt;
end;
$$;

revoke all on function public.ingest_audit_backfill(uuid, jsonb, boolean) from public;
grant execute on function public.ingest_audit_backfill(uuid, jsonb, boolean) to anon, authenticated, service_role;
