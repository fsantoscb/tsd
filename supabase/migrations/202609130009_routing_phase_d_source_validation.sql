create table source_operation_mappings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  source_system text not null default 'ORACLE_WMS',
  source_dataset text not null check (source_dataset in ('AUDIT','WORKBANK','STOCK')),
  source_field text not null,
  match_type text not null check (match_type in ('EXACT','PREFIX','SUFFIX','LIKE')),
  match_value text not null,
  operation_id uuid not null,
  completion_semantics text not null check (completion_semantics in ('CURRENT_LOCATION','ENTERED_OPERATION','COMPLETED_OPERATION','MOVED_FROM_OPERATION','MOVED_TO_OPERATION')),
  priority integer not null default 100 check (priority >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, source_system, source_dataset, source_field, match_type, match_value, completion_semantics),
  foreign key (organization_id, operation_id) references operations(organization_id, id)
);

create index source_operation_mappings_lookup_idx
  on source_operation_mappings(organization_id, source_dataset, source_field, priority)
  where active;

create table production_order_operation_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  production_order_id uuid not null,
  production_order_operation_id uuid not null,
  source_mapping_id uuid not null references source_operation_mappings(id),
  source_dataset text not null,
  source_record_key text not null,
  source_audit_event_id uuid references source_audit_events(id),
  semantics text not null,
  observed_at timestamptz not null,
  quantity numeric(14,3),
  source_value text not null,
  created_at timestamptz not null default now(),
  unique (production_order_operation_id, source_dataset, source_record_key, source_mapping_id),
  foreign key (organization_id, production_order_id) references production_orders(organization_id, id) on delete cascade,
  foreign key (organization_id, production_order_operation_id) references production_order_operations(organization_id, id) on delete cascade
);

create index production_order_operation_evidence_order_idx
  on production_order_operation_evidence(organization_id, production_order_id, observed_at);

create table production_routing_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  production_order_id uuid not null,
  production_order_operation_id uuid,
  exception_type text not null check (exception_type in ('SKIPPED_OPERATION','OUT_OF_SEQUENCE','UNKNOWN_SOURCE_STAGE','UNEXPECTED_OPERATION','ROUTING_MISMATCH')),
  description text not null,
  source_dataset text,
  source_record_key text,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  status text not null default 'OPEN' check (status in ('OPEN','ACKNOWLEDGED','RESOLVED','DISMISSED')),
  resolved_by uuid,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, production_order_id) references production_orders(organization_id, id) on delete cascade,
  foreign key (organization_id, production_order_operation_id) references production_order_operations(organization_id, id) on delete cascade,
  check ((status in ('OPEN','ACKNOWLEDGED') and resolved_at is null) or (status in ('RESOLVED','DISMISSED') and resolved_at is not null))
);

create unique index production_routing_exceptions_open_key
  on production_routing_exceptions(production_order_id, coalesce(production_order_operation_id, '00000000-0000-0000-0000-000000000000'::uuid), exception_type)
  where status in ('OPEN','ACKNOWLEDGED');

create or replace function source_value_matches(p_actual text, p_match_type text, p_expected text)
returns boolean language sql immutable parallel safe as $$
  select case p_match_type
    when 'EXACT' then upper(coalesce(p_actual,'')) = upper(p_expected)
    when 'PREFIX' then upper(coalesce(p_actual,'')) like upper(p_expected) || '%'
    when 'SUFFIX' then upper(coalesce(p_actual,'')) like '%' || upper(p_expected)
    when 'LIKE' then upper(coalesce(p_actual,'')) like upper(p_expected)
    else false
  end
$$;

create or replace function seed_source_operation_mappings(p_organization_id uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare affected integer;
begin
  insert into source_operation_mappings(organization_id,source_dataset,source_field,match_type,match_value,operation_id,completion_semantics,priority)
  select p_organization_id, x.dataset, x.field_name, x.match_type, x.match_value, o.id, x.semantics, x.priority
  from (values
    ('WORKBANK','queue','EXACT','SP11','PICKING','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','SP11','PICKING','ENTERED_OPERATION',10),
    ('WORKBANK','queue','EXACT','PCOR','DTG_PRINT','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',10),
    ('AUDIT','task','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',20),
    ('AUDIT','to_zone','EXACT','PWL1','PUTWALL','ENTERED_OPERATION',10),
    ('AUDIT','from_zone','EXACT','PWL1','PUTWALL','COMPLETED_OPERATION',10),
    ('STOCK','source_zone','EXACT','PWL1','PUTWALL','CURRENT_LOCATION',10),
    ('AUDIT','to_location','EXACT','DTGMOVE','DISPATCH','MOVED_TO_OPERATION',10),
    ('STOCK','location','LIKE','%UNDERPRINT%','UNDERPRINT','CURRENT_LOCATION',10),
    ('WORKBANK','from_location','SUFFIX','UP','UNDERPRINT','CURRENT_LOCATION',20),
    ('AUDIT','to_location','EXACT','UPMOVE','DISPATCH','MOVED_TO_OPERATION',20)
  ) x(dataset,field_name,match_type,match_value,operation_code,semantics,priority)
  join operations o on o.organization_id=p_organization_id and o.code=x.operation_code
  on conflict do nothing;
  get diagnostics affected=row_count;
  return affected;
end $$;

select seed_source_operation_mappings(id) from organizations;

create or replace view v_source_operation_evidence with (security_invoker=true) as
with source_values as (
  select a.organization_id,a.order_no,'AUDIT'::text source_dataset,
    coalesce(a.source_audit_id,a.raw_hash,a.id::text) source_record_key,a.id source_audit_event_id,
    a.event_at observed_at,a.production_units quantity,
    v.source_field,v.source_value
  from source_audit_events a
  cross join lateral (values
    ('queue',a.queue),('task',a.task),('from_zone',a.from_zone),('to_zone',a.to_zone),
    ('from_location',a.from_location),('to_location',a.to_location)
  ) v(source_field,source_value)
  where nullif(trim(v.source_value),'') is not null
  union all
  select w.organization_id,w.order_no,'WORKBANK',coalesce(w.source_row_id,w.id::text),null::uuid,w.created_at,w.production_units,
    v.source_field,v.source_value
  from v_current_workbank w
  cross join lateral (values ('queue',w.queue),('task',w.task),('from_zone',w.from_zone),('from_location',w.from_location),('to_location',w.to_location)) v(source_field,source_value)
  where nullif(trim(v.source_value),'') is not null
  union all
  select s.organization_id,regexp_replace(s.product,'^#',''),'STOCK',s.id::text,null::uuid,
    coalesce(s.source_timestamp,s.created_at),s.production_units,v.source_field,v.source_value
  from v_current_stock s
  cross join lateral (values ('source_zone',s.source_zone),('location',s.location)) v(source_field,source_value)
  where nullif(trim(v.source_value),'') is not null
), ranked as (
  select sv.*,m.id source_mapping_id,m.operation_id,m.completion_semantics,
    row_number() over(partition by sv.organization_id,sv.source_dataset,sv.source_record_key,sv.source_field order by m.priority,m.id) mapping_rank
  from source_values sv
  join source_operation_mappings m on m.organization_id=sv.organization_id and m.active
    and m.source_dataset=sv.source_dataset and m.source_field=sv.source_field
    and source_value_matches(sv.source_value,m.match_type,m.match_value)
)
select organization_id,order_no,source_dataset,source_record_key,source_audit_event_id,observed_at,quantity,
  source_field,source_value,source_mapping_id,operation_id,completion_semantics
from ranked where mapping_rank=1;

create or replace function resolve_production_order_actual_state(p_organization_id uuid, p_production_order_id uuid default null)
returns table(orders_resolved integer,evidence_added integer,exceptions_added integer)
language plpgsql security definer set search_path=public as $$
declare v_orders integer:=0; v_evidence integer:=0; v_exceptions integer:=0; v_count integer;
begin
  perform seed_source_operation_mappings(p_organization_id);

  with inserted as (
    insert into production_order_operation_evidence(
      organization_id,production_order_id,production_order_operation_id,source_mapping_id,source_dataset,
      source_record_key,source_audit_event_id,semantics,observed_at,quantity,source_value)
    select po.organization_id,po.id,poo.id,e.source_mapping_id,e.source_dataset,e.source_record_key,
      e.source_audit_event_id,e.completion_semantics,e.observed_at,e.quantity,e.source_value
    from production_orders po
    join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    join production_order_operations poo on poo.production_order_id=po.id
      and poo.organization_id=po.organization_id and poo.source_operation_id=e.operation_id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    on conflict do nothing returning 1
  ) select count(*) into v_evidence from inserted;

  with touched as (
    update production_order_operations poo set
      status=case
        when x.has_completion then 'COMPLETED'
        when poo.status in ('PENDING','READY') and x.has_entry then 'IN_PROGRESS'
        else poo.status end,
      started_at=coalesce(poo.started_at,x.first_observed_at),
      completed_at=case when x.has_completion then coalesce(poo.completed_at,x.last_completion_at) else poo.completed_at end,
      actual_quantity=greatest(poo.actual_quantity,coalesce(x.observed_quantity,0)),updated_at=now()
    from (
      select production_order_operation_id,
        bool_or(semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) has_completion,
        bool_or(semantics in ('CURRENT_LOCATION','ENTERED_OPERATION','MOVED_TO_OPERATION')) has_entry,
        min(observed_at) first_observed_at,
        max(observed_at) filter(where semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) last_completion_at,
        sum(coalesce(quantity,0)) observed_quantity
      from production_order_operation_evidence
      where organization_id=p_organization_id and (p_production_order_id is null or production_order_id=p_production_order_id)
      group by production_order_operation_id
    ) x where poo.id=x.production_order_operation_id
    returning poo.production_order_id
  ) select count(distinct production_order_id) into v_orders from touched;

  with observed as (
    select po.id production_order_id,max(poo.sequence) max_observed_sequence
    from production_orders po join production_order_operations poo on poo.production_order_id=po.id
    join production_order_operation_evidence e on e.production_order_operation_id=poo.id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    group by po.id
  ), inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,production_order_operation_id,exception_type,description)
    select poo.organization_id,poo.production_order_id,poo.id,'SKIPPED_OPERATION',
      'Required operation '||poo.operation_code_snapshot||' has no source evidence before a later observed operation.'
    from observed o join production_order_operations poo on poo.production_order_id=o.production_order_id
    where poo.required and poo.sequence<o.max_observed_sequence
      and not exists(select 1 from production_order_operation_evidence e where e.production_order_operation_id=poo.id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  with inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
    select po.organization_id,po.id,'UNEXPECTED_OPERATION',
      'Mapped source operation is not present in the Production Order routing snapshot.',e.source_dataset,e.source_record_key
    from production_orders po join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
      and not exists(select 1 from production_order_operations poo where poo.production_order_id=po.id and poo.source_operation_id=e.operation_id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  update production_orders po set
    production_status=case
      when not exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status<>'COMPLETED') then 'COMPLETED'
      when exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status='IN_PROGRESS') then 'IN_PROGRESS'
      else po.production_status end,
    actual_quantity=coalesce((select max(x.actual_quantity) from production_order_operations x where x.production_order_id=po.id),po.actual_quantity),
    updated_at=now()
  where po.organization_id=p_organization_id and po.production_status<>'UNROUTED'
    and (p_production_order_id is null or po.id=p_production_order_id);

  return query select v_orders,v_evidence,v_exceptions;
end $$;

create or replace view v_production_order_routing_status with (security_invoker=true) as
select po.organization_id,po.id production_order_id,po.order_no,po.source_order_no,po.production_status,
  count(poo.id) operation_count,count(poo.id) filter(where poo.status='COMPLETED') completed_operation_count,
  count(e.id) evidence_count,count(ex.id) filter(where ex.status in ('OPEN','ACKNOWLEDGED')) open_exception_count,
  max(e.observed_at) last_source_observed_at
from production_orders po
left join production_order_operations poo on poo.production_order_id=po.id
left join production_order_operation_evidence e on e.production_order_id=po.id
left join production_routing_exceptions ex on ex.production_order_id=po.id
group by po.organization_id,po.id,po.order_no,po.source_order_no,po.production_status;

alter table source_operation_mappings enable row level security;
alter table production_order_operation_evidence enable row level security;
alter table production_routing_exceptions enable row level security;

create policy source_operation_mappings_read on source_operation_mappings for select using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=source_operation_mappings.organization_id and m.active));
create policy source_operation_mappings_manage on source_operation_mappings for all using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=source_operation_mappings.organization_id and m.active and m.role in ('admin','supervisor')))
  with check (exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=source_operation_mappings.organization_id and m.active and m.role in ('admin','supervisor')));
create policy production_order_operation_evidence_read on production_order_operation_evidence for select using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_order_operation_evidence.organization_id and m.active));
create policy production_routing_exceptions_read on production_routing_exceptions for select using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_routing_exceptions.organization_id and m.active));
create policy production_routing_exceptions_manage on production_routing_exceptions for update using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_routing_exceptions.organization_id and m.active and m.role in ('admin','supervisor')))
  with check (exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_routing_exceptions.organization_id and m.active and m.role in ('admin','supervisor')));

revoke all on source_operation_mappings,production_order_operation_evidence,production_routing_exceptions from anon,authenticated;
grant select on source_operation_mappings,production_order_operation_evidence,production_routing_exceptions to authenticated;
grant insert,update,delete on source_operation_mappings to authenticated;
grant update on production_routing_exceptions to authenticated;
grant all on source_operation_mappings,production_order_operation_evidence,production_routing_exceptions to service_role;
revoke all on function seed_source_operation_mappings(uuid),resolve_production_order_actual_state(uuid,uuid) from public,anon,authenticated;
grant execute on function resolve_production_order_actual_state(uuid,uuid) to service_role;
grant select on v_source_operation_evidence,v_production_order_routing_status to authenticated,service_role;

create trigger source_operation_mappings_audit after insert or update or delete on source_operation_mappings
  for each row execute function maintenance_audit_change();
create trigger production_routing_exceptions_audit after insert or update or delete on production_routing_exceptions
  for each row execute function maintenance_audit_change();

