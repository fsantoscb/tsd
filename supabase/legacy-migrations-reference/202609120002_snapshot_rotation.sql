-- Keep one transactional source snapshot instead of accumulating a full copy
-- on every connector run. TRUNCATE is transactional in PostgreSQL: readers keep
-- seeing the previous committed snapshot until the replacement batch commits.

create or replace function ingest_sync_batch(payload jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
  batch_id uuid;
  audit_count integer;
  v_organization_id uuid := (payload->>'organizationId')::uuid;
begin
  -- One full snapshot writer at a time for each organization.
  perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text, 0));

  insert into sync_batches(organization_id,status,connector_version)
  values(v_organization_id,'running',payload->>'connectorVersion')
  returning id into batch_id;

  begin
    -- These tables are replaceable snapshots. Audit remains append-only.
    truncate table source_orders,source_workbank_items,source_stock_items;

    insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,source_updated_at)
    select v_organization_id,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x."sourceUpdatedAt"
    from jsonb_to_recordset(payload->'orders') x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,"sourceUpdatedAt" timestamptz);

    insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,prints_per_garment,queue,task)
    select v_organization_id,batch_id,x.*
    from jsonb_to_recordset(payload->'workbank') x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"printsPerGarment" numeric,queue text,task text);

    insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_timestamp,source_qty,source_weight,production_units)
    select v_organization_id,batch_id,x.*
    from jsonb_to_recordset(payload->'stock') x(product text,"packId" text,location text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);

    insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)
    select v_organization_id,x.*
    from jsonb_to_recordset(payload->'auditEvents') x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text)
    on conflict do nothing;
    get diagnostics audit_count=row_count;

    update sync_batches set
      status='completed',completed_at=now(),
      orders_count=jsonb_array_length(payload->'orders'),
      workbank_count=jsonb_array_length(payload->'workbank'),
      stock_count=jsonb_array_length(payload->'stock'),
      audit_new_count=audit_count
    where id=batch_id;

    -- Batch rows are lightweight metadata; keep the latest 100 for diagnosis.
    delete from sync_batches b
    where b.organization_id=v_organization_id
      and b.id<>batch_id
      and b.id not in (
        select k.id from sync_batches k
        where k.organization_id=v_organization_id
        order by k.created_at desc
        limit 99
      );
  exception when others then
    update sync_batches set status='failed',error_message=left(sqlerrm,1000)
    where id=batch_id;
    raise;
  end;

  return batch_id;
end $$;

revoke all on function ingest_sync_batch(jsonb) from public,anon,authenticated;
grant execute on function ingest_sync_batch(jsonb) to service_role;

-- Immediate recovery: old snapshot copies are disposable and will be replaced
-- by the next Oracle sync. Audit history and app-owned data are not removed.
truncate table source_orders,source_workbank_items,source_stock_items;

delete from sync_batches b
where b.id not in (
  select k.id from sync_batches k
  order by k.created_at desc
  limit 100
);
