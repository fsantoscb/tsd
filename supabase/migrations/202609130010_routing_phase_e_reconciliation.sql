create table production_reconciliation_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  sync_batch_id uuid references sync_batches(id),
  status text not null default 'RUNNING' check (status in ('RUNNING','COMPLETED','FAILED')),
  quantity_tolerance numeric(14,3) not null default 1 check (quantity_tolerance >= 0),
  total_orders integer not null default 0,
  matched_orders integer not null default 0,
  mismatched_orders integer not null default 0,
  missing_canonical_orders integer not null default 0,
  missing_legacy_orders integer not null default 0,
  comparable_quantity_orders integer not null default 0,
  quantity_matched_orders integer not null default 0,
  match_rate numeric(7,4),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create table production_reconciliation_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  reconciliation_run_id uuid not null references production_reconciliation_runs(id) on delete cascade,
  order_no text not null,
  legacy_area text,
  expected_operation_code text,
  canonical_operation_code text,
  legacy_remaining_quantity numeric(14,3),
  canonical_remaining_quantity numeric(14,3),
  quantity_variance numeric(14,3),
  presence_result text not null check (presence_result in ('BOTH','MISSING_CANONICAL','MISSING_LEGACY')),
  operation_result text not null check (operation_result in ('MATCH','MISMATCH','NOT_COMPARABLE')),
  quantity_result text not null check (quantity_result in ('MATCH','MISMATCH','NOT_COMPARABLE')),
  overall_result text not null check (overall_result in ('MATCH','MISMATCH','MISSING_CANONICAL','MISSING_LEGACY')),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(reconciliation_run_id,order_no,legacy_area)
);

create index production_reconciliation_runs_org_idx
  on production_reconciliation_runs(organization_id,started_at desc);
create index production_reconciliation_items_result_idx
  on production_reconciliation_items(organization_id,reconciliation_run_id,overall_result);

create or replace function run_production_reconciliation(
  p_organization_id uuid,
  p_quantity_tolerance numeric default 1
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_run_id uuid; v_batch_id uuid;
begin
  if p_quantity_tolerance < 0 then raise exception 'Quantity tolerance cannot be negative'; end if;
  select id into v_batch_id from v_latest_completed_batch where organization_id=p_organization_id;
  insert into production_reconciliation_runs(organization_id,sync_batch_id,quantity_tolerance)
  values(p_organization_id,v_batch_id,p_quantity_tolerance) returning id into v_run_id;

  insert into production_reconciliation_items(
    organization_id,reconciliation_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,
    quantity_result,overall_result,detail)
  with legacy as (
    select organization_id,order_no,'DTG'::text legacy_area,'DTG_PRINT'::text expected_operation_code,remaining_units legacy_remaining_quantity
    from v_dtg_operational_orders where organization_id=p_organization_id
    union all
    select organization_id,order_no,'UP','UNDERPRINT',remaining_units
    from v_up_operational_orders where organization_id=p_organization_id
  ), canonical as (
    select x.organization_id,coalesce(x.source_order_no,x.order_no) order_no,x.current_operation_code,
      case when poo.planned_quantity is null then null
        else greatest(poo.planned_quantity-coalesce(poo.actual_quantity,0),0) end canonical_remaining_quantity,
      x.production_order_id,x.production_status
    from v_production_order_execution x
    left join production_order_operations poo on poo.id=x.current_operation_id
    where x.organization_id=p_organization_id and x.production_status not in ('CANCELLED','COMPLETED','UNROUTED')
  ), compared as (
    select coalesce(l.organization_id,c.organization_id) organization_id,coalesce(l.order_no,c.order_no) order_no,
      l.legacy_area,l.expected_operation_code,c.current_operation_code canonical_operation_code,
      l.legacy_remaining_quantity,c.canonical_remaining_quantity,
      case when l.legacy_remaining_quantity is not null and c.canonical_remaining_quantity is not null
        then c.canonical_remaining_quantity-l.legacy_remaining_quantity end quantity_variance,
      case when c.order_no is null then 'MISSING_CANONICAL' when l.order_no is null then 'MISSING_LEGACY' else 'BOTH' end presence_result,
      case when c.order_no is null or l.order_no is null then 'NOT_COMPARABLE'
        when c.current_operation_code=l.expected_operation_code then 'MATCH' else 'MISMATCH' end operation_result,
      case when l.legacy_remaining_quantity is null or c.canonical_remaining_quantity is null then 'NOT_COMPARABLE'
        when abs(c.canonical_remaining_quantity-l.legacy_remaining_quantity)<=p_quantity_tolerance then 'MATCH' else 'MISMATCH' end quantity_result,
      c.production_order_id,c.production_status
    from legacy l full join canonical c on c.organization_id=l.organization_id and c.order_no=l.order_no
  )
  select organization_id,v_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,quantity_result,
    case when presence_result='MISSING_CANONICAL' then 'MISSING_CANONICAL'
      when presence_result='MISSING_LEGACY' then 'MISSING_LEGACY'
      when operation_result='MISMATCH' or quantity_result='MISMATCH' then 'MISMATCH' else 'MATCH' end,
    jsonb_build_object('production_order_id',production_order_id,'production_status',production_status,
      'quantity_semantics','legacy remaining versus canonical planned minus actual')
  from compared;

  update production_reconciliation_runs r set
    status='COMPLETED',completed_at=now(),
    total_orders=s.total_orders,matched_orders=s.matched_orders,mismatched_orders=s.mismatched_orders,
    missing_canonical_orders=s.missing_canonical_orders,missing_legacy_orders=s.missing_legacy_orders,
    comparable_quantity_orders=s.comparable_quantity_orders,quantity_matched_orders=s.quantity_matched_orders,
    match_rate=case when s.total_orders=0 then null else round(100.0*s.matched_orders/s.total_orders,4) end
  from (
    select count(*)::integer total_orders,count(*) filter(where overall_result='MATCH')::integer matched_orders,
      count(*) filter(where overall_result='MISMATCH')::integer mismatched_orders,
      count(*) filter(where overall_result='MISSING_CANONICAL')::integer missing_canonical_orders,
      count(*) filter(where overall_result='MISSING_LEGACY')::integer missing_legacy_orders,
      count(*) filter(where quantity_result<>'NOT_COMPARABLE')::integer comparable_quantity_orders,
      count(*) filter(where quantity_result='MATCH')::integer quantity_matched_orders
    from production_reconciliation_items where reconciliation_run_id=v_run_id
  ) s where r.id=v_run_id;
  return v_run_id;
exception when others then
  if v_run_id is not null then update production_reconciliation_runs set status='FAILED',completed_at=now(),error_message=left(sqlerrm,1000) where id=v_run_id; end if;
  raise;
end $$;

create or replace view v_latest_production_reconciliation with (security_invoker=true) as
select distinct on (organization_id) * from production_reconciliation_runs
where status='COMPLETED' order by organization_id,completed_at desc;

create or replace view v_latest_production_reconciliation_items with (security_invoker=true) as
select i.* from production_reconciliation_items i
join v_latest_production_reconciliation r on r.id=i.reconciliation_run_id;

create or replace view v_production_reconciliation_gate with (security_invoker=true) as
select r.*,
  case when total_orders=0 then 'NO_DATA'
    when missing_canonical_orders>0 then 'BLOCKED_MISSING_CANONICAL'
    when match_rate>=98 then 'READY_FOR_UI_PILOT'
    when match_rate>=90 then 'REVIEW_REQUIRED'
    else 'NOT_READY' end migration_gate
from v_latest_production_reconciliation r;

alter table production_reconciliation_runs enable row level security;
alter table production_reconciliation_items enable row level security;
create policy production_reconciliation_runs_read on production_reconciliation_runs for select using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_reconciliation_runs.organization_id and m.active));
create policy production_reconciliation_items_read on production_reconciliation_items for select using (
  exists(select 1 from maintenance_members m where m.user_id=auth.uid() and m.organization_id=production_reconciliation_items.organization_id and m.active));
revoke all on production_reconciliation_runs,production_reconciliation_items from anon,authenticated;
grant select on production_reconciliation_runs,production_reconciliation_items to authenticated;
grant all on production_reconciliation_runs,production_reconciliation_items to service_role;
revoke all on function run_production_reconciliation(uuid,numeric) from public,anon,authenticated;
grant execute on function run_production_reconciliation(uuid,numeric) to service_role;
grant select on v_latest_production_reconciliation,v_latest_production_reconciliation_items,v_production_reconciliation_gate to authenticated,service_role;

