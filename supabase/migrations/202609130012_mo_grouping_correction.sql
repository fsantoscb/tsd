-- Manufacturing Order grouping correction.
-- Authoritative rule: ONE SO + ONE ROUTING = ONE MO.

alter table production_orders drop constraint if exists production_orders_organization_id_order_no_key;
create unique index if not exists production_orders_legacy_order_key
  on production_orders(organization_id,order_no) where source_routing_id is null;

alter table production_orders
  add column if not exists mo_number text,
  add column if not exists source_system text not null default 'ORACLE_WMS',
  add column if not exists split_number integer not null default 1 check(split_number>0),
  add constraint production_orders_mo_number_key unique(organization_id,mo_number),
  add constraint production_orders_so_routing_split_key unique(organization_id,source_system,source_order_no,source_routing_id,split_number),
  add constraint production_orders_mo_identity_check check(
    source_routing_id is null or nullif(trim(source_order_no),'') is not null
  );

create table production_demand_lines(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  source_system text not null,
  source_order_no text not null check(nullif(trim(source_order_no),'') is not null),
  source_order_line_id text not null check(nullif(trim(source_order_line_id),'') is not null),
  product_id uuid,
  routing_id uuid,
  routing_revision_id uuid,
  source_product_code text,
  source_description text,
  quantity numeric(14,3) not null check(quantity>0),
  due_date timestamptz,
  source_priority integer,
  planner_priority integer,
  status text not null default 'READY' check(status in('READY','GROUPED','CANCELLED','EXCEPTION')),
  resolution_status text not null default 'RESOLVED' check(resolution_status in('RESOLVED','PRODUCT_UNMAPPED','ROUTING_UNMAPPED','ROUTING_INACTIVE','INVALID_QUANTITY')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id,source_system,source_order_no,source_order_line_id),
  unique(organization_id,id),
  foreign key(organization_id,product_id) references products(organization_id,id),
  foreign key(organization_id,routing_id) references routings(organization_id,id),
  foreign key(organization_id,routing_revision_id) references routings(organization_id,id),
  check((resolution_status='RESOLVED' and product_id is not null and routing_revision_id is not null) or resolution_status<>'RESOLVED')
);

create table manufacturing_order_lines(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  manufacturing_order_id uuid not null,
  production_demand_line_id uuid,
  source_order_no text not null,
  source_order_line_id text not null,
  product_id uuid,
  routing_revision_id uuid not null,
  planned_quantity numeric(14,3) not null check(planned_quantity>0),
  actual_quantity numeric(14,3) not null default 0 check(actual_quantity>=0),
  sequence integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(manufacturing_order_id,source_order_line_id),
  unique(production_demand_line_id),
  foreign key(organization_id,manufacturing_order_id) references production_orders(organization_id,id) on delete restrict,
  foreign key(organization_id,production_demand_line_id) references production_demand_lines(organization_id,id),
  foreign key(organization_id,product_id) references products(organization_id,id),
  foreign key(organization_id,routing_revision_id) references routings(organization_id,id)
);

create table production_demand_exceptions(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  production_demand_line_id uuid not null,
  exception_type text not null check(exception_type in('PRODUCT_UNMAPPED','ROUTING_UNMAPPED','ROUTING_INACTIVE','INVALID_QUANTITY')),
  description text not null,
  status text not null default 'OPEN' check(status in('OPEN','RESOLVED','DISMISSED')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique(production_demand_line_id,exception_type,status),
  foreign key(organization_id,production_demand_line_id) references production_demand_lines(organization_id,id) on delete cascade
);

alter table production_routing_exceptions drop constraint production_routing_exceptions_exception_type_check;
alter table production_routing_exceptions add constraint production_routing_exceptions_exception_type_check check(exception_type in(
  'SKIPPED_OPERATION','OUT_OF_SEQUENCE','UNKNOWN_SOURCE_STAGE','UNEXPECTED_OPERATION','ROUTING_MISMATCH','SOURCE_QUANTITY_CHANGE','SOURCE_ORDER_CANCELLED'
));

create or replace function enforce_manufacturing_order_line_boundary() returns trigger language plpgsql set search_path=public as $$
declare parent production_orders%rowtype; demand production_demand_lines%rowtype;
begin
  select * into strict parent from production_orders where id=new.manufacturing_order_id and organization_id=new.organization_id;
  if parent.source_order_no is distinct from new.source_order_no then raise exception 'MO line Sales Order must equal parent Sales Order';end if;
  if parent.source_routing_id is distinct from new.routing_revision_id then raise exception 'MO line Routing must equal parent Routing';end if;
  if new.production_demand_line_id is not null then
    select * into strict demand from production_demand_lines where id=new.production_demand_line_id and organization_id=new.organization_id;
    if (demand.source_order_no,demand.source_order_line_id,demand.product_id,demand.routing_revision_id) is distinct from
       (new.source_order_no,new.source_order_line_id,new.product_id,new.routing_revision_id) then
      raise exception 'MO line does not match its demand line';
    end if;
  end if;
  new.updated_at:=now();return new;
end$$;
create trigger enforce_manufacturing_order_line_boundary_change before insert or update on manufacturing_order_lines
for each row execute function enforce_manufacturing_order_line_boundary();

create or replace function recalculate_manufacturing_order_quantity() returns trigger language plpgsql set search_path=public as $$
declare mo_id uuid:=coalesce(new.manufacturing_order_id,old.manufacturing_order_id);total numeric(14,3);
begin
  select sum(planned_quantity) into total from manufacturing_order_lines where manufacturing_order_id=mo_id;
  update production_orders set planned_quantity=total,updated_at=now() where id=mo_id;
  update production_order_operations set planned_quantity=total,updated_at=now()
    where production_order_id=mo_id and status in('PENDING','READY');
  return coalesce(new,old);
end$$;
create trigger recalculate_manufacturing_order_quantity_change after insert or update of planned_quantity or delete on manufacturing_order_lines
for each row execute function recalculate_manufacturing_order_quantity();

create or replace function create_manufacturing_orders(p_organization_id uuid,p_source_system text default 'ORACLE_WMS')
returns table(out_manufacturing_order_id uuid,out_mo_number text,out_source_order_no text,out_routing_id uuid,out_planned_quantity numeric)
language plpgsql security definer set search_path=public as $$
declare g record;mo uuid;number text;
begin
  for g in
    select d.source_order_no,d.routing_revision_id,count(*) line_count,sum(d.quantity)::numeric(14,3) qty,
      min(d.due_date)::date planned_date,min(d.planner_priority) planner_priority,r.code routing_code
    from production_demand_lines d join routings r on r.id=d.routing_revision_id and r.organization_id=d.organization_id
    where d.organization_id=p_organization_id and d.source_system=p_source_system and d.status='READY' and d.resolution_status='RESOLVED'
    group by d.source_order_no,d.routing_revision_id,r.code order by d.source_order_no,r.code
  loop
    number:='MO-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code||'-1';
    insert into production_orders(organization_id,order_no,mo_number,source_system,source_order_no,source_routing_id,planned_quantity,planned_date,planner_priority,split_number)
    values(p_organization_id,number,number,p_source_system,g.source_order_no,g.routing_revision_id,g.qty,g.planned_date,g.planner_priority,1)
    on conflict on constraint production_orders_so_routing_split_key do update set updated_at=now()
    returning id into mo;
    insert into manufacturing_order_lines(organization_id,manufacturing_order_id,production_demand_line_id,source_order_no,source_order_line_id,product_id,routing_revision_id,planned_quantity,sequence)
    select d.organization_id,mo,d.id,d.source_order_no,d.source_order_line_id,d.product_id,d.routing_revision_id,d.quantity,
      row_number()over(order by d.source_order_line_id)::integer
    from production_demand_lines d where d.organization_id=p_organization_id and d.source_system=p_source_system
      and d.source_order_no=g.source_order_no and d.routing_revision_id=g.routing_revision_id and d.status='READY' and d.resolution_status='RESOLVED'
    on conflict(production_demand_line_id) do nothing;
    update production_demand_lines set status='GROUPED',updated_at=now() where organization_id=p_organization_id and source_system=p_source_system
      and source_order_no=g.source_order_no and routing_revision_id=g.routing_revision_id and status='READY';
    return query select po.id,po.mo_number,po.source_order_no,po.source_routing_id,po.planned_quantity from production_orders po where po.id=mo;
  end loop;
end$$;

create or replace function update_manufacturing_order_line_quantity(p_organization_id uuid,p_source_system text,p_source_order_no text,p_source_order_line_id text,p_new_quantity numeric)
returns text language plpgsql security definer set search_path=public as $$
declare d production_demand_lines%rowtype;line manufacturing_order_lines%rowtype;po production_orders%rowtype;
begin
  if p_new_quantity<=0 then raise exception 'Quantity must be positive';end if;
  select * into strict d from production_demand_lines where organization_id=p_organization_id and source_system=p_source_system and source_order_no=p_source_order_no and source_order_line_id=p_source_order_line_id for update;
  select * into line from manufacturing_order_lines where production_demand_line_id=d.id;
  if line.id is null then update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;return 'DEMAND_UPDATED';end if;
  select * into strict po from production_orders where id=line.manufacturing_order_id for update;
  if po.production_status in('UNROUTED','PLANNED','RELEASED') then
    update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;
    update manufacturing_order_lines set planned_quantity=p_new_quantity where id=line.id;
    return 'MO_UPDATED';
  end if;
  insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
  values(p_organization_id,po.id,'SOURCE_QUANTITY_CHANGE',format('Source quantity changed from %s to %s (delta %s)',d.quantity,p_new_quantity,p_new_quantity-d.quantity),'ORDER_LINE',p_source_order_no||':'||p_source_order_line_id);
  return 'EXCEPTION_CREATED';
end$$;

create or replace view v_manufacturing_order_product_mix with(security_invoker=true) as
select po.organization_id,po.id manufacturing_order_id,po.mo_number,po.source_order_no,po.routing_code_snapshot,
  l.product_id,p.sku,p.description,sum(l.planned_quantity)::numeric(14,3) planned_quantity,
  round(sum(l.planned_quantity)/nullif(po.planned_quantity,0)*100,1) mix_percent
from production_orders po join manufacturing_order_lines l on l.manufacturing_order_id=po.id
left join products p on p.id=l.product_id and p.organization_id=l.organization_id
group by po.organization_id,po.id,po.mo_number,po.source_order_no,po.routing_code_snapshot,l.product_id,p.sku,p.description,po.planned_quantity;

create or replace view v_mo_grouping_reconciliation with(security_invoker=true) as
with expected as(select x.organization_id,x.source_system,x.source_order_no,count(*) source_line_count,count(distinct x.routing_revision_id) filter(where x.resolution_status='RESOLVED') expected_mo_count,
 jsonb_object_agg(coalesce(r.code,resolution_status),quantity_by_route) expected_quantity_by_routing
 from(select d.organization_id,d.source_system,d.source_order_no,d.routing_revision_id,d.resolution_status,sum(d.quantity) quantity_by_route from production_demand_lines d group by d.organization_id,d.source_system,d.source_order_no,d.routing_revision_id,d.resolution_status)x
 left join routings r on r.id=x.routing_revision_id group by x.organization_id,x.source_system,x.source_order_no),
actual as(select organization_id,source_system,source_order_no,count(*) actual_mo_count,sum(planned_quantity) actual_quantity from production_orders where source_routing_id is not null group by organization_id,source_system,source_order_no)
select e.*,coalesce(a.actual_mo_count,0) actual_mo_count,e.expected_mo_count-coalesce(a.actual_mo_count,0) mo_difference,
 coalesce(a.actual_quantity,0) actual_quantity from expected e left join actual a using(organization_id,source_system,source_order_no);

do $$declare t text;begin foreach t in array array['production_demand_lines','manufacturing_order_lines','production_demand_exceptions'] loop
 execute format('alter table %I enable row level security',t);
 execute format('create policy %I on %I for select to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=%I.organization_id and m.active))',t||'_read',t,t);
 execute format('create policy %I on %I for all to authenticated using(exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=%I.organization_id and m.active and m.role in(''admin'',''supervisor''))) with check(exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=%I.organization_id and m.active and m.role in(''admin'',''supervisor'')))',t||'_manage',t,t,t);
end loop;end$$;

grant select on production_demand_lines,manufacturing_order_lines,production_demand_exceptions,v_manufacturing_order_product_mix,v_mo_grouping_reconciliation to authenticated;
grant all on production_demand_lines,manufacturing_order_lines,production_demand_exceptions to service_role;
grant select on v_manufacturing_order_product_mix,v_mo_grouping_reconciliation to service_role;
revoke all on function create_manufacturing_orders(uuid,text),update_manufacturing_order_line_quantity(uuid,text,text,text,numeric) from public,anon,authenticated;
grant execute on function create_manufacturing_orders(uuid,text),update_manufacturing_order_line_quantity(uuid,text,text,text,numeric) to service_role;
create trigger production_demand_lines_audit after insert or update or delete on production_demand_lines for each row execute function maintenance_audit_change();
create trigger manufacturing_order_lines_audit after insert or update or delete on manufacturing_order_lines for each row execute function maintenance_audit_change();
create trigger production_demand_exceptions_audit after insert or update or delete on production_demand_exceptions for each row execute function maintenance_audit_change();
