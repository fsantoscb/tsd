alter table source_workbank_items add column if not exists prints_per_garment numeric(14,3);
create or replace view v_current_workbank as select w.* from source_workbank_items w join v_latest_completed_batch b on b.id=w.sync_batch_id;

create or replace function ingest_sync_batch(payload jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare batch_id uuid; audit_count integer;
begin
 insert into sync_batches(organization_id,status,connector_version) values((payload->>'organizationId')::uuid,'running',payload->>'connectorVersion') returning id into batch_id;
 begin
  insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,source_updated_at)
  select (payload->>'organizationId')::uuid,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x."sourceUpdatedAt" from jsonb_to_recordset(payload->'orders') x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,"sourceUpdatedAt" timestamptz);
  insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,prints_per_garment,queue,task)
  select (payload->>'organizationId')::uuid,batch_id,x.* from jsonb_to_recordset(payload->'workbank') x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"printsPerGarment" numeric,queue text,task text);
  insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_timestamp,source_qty,source_weight,production_units)
  select (payload->>'organizationId')::uuid,batch_id,x.* from jsonb_to_recordset(payload->'stock') x(product text,"packId" text,location text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);
  insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)
  select (payload->>'organizationId')::uuid,x.* from jsonb_to_recordset(payload->'auditEvents') x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text) on conflict do nothing;
  get diagnostics audit_count=row_count;
  update sync_batches set status='completed',completed_at=now(),orders_count=jsonb_array_length(payload->'orders'),workbank_count=jsonb_array_length(payload->'workbank'),stock_count=jsonb_array_length(payload->'stock'),audit_new_count=audit_count where id=batch_id;
 exception when others then update sync_batches set status='failed',error_message=left(sqlerrm,1000) where id=batch_id; raise;
 end;
 return batch_id;
end $$;
revoke all on function ingest_sync_batch(jsonb) from public,anon,authenticated;
grant execute on function ingest_sync_batch(jsonb) to service_role;

create or replace view v_up_operational_orders with (security_invoker=true) as
with stock as (select s.organization_id,regexp_replace(s.product,'^#','') order_no,count(*) box_count,sum(s.production_units) remaining_units,min(s.source_timestamp) last_movement from v_current_stock s where upper(coalesce(s.location,''))='UNDERPRINT' group by s.organization_id,regexp_replace(s.product,'^#','')),
putwall as (select organization_id,order_no,string_agg(distinct coalesce(nullif(to_location,''),from_location),', ' order by coalesce(nullif(to_location,''),from_location)) putwall_locations from v_current_workbank where upper(coalesce(from_zone,''))='PWL1' group by organization_id,order_no)
select s.organization_id,s.order_no,o.customer_name,o.delivery_desc screen,o.source_status status,o.source_priority priority,o.date_due,greatest(0,current_date-coalesce(o.date_due::date,current_date)) age_days,s.box_count item_count,s.remaining_units,s.last_movement,p.putwall_locations,'At UP' progress_label,null::numeric total_prints from stock s left join v_current_orders o on o.organization_id=s.organization_id and o.order_no=s.order_no left join putwall p on p.organization_id=s.organization_id and p.order_no=s.order_no;

create or replace view v_dtg_operational_orders with (security_invoker=true) as
select w.organization_id,w.order_no,max(coalesce(w.customer_name,o.customer_name)) customer_name,max(o.delivery_desc) screen,max(o.source_status) status,max(coalesce(w.source_priority,o.source_priority)) priority,min(coalesce(w.source_due_at,o.date_due)) date_due,greatest(0,current_date-coalesce(min(coalesce(w.source_due_at,o.date_due))::date,current_date)) age_days,count(*) item_count,count(*)::numeric remaining_units,null::timestamptz last_movement,string_agg(distinct coalesce(nullif(w.to_location,''),w.from_location),', ' order by coalesce(nullif(w.to_location,''),w.from_location)) putwall_locations,'At DTG' progress_label,sum(w.prints_per_garment) total_prints from v_current_workbank w left join v_current_orders o on o.organization_id=w.organization_id and o.order_no=w.order_no where upper(coalesce(w.from_zone,''))='DTGS' group by w.organization_id,w.order_no;

revoke all on v_up_operational_orders,v_dtg_operational_orders from anon,authenticated;
grant select on v_up_operational_orders,v_dtg_operational_orders to service_role;
