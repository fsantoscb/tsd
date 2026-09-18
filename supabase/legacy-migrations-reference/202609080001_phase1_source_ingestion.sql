create extension if not exists pgcrypto;

create table organizations (
  id uuid primary key default gen_random_uuid(), name text not null, timezone text not null default 'Australia/Brisbane',
  created_at timestamptz not null default now()
);
create table sync_batches (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id),
  started_at timestamptz not null default now(), completed_at timestamptz, status text not null check(status in ('running','completed','failed')),
  orders_count integer not null default 0, workbank_count integer not null default 0, stock_count integer not null default 0,
  audit_new_count integer not null default 0, error_message text, connector_version text, created_at timestamptz not null default now()
);
create table source_orders (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id), sync_batch_id uuid not null references sync_batches(id),
  order_no text not null, date_received timestamptz, date_due timestamptz, date_released timestamptz, source_status text, source_sub_status text,
  customer_code text, customer_name text, ship_to_name text, customer_state text, city text, delivery_desc text, client_so_number text,
  source_priority integer, source_updated_at timestamptz, created_at timestamptz not null default now(), unique(sync_batch_id,order_no)
);
create table source_workbank_items (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id), sync_batch_id uuid not null references sync_batches(id),
  source_row_id text, order_no text not null, customer_code text, customer_name text, source_due_at timestamptz, from_location text, from_zone text,
  to_location text, from_pack_id text, to_pack_id text, source_priority integer, product_code text, product_description text, product_group text,
  source_qty numeric(14,3), source_weight numeric(14,3), production_units numeric(14,3) not null, queue text not null, task text,
  created_at timestamptz not null default now()
);
create table source_stock_items (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id), sync_batch_id uuid not null references sync_batches(id),
  product text not null, pack_id text not null, location text not null, source_timestamp timestamptz, source_qty numeric(14,3),
  source_weight numeric(14,3), production_units numeric(14,3) not null, created_at timestamptz not null default now()
);
create table source_audit_events (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id), source_audit_id text,
  order_no text not null, username text, from_zone text, to_zone text, from_location text, to_location text, product text,
  from_pack_id text, to_pack_id text, source_qty numeric(14,3), source_weight numeric(14,3), production_units numeric(14,3) not null,
  event_at timestamptz not null, raw_hash text not null, imported_at timestamptz not null default now(),
  unique(organization_id,source_audit_id), unique(organization_id,raw_hash)
);
create table sync_agent_heartbeat (
  organization_id uuid not null references organizations(id), agent_id text not null, last_seen_at timestamptz not null default now(),
  version text not null, hostname text, status text not null, last_error text, primary key(organization_id,agent_id)
);
create index source_orders_order_no_idx on source_orders(order_no);
create index source_workbank_order_no_idx on source_workbank_items(order_no);
create index source_workbank_zone_idx on source_workbank_items(from_zone);
create index source_workbank_location_idx on source_workbank_items(from_location);
create index source_stock_product_idx on source_stock_items(product);
create index source_stock_location_idx on source_stock_items(location);
create index source_stock_pack_idx on source_stock_items(pack_id);
create index source_audit_order_idx on source_audit_events(order_no);
create index source_audit_event_idx on source_audit_events(event_at);
create index source_audit_from_location_idx on source_audit_events(from_location);
create index source_audit_to_location_idx on source_audit_events(to_location);

create view v_latest_completed_batch as
select distinct on (organization_id) * from sync_batches where status='completed' order by organization_id,completed_at desc;
create view v_current_orders as select o.* from source_orders o join v_latest_completed_batch b on b.id=o.sync_batch_id;
create view v_current_workbank as select w.* from source_workbank_items w join v_latest_completed_batch b on b.id=w.sync_batch_id;
create view v_current_stock as select s.* from source_stock_items s join v_latest_completed_batch b on b.id=s.sync_batch_id;

alter table organizations enable row level security;
alter table sync_batches enable row level security;
alter table source_orders enable row level security;
alter table source_workbank_items enable row level security;
alter table source_stock_items enable row level security;
alter table source_audit_events enable row level security;
alter table sync_agent_heartbeat enable row level security;

create or replace function ingest_sync_batch(payload jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare batch_id uuid; audit_count integer;
begin
 insert into sync_batches(organization_id,status,connector_version) values((payload->>'organizationId')::uuid,'running',payload->>'connectorVersion') returning id into batch_id;
 begin
  insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,source_updated_at)
  select (payload->>'organizationId')::uuid,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x."sourceUpdatedAt" from jsonb_to_recordset(payload->'orders') x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,"sourceUpdatedAt" timestamptz);
  insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,queue,task)
  select (payload->>'organizationId')::uuid,batch_id,x.* from jsonb_to_recordset(payload->'workbank') x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,queue text,task text);
  insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_timestamp,source_qty,source_weight,production_units)
  select (payload->>'organizationId')::uuid,batch_id,x.* from jsonb_to_recordset(payload->'stock') x(product text,"packId" text,location text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);
  insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)
  select (payload->>'organizationId')::uuid,x.* from jsonb_to_recordset(payload->'auditEvents') x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text)
  on conflict do nothing;
  get diagnostics audit_count=row_count;
  update sync_batches set status='completed',completed_at=now(),orders_count=jsonb_array_length(payload->'orders'),workbank_count=jsonb_array_length(payload->'workbank'),stock_count=jsonb_array_length(payload->'stock'),audit_new_count=audit_count where id=batch_id;
 exception when others then
  update sync_batches set status='failed',error_message=left(sqlerrm,1000) where id=batch_id; raise;
 end;
 return batch_id;
end $$;
revoke all on function ingest_sync_batch(jsonb) from public,anon,authenticated;
grant execute on function ingest_sync_batch(jsonb) to service_role;
