create or replace view v_production_order_current_operation with (security_invoker=true) as
select e.organization_id,e.production_order_id,e.order_no,e.source_order_no,e.routing_code_snapshot,
  e.production_status,e.planned_quantity,e.actual_quantity,e.current_operation_id,
  e.current_operation_sequence,e.current_operation_code,e.current_operation_name,
  e.next_operation_id,e.next_operation_code,e.next_operation_name,
  e.last_completed_operation_id,e.last_completed_operation_code,e.last_completed_operation_name
from v_production_order_execution e;

create or replace view v_production_order_progress with (security_invoker=true) as
select c.*,greatest(coalesce(c.planned_quantity,0)-coalesce(c.actual_quantity,0),0) remaining_quantity,
  s.operation_count,s.completed_operation_count,s.evidence_count,s.open_exception_count,s.last_source_observed_at
from v_production_order_current_operation c
join v_production_order_routing_status s using(organization_id,production_order_id);

create or replace view v_production_flow_canonical with (security_invoker=true) as
with classified as (
  select p.*,
    case when routing_code_snapshot ilike 'DTG%' then 'DTG'
         when routing_code_snapshot ilike 'UNDERPRINT%' or routing_code_snapshot ilike 'UP%' then 'UNDERPRINT'
         when routing_code_snapshot ilike 'SCREEN%' then 'SCREEN_PRINT' end process_code
  from v_production_order_progress p
), normalized as (
  select *,case
    when process_code='DTG' and current_operation_code='PICKING' then 'DTG_PICKING'
    when process_code='DTG' and current_operation_code in('DTG_PRINT','DTG_PRINTING') then 'DTG_PRINTING'
    when process_code='DTG' and current_operation_code='PUTWALL' then 'DTG_PUTWALL'
    when process_code='DTG' and current_operation_code='DISPATCH' then 'DTG_DISPATCH'
    when process_code='UNDERPRINT' and current_operation_code='PICKING' then 'UP_PICKING'
    when process_code='UNDERPRINT' and current_operation_code='UNDERPRINT' then 'UP_PRINTING'
    when process_code='UNDERPRINT' and current_operation_code='DISPATCH' then 'UP_DISPATCH'
    when process_code='SCREEN_PRINT' then current_operation_code end stage_code
  from classified
)
select organization_id,process_code,stage_code,count(distinct production_order_id)::integer orders,
  sum(remaining_quantity)::numeric(14,3) units,
  count(*) filter(where open_exception_count>0)::integer orders_with_deviations,
  count(*) filter(where evidence_count=0)::integer orders_without_evidence
from normalized where process_code is not null and stage_code is not null
group by organization_id,process_code,stage_code;

create or replace view v_production_flow_legacy_snapshot with (security_invoker=true) as
with stages as (
 select organization_id,'DTG_PICKING' stage_code,order_no,production_units from v_current_workbank where upper(trim(coalesce(queue,'')))='SP11'
 union all select organization_id,'DTG_PRINTING',order_no,production_units from v_current_workbank where upper(trim(coalesce(queue,'')))='PCOR'
 union all select organization_id,'DTG_PUTWALL',order_no,production_units from v_current_workbank where upper(trim(coalesce(from_zone,'')))='PWL1'
 union all select organization_id,'DTG_DISPATCH',order_no,production_units from source_audit_events where upper(trim(coalesce(to_location,'')))='DTGMOVE' and (event_at at time zone 'Australia/Brisbane')::date=(now() at time zone 'Australia/Brisbane')::date
 union all select organization_id,'UP_PICKING',product,production_units from v_current_stock where upper(trim(coalesce(location,'')))='UNDERPRINT'
 union all select organization_id,'UP_PRINTING',order_no,production_units from v_current_workbank where upper(trim(coalesce(from_location,''))) like '%UP'
 union all select organization_id,'UP_DISPATCH',order_no,production_units from source_audit_events where upper(trim(coalesce(to_location,'')))='UPMOVE' and (event_at at time zone 'Australia/Brisbane')::date=(now() at time zone 'Australia/Brisbane')::date
)
select organization_id,stage_code,count(distinct order_no)::integer orders,sum(coalesce(production_units,0))::numeric(14,3) units
from stages group by organization_id,stage_code;

create or replace view v_production_flow_routing_reconciliation with (security_invoker=true) as
with expected(stage_code) as(values('DTG_PICKING'),('DTG_PRINTING'),('DTG_PUTWALL'),('DTG_DISPATCH'),('UP_PICKING'),('UP_PRINTING'),('UP_DISPATCH')),
orgs as(select id organization_id from organizations),canonical as(
 select organization_id,stage_code,orders,units from v_production_flow_canonical
)
select o.organization_id,e.stage_code,coalesce(l.units,0) legacy_units,coalesce(c.units,0) routing_units,
 coalesce(c.units,0)-coalesce(l.units,0) unit_difference,coalesce(l.orders,0) legacy_orders,
 coalesce(c.orders,0) routing_orders,coalesce(c.orders,0)-coalesce(l.orders,0) order_difference,
 case when coalesce(l.units,0)=coalesce(c.units,0) and coalesce(l.orders,0)=coalesce(c.orders,0) then 'MATCH' else 'MISMATCH' end result
from orgs o cross join expected e
left join v_production_flow_legacy_snapshot l on l.organization_id=o.organization_id and l.stage_code=e.stage_code
left join canonical c on c.organization_id=o.organization_id and c.stage_code=e.stage_code;

grant select on v_production_order_current_operation,v_production_order_progress,v_production_flow_canonical,
 v_production_flow_legacy_snapshot,v_production_flow_routing_reconciliation to authenticated,service_role;
