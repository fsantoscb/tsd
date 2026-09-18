alter table source_orders add column if not exists release_source_status text;
create or replace view v_current_orders as select o.* from source_orders o join v_latest_completed_batch b on b.id=o.sync_batch_id;
drop view if exists v_release_queue;
drop view if exists v_release_queue_all;

create or replace view v_release_queue_all as
with process_qty as(
 select organization_id,sync_batch_id,order_no,
  coalesce(sum(qty_lcd) filter(where upper(trim(group_code)) in('DTG_1','DTG_2')),0) dtg_qty,coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='UNDERPRINT'),0) underprint_qty,
  coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='UV PRINT'),0) uv_qty,coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='HATS'),0) hats_qty,
  coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='FINISHED'),0) finished_qty,coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='STICKERS'),0) stickers_qty,
  coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='VISUAL'),0) visual_qty,coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='PROD'),0) production_qty,
  coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='CUSTOM EMB'),0) custom_emb_qty,coalesce(sum(qty_lcd) filter(where upper(trim(group_code))='EYEWEAR'),0) eyewear_qty
 from v_current_release_order_lines group by organization_id,sync_batch_id,order_no
),evidence as(
 select o.*,b.completed_at snapshot_completed_at,coalesce(p.dtg_qty,0) dtg_qty,coalesce(p.underprint_qty,0) underprint_qty,coalesce(p.uv_qty,0) uv_qty,coalesce(p.hats_qty,0) hats_qty,coalesce(p.finished_qty,0) finished_qty,coalesce(p.stickers_qty,0) stickers_qty,coalesce(p.visual_qty,0) visual_qty,coalesce(p.production_qty,0) production_qty,coalesce(p.custom_emb_qty,0) custom_emb_qty,coalesce(p.eyewear_qty,0) eyewear_qty
 from v_current_orders o join v_latest_completed_batch b on b.id=o.sync_batch_id left join process_qty p on p.organization_id=o.organization_id and p.sync_batch_id=o.sync_batch_id and p.order_no=o.order_no
 where o.site='B' and o.order_no like '13%' and o.release_source_status='1' and o.date_due between now()-interval '30 days' and now()+interval '30 days'
),resolved as(
 select e.*,(dtg_qty+underprint_qty+uv_qty+hats_qty+finished_qty+stickers_qty+visual_qty+production_qty+custom_emb_qty+eyewear_qty) total_process_qty,
 array_remove(array[case when upper(trim(route_id))='NO' then 'ROUTE_BLOCKED' end,case when upper(trim(stop_ship_flag))='Y' then 'STOP_SHIP' end,case when custom_emb_qty>0 then 'CUSTOM_EMB' end],null)::text[] release_blockers from evidence e
)
select r.*,case when total_process_qty<=0 then 'ZERO_PRODUCTION_QTY' end diagnostic_status,
 case when route_id is null or trim(route_id)='' or stop_ship_flag is null or trim(stop_ship_flag)='' or date_due is null or release_source_status is null then 'UNKNOWN'
 when upper(trim(coalesce(cost_centre,'')))='NOTAPPRO' then 'NOT_APPROVED' when cardinality(release_blockers)>0 then 'BLOCKED'
 when date_due::date>((now() at time zone 'Australia/Brisbane')::date+7) then 'FUTURE_DUE' else 'ELIGIBLE' end release_status from resolved r;
create or replace view v_release_queue as select * from v_release_queue_all where total_process_qty>0;
grant select on v_release_queue_all,v_release_queue to authenticated,service_role;

create or replace function ingest_sync_batch(payload jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare batch_id uuid;audit_count integer;v_organization_id uuid:=(payload->>'organizationId')::uuid;
begin perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text,0));insert into sync_batches(organization_id,status,connector_version)values(v_organization_id,'running',payload->>'connectorVersion')returning id into batch_id;
 begin truncate table source_release_order_lines,source_orders,source_workbank_items,source_stock_items;
 insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,site,route_id,cost_centre,stop_ship_flag,release_source_status,source_updated_at)
 select v_organization_id,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x.site,x."routeId",x."costCentre",x."stopShipFlag",x."releaseSourceStatus",x."sourceUpdatedAt" from jsonb_to_recordset(payload->'orders')x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,site text,"routeId" text,"costCentre" text,"stopShipFlag" text,"releaseSourceStatus" text,"sourceUpdatedAt" timestamptz);
 insert into source_release_order_lines(organization_id,sync_batch_id,order_no,line_number,product,client,qty_lcd,orig_ref3,group_code,product_name,source_updated_at)select v_organization_id,batch_id,x."orderNo",x."lineNumber",x.product,x.client,x."qtyLcd",x."origRef3",x."groupCode",x."productName",x."sourceUpdatedAt" from jsonb_to_recordset(coalesce(payload->'releaseOrderLines','[]'::jsonb))x("orderNo" text,"lineNumber" text,product text,client text,"qtyLcd" numeric,"origRef3" text,"groupCode" text,"productName" text,"sourceUpdatedAt" timestamptz);
 insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,prints_per_garment,queue,task)select v_organization_id,batch_id,x.* from jsonb_to_recordset(payload->'workbank')x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"printsPerGarment" numeric,queue text,task text);
 insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_zone,source_timestamp,source_qty,source_weight,production_units)select v_organization_id,batch_id,x.* from jsonb_to_recordset(payload->'stock')x(product text,"packId" text,location text,"sourceZone" text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);
 insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)select v_organization_id,x.* from jsonb_to_recordset(payload->'auditEvents')x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text)on conflict do nothing;get diagnostics audit_count=row_count;
 update sync_batches set status='completed',completed_at=now(),orders_count=jsonb_array_length(payload->'orders'),release_line_count=jsonb_array_length(coalesce(payload->'releaseOrderLines','[]'::jsonb)),workbank_count=jsonb_array_length(payload->'workbank'),stock_count=jsonb_array_length(payload->'stock'),audit_new_count=audit_count where id=batch_id;
 delete from sync_batches b where b.organization_id=v_organization_id and b.id<>batch_id and b.id not in(select k.id from sync_batches k where k.organization_id=v_organization_id order by k.created_at desc limit 99);
 exception when others then update sync_batches set status='failed',error_message=left(sqlerrm,1000)where id=batch_id;raise;end;return batch_id;end $$;
alter function ingest_sync_batch(jsonb) set statement_timeout='120s';revoke all on function ingest_sync_batch(jsonb) from public,anon,authenticated;grant execute on function ingest_sync_batch(jsonb) to service_role;
