create table shift_templates (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id),
  name text not null, starts_at time not null, ends_at time not null, active boolean not null default true,
  created_at timestamptz not null default now(), unique(organization_id,name)
);
create table production_orders (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id), order_no text not null,
  planner_priority integer check(planner_priority between 0 and 999), planned_date date,
  planned_shift_id uuid references shift_templates(id),
  planning_status text not null default 'unplanned' check(planning_status in ('unplanned','planned','ready','in_progress','blocked','waiting','completed','cancelled')),
  special_instruction text, planner_note text, blocked_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), updated_by uuid,
  unique(organization_id,order_no), check(planning_status='blocked' or blocked_reason is null),
  check(planning_status<>'blocked' or nullif(trim(blocked_reason),'') is not null)
);
create table production_order_history (
  id uuid primary key default gen_random_uuid(), production_order_id uuid not null references production_orders(id),
  organization_id uuid not null references organizations(id), order_no text not null, changed_by uuid, changed_by_email text,
  changed_at timestamptz not null default now(), before_state jsonb not null, after_state jsonb not null
);
create index production_order_history_order_idx on production_order_history(organization_id,order_no,changed_at desc);
alter table shift_templates enable row level security;
alter table production_orders enable row level security;
alter table production_order_history enable row level security;
revoke all on shift_templates,production_orders,production_order_history from anon,authenticated;
grant select,insert,update,delete on shift_templates,production_orders to service_role;
grant select,insert on production_order_history to service_role;
insert into shift_templates(organization_id,name,starts_at,ends_at)
select id,x.name,x.starts_at,x.ends_at from organizations cross join (values ('Day','06:00'::time,'14:00'::time),('Afternoon','14:00'::time,'22:00'::time),('Night','22:00'::time,'06:00'::time)) x(name,starts_at,ends_at) on conflict do nothing;

create or replace function apply_production_planning(p_organization_id uuid,p_order_nos text[],p_changes jsonb,p_actor_id uuid,p_actor_email text)
returns integer language plpgsql security definer set search_path=public as $$
declare n text; row_id uuid; old_row jsonb; new_row jsonb; old_status text; new_status text; changed integer:=0;
begin
  if coalesce(array_length(p_order_nos,1),0)=0 then raise exception 'At least one order is required'; end if;
  if p_changes ? 'planned_shift_id' and nullif(p_changes->>'planned_shift_id','') is not null and not exists(select 1 from shift_templates where id=(p_changes->>'planned_shift_id')::uuid and organization_id=p_organization_id and active) then raise exception 'Invalid shift'; end if;
  foreach n in array p_order_nos loop
    if not exists(select 1 from v_current_orders where organization_id=p_organization_id and order_no=n) then raise exception 'Unknown source order %',n; end if;
    insert into production_orders(organization_id,order_no,updated_by) values(p_organization_id,n,p_actor_id) on conflict do nothing;
    select id,to_jsonb(po),planning_status into row_id,old_row,old_status from production_orders po where organization_id=p_organization_id and order_no=n for update;
    new_status=coalesce(nullif(p_changes->>'planning_status',''),old_status);
    if new_status<>old_status and not ((old_status='unplanned' and new_status in ('planned','cancelled')) or (old_status='planned' and new_status in ('unplanned','ready','blocked','waiting','cancelled')) or (old_status='ready' and new_status in ('planned','in_progress','blocked','waiting','cancelled')) or (old_status='in_progress' and new_status in ('blocked','waiting','completed','cancelled')) or (old_status in ('blocked','waiting') and new_status in ('planned','ready','in_progress','cancelled')) or (old_status in ('completed','cancelled') and new_status='unplanned')) then raise exception 'Invalid status transition: % to %',old_status,new_status; end if;
    update production_orders set
      planner_priority=case when p_changes?'planner_priority' then nullif(p_changes->>'planner_priority','')::integer else planner_priority end,
      planned_date=case when p_changes?'planned_date' then nullif(p_changes->>'planned_date','')::date else planned_date end,
      planned_shift_id=case when p_changes?'planned_shift_id' then nullif(p_changes->>'planned_shift_id','')::uuid else planned_shift_id end,
      planning_status=new_status,
      special_instruction=case when p_changes?'special_instruction' then nullif(trim(p_changes->>'special_instruction'),'') else special_instruction end,
      planner_note=case when p_changes?'planner_note' then nullif(trim(p_changes->>'planner_note'),'') else planner_note end,
      blocked_reason=case when new_status='blocked' then nullif(trim(p_changes->>'blocked_reason'),'') else null end,
      updated_at=now(),updated_by=p_actor_id where id=row_id returning to_jsonb(production_orders.*) into new_row;
    insert into production_order_history(production_order_id,organization_id,order_no,changed_by,changed_by_email,before_state,after_state) values(row_id,p_organization_id,n,p_actor_id,p_actor_email,old_row,new_row);
    changed=changed+1;
  end loop;
  return changed;
end $$;
revoke all on function apply_production_planning(uuid,text[],jsonb,uuid,text) from public,anon,authenticated;
grant execute on function apply_production_planning(uuid,text[],jsonb,uuid,text) to service_role;

create or replace view v_production_planning with (security_invoker=true) as
with queues as (
 select organization_id,order_no,'UP'::text line,customer_name,screen,status source_status,priority source_priority,age_days,remaining_units,total_prints from v_up_operational_orders
 union all
 select organization_id,order_no,'DTG'::text line,customer_name,screen,status,priority,age_days,remaining_units,total_prints from v_dtg_operational_orders
)
select q.*,p.id production_order_id,p.planner_priority,coalesce(p.planner_priority,q.source_priority) effective_priority,p.planned_date,p.planned_shift_id,s.name planned_shift,p.planning_status,p.special_instruction,p.planner_note,p.blocked_reason,p.updated_at
from queues q left join production_orders p on p.organization_id=q.organization_id and p.order_no=q.order_no left join shift_templates s on s.id=p.planned_shift_id;
revoke all on v_production_planning from anon,authenticated;
grant select on v_production_planning to service_role;
