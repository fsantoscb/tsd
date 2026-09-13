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

alter table operations add constraint operations_organization_id_id_key unique(organization_id,id);

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

create or replace function protect_routing_revision()returns trigger language plpgsql set search_path=public as $$begin
  if tg_op='DELETE' and old.status<>'DRAFT' then raise exception 'Only draft routing revisions may be deleted';end if;
  if tg_op='UPDATE' and old.status='ACTIVE' and (new.code,new.name,new.revision,new.effective_from,new.organization_id)is distinct from(old.code,old.name,old.revision,old.effective_from,old.organization_id)then raise exception 'Active routing revisions are immutable';end if;
  if tg_op='UPDATE' and old.status='INACTIVE' and new is distinct from old then raise exception 'Inactive routing revisions are immutable';end if;
  if tg_op='UPDATE' and not((old.status=new.status)or(old.status='DRAFT'and new.status in('ACTIVE','INACTIVE'))or(old.status='ACTIVE'and new.status='INACTIVE'))then raise exception 'Invalid routing status transition';end if;
  return case when tg_op='DELETE'then old else new end;
end$$;
drop trigger if exists protect_routing_revision_change on routings;
create trigger protect_routing_revision_change before update or delete on routings for each row execute function protect_routing_revision();

create or replace function protect_routing_operation_change()returns trigger language plpgsql set search_path=public as $$declare route_status text;operation_active boolean;begin
  select status into route_status from routings where id=coalesce(new.routing_id,old.routing_id)and organization_id=coalesce(new.organization_id,old.organization_id);
  if route_status is distinct from 'DRAFT'then raise exception 'Routing operations may only change on draft revisions';end if;
  if tg_op<>'DELETE'then select active into operation_active from operations where id=new.operation_id and organization_id=new.organization_id;if operation_active is distinct from true then raise exception 'Only active canonical operations may be added';end if;end if;
  return case when tg_op='DELETE'then old else new end;
end$$;
drop trigger if exists protect_routing_operation_change on routing_operations;
create trigger protect_routing_operation_change before insert or update or delete on routing_operations for each row execute function protect_routing_operation_change();

create or replace function validate_product_default_routing()returns trigger language plpgsql set search_path=public as $$begin
  if new.default_routing_id is not null and not exists(select 1 from routings r where r.id=new.default_routing_id and r.organization_id=new.organization_id and r.status='ACTIVE'and r.active and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date))then raise exception 'Product default routing must be active, effective and in the same organization';end if;return new;
end$$;
drop trigger if exists validate_product_default_routing_change on products;
create trigger validate_product_default_routing_change before insert or update of default_routing_id,organization_id on products for each row execute function validate_product_default_routing();

create or replace function protect_active_operation_deactivation()returns trigger language plpgsql set search_path=public as $$begin
  if old.active and not new.active and exists(select 1 from routing_operations ro join routings r on r.id=ro.routing_id and r.organization_id=ro.organization_id where ro.operation_id=old.id and ro.organization_id=old.organization_id and r.status='ACTIVE')then raise exception 'Operation is used by an active routing revision';end if;return new;
end$$;
drop trigger if exists protect_active_operation_deactivation_change on operations;
create trigger protect_active_operation_deactivation_change before update of active on operations for each row execute function protect_active_operation_deactivation();

create or replace function clone_routing_revision(p_routing_id uuid)returns uuid language plpgsql set search_path=public as $$declare source routings%rowtype;new_id uuid;new_revision integer;begin
  select * into strict source from routings where id=p_routing_id;
  perform pg_advisory_xact_lock(hashtext(source.organization_id::text||source.code));
  select coalesce(max(revision),0)+1 into new_revision from routings where organization_id=source.organization_id and code=source.code;
  insert into routings(organization_id,code,name,revision,status,active)values(source.organization_id,source.code,source.name,new_revision,'DRAFT',true)returning id into new_id;
  insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions)
  select organization_id,new_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions from routing_operations where routing_id=p_routing_id order by sequence;
  return new_id;
end$$;
grant execute on function clone_routing_revision(uuid)to authenticated,service_role;

create or replace function move_routing_operation(p_operation_id uuid,p_direction text)returns void language plpgsql set search_path=public as $$declare route uuid;ids uuid[];position integer;swap uuid;i integer;begin
  if p_direction not in('up','down')then raise exception 'Direction must be up or down';end if;
  select routing_id into strict route from routing_operations where id=p_operation_id;
  select array_agg(id order by sequence)into ids from routing_operations where routing_id=route;
  position:=array_position(ids,p_operation_id);if position is null or(p_direction='up'and position=1)or(p_direction='down'and position=array_length(ids,1))then return;end if;
  i:=case when p_direction='up'then position-1 else position+1 end;swap:=ids[i];ids[i]:=ids[position];ids[position]:=swap;
  update routing_operations set sequence=sequence+100000 where routing_id=route;
  for i in 1..array_length(ids,1)loop update routing_operations set sequence=i*10 where id=ids[i];end loop;
end$$;
grant execute on function move_routing_operation(uuid,text)to authenticated,service_role;
