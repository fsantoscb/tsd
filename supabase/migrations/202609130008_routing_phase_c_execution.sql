alter table production_orders add constraint production_orders_organization_id_id_key unique(organization_id,id);
alter table production_orders
  add column product_id uuid,
  add column source_order_no text,
  add column source_routing_id uuid,
  add column routing_code_snapshot text,
  add column routing_name_snapshot text,
  add column routing_revision_snapshot integer,
  add column production_status text not null default 'UNROUTED',
  add column planned_quantity numeric(14,3),
  add column actual_quantity numeric(14,3) not null default 0,
  add constraint production_orders_product_fkey foreign key(organization_id,product_id)references products(organization_id,id),
  add constraint production_orders_status_check check(production_status in('UNROUTED','PLANNED','RELEASED','IN_PROGRESS','ON_HOLD','COMPLETED','CANCELLED')),
  add constraint production_orders_planned_quantity_check check(planned_quantity is null or planned_quantity>0),
  add constraint production_orders_actual_quantity_check check(actual_quantity>=0),
  add constraint production_orders_snapshot_complete_check check(
    (source_routing_id is null and routing_code_snapshot is null and routing_name_snapshot is null and routing_revision_snapshot is null and production_status='UNROUTED')
    or
    (source_routing_id is not null and routing_code_snapshot is not null and routing_name_snapshot is not null and routing_revision_snapshot is not null and production_status<>'UNROUTED')
  );

create table production_order_operations(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  production_order_id uuid not null,
  source_routing_operation_id uuid,
  source_operation_id uuid,
  sequence integer not null check(sequence>0),
  operation_code_snapshot text not null,
  operation_name_snapshot text not null,
  work_center_code_snapshot text,
  work_center_name_snapshot text,
  required boolean not null default true,
  setup_minutes_snapshot numeric(12,3),
  run_rate_snapshot numeric(14,3),
  queue_minutes_snapshot numeric(12,3),
  instructions_snapshot text,
  status text not null default 'PENDING' check(status in('PENDING','READY','IN_PROGRESS','ON_HOLD','COMPLETED','SKIPPED')),
  planned_quantity numeric(14,3) check(planned_quantity is null or planned_quantity>0),
  actual_quantity numeric(14,3) not null default 0 check(actual_quantity>=0),
  planned_date date,
  planned_shift_id uuid references shift_templates(id),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(production_order_id,sequence),
  unique(organization_id,id),
  foreign key(organization_id,production_order_id)references production_orders(organization_id,id)on delete cascade
);
create index production_order_operations_progress_idx on production_order_operations(organization_id,production_order_id,sequence,status);
create index production_orders_execution_idx on production_orders(organization_id,production_status,planned_date,planner_priority);

create or replace function prepare_production_order_snapshot()returns trigger language plpgsql security definer set search_path=public as $$
declare p products%rowtype;r routings%rowtype;
begin
  if tg_op='UPDATE'and old.source_routing_id is not null and(new.product_id,new.source_routing_id,new.routing_code_snapshot,new.routing_name_snapshot,new.routing_revision_snapshot)is distinct from(old.product_id,old.source_routing_id,old.routing_code_snapshot,old.routing_name_snapshot,old.routing_revision_snapshot)then
    raise exception 'Production order routing snapshot is immutable';
  end if;
  if new.product_id is null and new.source_routing_id is null then return new;end if;
  if new.product_id is null then raise exception 'A product is required for routed production orders';end if;
  select * into p from products where id=new.product_id and organization_id=new.organization_id and active;
  if p.id is null then raise exception 'Invalid or inactive product';end if;
  select * into r from routings where id=coalesce(new.source_routing_id,p.default_routing_id)and organization_id=new.organization_id and status='ACTIVE'and active and(effective_from is null or effective_from<=current_date)and(effective_to is null or effective_to>=current_date);
  if r.id is null then raise exception 'Product requires an active effective routing';end if;
  if not exists(select 1 from routing_operations where routing_id=r.id and organization_id=r.organization_id)then raise exception 'Routing has no operations';end if;
  new.source_order_no:=coalesce(new.source_order_no,new.order_no);
  new.source_routing_id:=r.id;
  new.routing_code_snapshot:=r.code;
  new.routing_name_snapshot:=r.name;
  new.routing_revision_snapshot:=r.revision;
  if new.production_status='UNROUTED'then new.production_status:='PLANNED';end if;
  return new;
end$$;
create trigger prepare_production_order_snapshot_change before insert or update of product_id,source_routing_id on production_orders for each row execute function prepare_production_order_snapshot();

create or replace function copy_production_order_operations()returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.source_routing_id is null or exists(select 1 from production_order_operations where production_order_id=new.id)then return new;end if;
  insert into production_order_operations(organization_id,production_order_id,source_routing_operation_id,source_operation_id,sequence,operation_code_snapshot,operation_name_snapshot,work_center_code_snapshot,work_center_name_snapshot,required,setup_minutes_snapshot,run_rate_snapshot,queue_minutes_snapshot,instructions_snapshot,planned_quantity,planned_date,planned_shift_id)
  select new.organization_id,new.id,ro.id,o.id,ro.sequence,o.code,o.name,w.code,w.name,ro.required,ro.setup_minutes,ro.run_rate,ro.queue_minutes,ro.instructions,new.planned_quantity,new.planned_date,new.planned_shift_id
  from routing_operations ro join operations o on o.id=ro.operation_id and o.organization_id=ro.organization_id left join work_centers w on w.id=ro.work_center_id and w.organization_id=ro.organization_id
  where ro.routing_id=new.source_routing_id and ro.organization_id=new.organization_id order by ro.sequence;
  return new;
end$$;
create trigger copy_production_order_operations_change after insert or update of product_id,source_routing_id on production_orders for each row execute function copy_production_order_operations();

create or replace function protect_production_operation_snapshot()returns trigger language plpgsql set search_path=public as $$
begin
  if tg_op='DELETE'then raise exception 'Production operation snapshots cannot be deleted';end if;
  if(new.organization_id,new.production_order_id,new.source_routing_operation_id,new.source_operation_id,new.sequence,new.operation_code_snapshot,new.operation_name_snapshot,new.work_center_code_snapshot,new.work_center_name_snapshot,new.required,new.setup_minutes_snapshot,new.run_rate_snapshot,new.queue_minutes_snapshot,new.instructions_snapshot)is distinct from(old.organization_id,old.production_order_id,old.source_routing_operation_id,old.source_operation_id,old.sequence,old.operation_code_snapshot,old.operation_name_snapshot,old.work_center_code_snapshot,old.work_center_name_snapshot,old.required,old.setup_minutes_snapshot,old.run_rate_snapshot,old.queue_minutes_snapshot,old.instructions_snapshot)then raise exception 'Production operation definition snapshot is immutable';end if;
  if new.status<>old.status and not((old.status='PENDING'and new.status in('READY','IN_PROGRESS','SKIPPED'))or(old.status='READY'and new.status in('IN_PROGRESS','SKIPPED'))or(old.status='IN_PROGRESS'and new.status in('ON_HOLD','COMPLETED'))or(old.status='ON_HOLD'and new.status in('IN_PROGRESS','SKIPPED')))then raise exception 'Invalid production operation status transition';end if;
  if new.status='IN_PROGRESS'and old.status<>'IN_PROGRESS'then new.started_at:=coalesce(new.started_at,now());end if;
  if new.status in('COMPLETED','SKIPPED')and old.status not in('COMPLETED','SKIPPED')then new.completed_at:=coalesce(new.completed_at,now());end if;
  new.updated_at:=now();return new;
end$$;
create trigger protect_production_operation_snapshot_change before update or delete on production_order_operations for each row execute function protect_production_operation_snapshot();

alter table production_order_operations enable row level security;
create policy production_orders_execution_read on production_orders for select to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_orders.organization_id and m.active));
create policy production_orders_execution_manage on production_orders for all to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_orders.organization_id and m.active and m.role in('admin','supervisor')))with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_orders.organization_id and m.active and m.role in('admin','supervisor')));
create policy production_order_operations_read on production_order_operations for select to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_order_operations.organization_id and m.active));
create policy production_order_operations_manage on production_order_operations for all to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_order_operations.organization_id and m.active and m.role in('admin','supervisor')))with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_order_operations.organization_id and m.active and m.role in('admin','supervisor')));
create policy production_order_operations_execute on production_order_operations for update to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_order_operations.organization_id and m.active and m.role='operator'))with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=production_order_operations.organization_id and m.active and m.role='operator'));
grant select,insert,update on production_orders to authenticated;
grant select,insert,update,delete on production_order_operations to authenticated;
grant all on production_order_operations to service_role;

create or replace view v_production_order_execution with(security_invoker=true)as
select po.organization_id,po.id production_order_id,po.order_no,po.source_order_no,po.product_id,po.routing_code_snapshot,po.routing_name_snapshot,po.routing_revision_snapshot,po.production_status,po.planned_quantity,po.actual_quantity,po.planned_date,po.planned_shift_id,po.planner_priority,
  current_op.id current_operation_id,current_op.sequence current_operation_sequence,current_op.operation_code_snapshot current_operation_code,current_op.operation_name_snapshot current_operation_name,
  next_op.id next_operation_id,next_op.sequence next_operation_sequence,next_op.operation_code_snapshot next_operation_code,next_op.operation_name_snapshot next_operation_name,
  last_op.id last_completed_operation_id,last_op.sequence last_completed_operation_sequence,last_op.operation_code_snapshot last_completed_operation_code,last_op.operation_name_snapshot last_completed_operation_name
from production_orders po
left join lateral(select x.* from production_order_operations x where x.production_order_id=po.id and x.status in('IN_PROGRESS','READY','PENDING','ON_HOLD')order by case x.status when'IN_PROGRESS'then 0 when'ON_HOLD'then 1 when'READY'then 2 else 3 end,x.sequence limit 1)current_op on true
left join lateral(select x.* from production_order_operations x where x.production_order_id=po.id and x.status in('READY','PENDING')and(current_op.sequence is null or x.sequence>current_op.sequence)order by x.sequence limit 1)next_op on true
left join lateral(select x.* from production_order_operations x where x.production_order_id=po.id and x.status in('COMPLETED','SKIPPED')order by x.sequence desc limit 1)last_op on true;
grant select on v_production_order_execution to authenticated,service_role;

create trigger production_orders_execution_audit after insert or update or delete on production_orders for each row execute function maintenance_audit_change();
create trigger production_order_operations_audit after insert or update or delete on production_order_operations for each row execute function maintenance_audit_change();

