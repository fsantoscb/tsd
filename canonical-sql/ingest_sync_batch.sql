create or replace function public.ingest_sync_batch(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path to 'public'
set statement_timeout to '120s'
as $function$
declare
  batch_id uuid;
  audit_count integer := 0;
  v_organization_id uuid := (payload ->> 'organizationId')::uuid;
  v_orders jsonb := coalesce(payload -> 'orders', '[]'::jsonb);
  v_release_lines jsonb := coalesce(payload -> 'releaseOrderLines', '[]'::jsonb);
  v_workbank jsonb := coalesce(payload -> 'workbank', '[]'::jsonb);
  v_stock jsonb := coalesce(payload -> 'stock', '[]'::jsonb);
  v_audit jsonb := coalesce(payload -> 'auditEvents', '[]'::jsonb);
begin
  if v_organization_id is null then
    raise exception 'ORGANIZATION_ID_REQUIRED';
  end if;
  if jsonb_typeof(v_orders) <> 'array'
     or jsonb_typeof(v_release_lines) <> 'array'
     or jsonb_typeof(v_workbank) <> 'array'
     or jsonb_typeof(v_stock) <> 'array'
     or jsonb_typeof(v_audit) <> 'array' then
    raise exception 'INVALID_SYNC_PAYLOAD';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text, 0));

  insert into public.sync_batches(organization_id, status, connector_version)
  values(v_organization_id, 'running', payload ->> 'connectorVersion')
  returning id into batch_id;

  delete from public.source_release_order_lines where organization_id = v_organization_id;
  delete from public.source_orders where organization_id = v_organization_id;
  delete from public.source_workbank_items where organization_id = v_organization_id;
  delete from public.source_stock_items where organization_id = v_organization_id;

  insert into public.source_orders(
    organization_id, sync_batch_id, order_no, date_received, date_due,
    date_released, source_status, source_sub_status, customer_code,
    customer_name, ship_to_name, customer_state, city, delivery_desc,
    client_so_number, source_priority, site, source_route_id, cost_centre,
    stop_ship_flag, release_source_status, source_updated_at
  )
  select v_organization_id, batch_id, x."orderNo", x."dateReceived",
    x."dateDue", x."dateReleased", x."sourceStatus", x."sourceSubStatus",
    x."customerCode", x."customerName", x."shipToName", x."customerState",
    x.city, x."deliveryDesc", x."clientSoNumber", x."sourcePriority", x.site,
    x."routeId", x."costCentre", x."stopShipFlag", x."releaseSourceStatus",
    x."sourceUpdatedAt"
  from jsonb_to_recordset(v_orders) as x(
    "orderNo" text, "dateReceived" timestamptz, "dateDue" timestamptz,
    "dateReleased" timestamptz, "sourceStatus" text, "sourceSubStatus" text,
    "customerCode" text, "customerName" text, "shipToName" text,
    "customerState" text, city text, "deliveryDesc" text,
    "clientSoNumber" text, "sourcePriority" integer, site text,
    "routeId" text, "costCentre" text, "stopShipFlag" text,
    "releaseSourceStatus" text, "sourceUpdatedAt" timestamptz
  );

  insert into public.source_release_order_lines(
    organization_id, sync_batch_id, order_no, line_number, product, client,
    qty_lcd, orig_ref3, group_code, product_name, source_updated_at
  )
  select v_organization_id, batch_id, x."orderNo", x."lineNumber", x.product,
    x.client, x."qtyLcd", x."origRef3", x."groupCode", x."productName",
    x."sourceUpdatedAt"
  from jsonb_to_recordset(v_release_lines) as x(
    "orderNo" text, "lineNumber" text, product text, client text,
    "qtyLcd" numeric, "origRef3" text, "groupCode" text,
    "productName" text, "sourceUpdatedAt" timestamptz
  );

  insert into public.source_workbank_items(
    organization_id, sync_batch_id, source_row_id, order_no, customer_code,
    customer_name, source_due_at, from_location, from_zone, to_location,
    from_pack_id, to_pack_id, source_priority, product_code,
    product_description, product_group, source_qty, source_weight,
    production_units, prints_per_garment, queue, task
  )
  select v_organization_id, batch_id, x.*
  from jsonb_to_recordset(v_workbank) as x(
    "sourceRowId" text, "orderNo" text, "customerCode" text,
    "customerName" text, "sourceDueAt" timestamptz, "fromLocation" text,
    "fromZone" text, "toLocation" text, "fromPackId" text, "toPackId" text,
    "sourcePriority" integer, "productCode" text, "productDescription" text,
    "productGroup" text, "sourceQty" numeric, "sourceWeight" numeric,
    "productionUnits" numeric, "printsPerGarment" numeric, queue text, task text
  );

  insert into public.source_stock_items(
    organization_id, sync_batch_id, product, pack_id, location, source_zone,
    source_timestamp, source_qty, source_weight, production_units
  )
  select v_organization_id, batch_id, x.*
  from jsonb_to_recordset(v_stock) as x(
    product text, "packId" text, location text, "sourceZone" text,
    "sourceTimestamp" timestamptz, "sourceQty" numeric,
    "sourceWeight" numeric, "productionUnits" numeric
  );

  insert into public.source_audit_events(
    organization_id, source_audit_id, order_no, username, from_zone, to_zone,
    from_location, to_location, product, from_pack_id, to_pack_id, source_qty,
    source_weight, production_units, event_at, raw_hash
  )
  select v_organization_id, x.*
  from jsonb_to_recordset(v_audit) as x(
    "sourceAuditId" text, "orderNo" text, username text, "fromZone" text,
    "toZone" text, "fromLocation" text, "toLocation" text, product text,
    "fromPackId" text, "toPackId" text, "sourceQty" numeric,
    "sourceWeight" numeric, "productionUnits" numeric, "eventAt" timestamptz,
    "rawHash" text
  )
  on conflict do nothing;
  get diagnostics audit_count = row_count;

  update public.sync_batches
  set status = 'completed', completed_at = now(),
      orders_count = jsonb_array_length(v_orders),
      release_line_count = jsonb_array_length(v_release_lines),
      workbank_count = jsonb_array_length(v_workbank),
      stock_count = jsonb_array_length(v_stock),
      audit_new_count = audit_count
  where id = batch_id;

  delete from public.sync_batches b
  where b.organization_id = v_organization_id and b.id <> batch_id
    and b.id not in (
      select k.id from public.sync_batches k
      where k.organization_id = v_organization_id
      order by k.created_at desc limit 99
    );

  return batch_id;
exception when others then
  raise;
end
$function$;
