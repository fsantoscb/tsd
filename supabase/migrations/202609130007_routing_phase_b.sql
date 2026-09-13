create table if not exists routings(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  code text not null check(code~'^[A-Z0-9_]+$'),
  name text not null,
  revision integer not null default 1 check(revision>0),
  status text not null default 'DRAFT' check(status in('DRAFT','ACTIVE','INACTIVE')),
  effective_from date,
  effective_to date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,code,revision),
  unique(organization_id,id),
  check(effective_to is null or effective_from is null or effective_to>=effective_from)
);

create table if not exists routing_operations(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  routing_id uuid not null,
  sequence integer not null check(sequence>0),
  operation_id uuid not null,
  work_center_id uuid,
  required boolean not null default true,
  setup_minutes numeric(12,3) check(setup_minutes is null or setup_minutes>=0),
  run_rate numeric(14,3) check(run_rate is null or run_rate>0),
  queue_minutes numeric(12,3) check(queue_minutes is null or queue_minutes>=0),
  capacity_profile_id uuid,
  instructions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(routing_id,sequence),
  foreign key(organization_id,routing_id)references routings(organization_id,id)on delete cascade,
  foreign key(organization_id,operation_id)references operations(organization_id,id),
  foreign key(organization_id,work_center_id)references work_centers(organization_id,id)
);

alter table operations add constraint operations_organization_id_id_key unique(organization_id,id);
alter table products drop constraint if exists products_default_routing_id_fkey;
alter table products add constraint products_default_routing_organization_fkey foreign key(organization_id,default_routing_id)references routings(organization_id,id);
create index if not exists routing_operations_routing_idx on routing_operations(organization_id,routing_id,sequence);
create index if not exists products_default_routing_idx on products(organization_id,default_routing_id);

do $$
declare org uuid; route uuid;
begin
  for org in select id from organizations loop
    insert into routings(organization_id,code,name,revision,status,effective_from)
    values(org,'DTG_STANDARD','DTG Standard',1,'ACTIVE',current_date)
    on conflict(organization_id,code,revision)do update set name=excluded.name
    returning id into route;
    insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id)
    select org,route,v.seq,o.id,w.id from(values(10,'PICKING',null),(20,'DTG_PRINT','DTG'),(30,'PUTWALL',null),(40,'DISPATCH','DISPATCH'))v(seq,op,wc)
    join operations o on o.organization_id=org and o.code=v.op
    left join work_centers w on w.organization_id=org and w.code=v.wc
    on conflict(routing_id,sequence)do nothing;

    insert into routings(organization_id,code,name,revision,status,effective_from)
    values(org,'UNDERPRINT_STANDARD','Underprint Standard',1,'ACTIVE',current_date)
    on conflict(organization_id,code,revision)do update set name=excluded.name
    returning id into route;
    insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id)
    select org,route,v.seq,o.id,w.id from(values(10,'PICKING',null),(20,'UNDERPRINT','UNDERPRINT'),(30,'DISPATCH','DISPATCH'))v(seq,op,wc)
    join operations o on o.organization_id=org and o.code=v.op
    left join work_centers w on w.organization_id=org and w.code=v.wc
    on conflict(routing_id,sequence)do nothing;

    insert into routings(organization_id,code,name,revision,status,effective_from)
    values(org,'SCREEN_PRINT_STANDARD','Screen Print Standard',1,'ACTIVE',current_date)
    on conflict(organization_id,code,revision)do update set name=excluded.name
    returning id into route;
    insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id,required)
    select org,route,v.seq,o.id,w.id,v.required from(values(10,'PICKING',null,true),(20,'SCREEN_PRINT','SCREEN_PRINT',true),(30,'QC',null,false),(40,'PACKING',null,false),(50,'DISPATCH','DISPATCH',true))v(seq,op,wc,required)
    join operations o on o.organization_id=org and o.code=v.op
    left join work_centers w on w.organization_id=org and w.code=v.wc
    on conflict(routing_id,sequence)do nothing;
  end loop;
end$$;

alter table routings enable row level security;
alter table routing_operations enable row level security;
create policy routings_read on routings for select to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routings.organization_id and m.active));
create policy routings_manage on routings for all to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routings.organization_id and m.active and m.role in('admin','supervisor')))with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routings.organization_id and m.active and m.role in('admin','supervisor')));
create policy routing_operations_read on routing_operations for select to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routing_operations.organization_id and m.active));
create policy routing_operations_manage on routing_operations for all to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routing_operations.organization_id and m.active and m.role in('admin','supervisor')))with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid()and m.organization_id=routing_operations.organization_id and m.active and m.role in('admin','supervisor')));
grant select on routings,routing_operations to authenticated;
grant insert,update,delete on routings,routing_operations to authenticated;
grant all on routings,routing_operations to service_role;

create or replace view v_routing_master with(security_invoker=true)as
select r.organization_id,r.id routing_id,r.code,r.name,r.revision,r.status,r.effective_from,r.effective_to,r.active,
  ro.id routing_operation_id,ro.sequence,o.code operation_code,o.name operation_name,w.code work_center_code,
  ro.required,ro.setup_minutes,ro.run_rate,ro.queue_minutes,ro.instructions
from routings r left join routing_operations ro on ro.routing_id=r.id and ro.organization_id=r.organization_id
left join operations o on o.id=ro.operation_id and o.organization_id=r.organization_id
left join work_centers w on w.id=ro.work_center_id and w.organization_id=r.organization_id;
grant select on v_routing_master to authenticated,service_role;

drop trigger if exists routing_master_audit_change on routings;
create trigger routing_master_audit_change after insert or update or delete on routings for each row execute function maintenance_audit_change();
drop trigger if exists routing_operations_audit_change on routing_operations;
create trigger routing_operations_audit_change after insert or update or delete on routing_operations for each row execute function maintenance_audit_change();
drop trigger if exists product_routing_assignment_audit_change on products;
create trigger product_routing_assignment_audit_change after update of default_routing_id on products for each row when(old.default_routing_id is distinct from new.default_routing_id)execute function maintenance_audit_change();
