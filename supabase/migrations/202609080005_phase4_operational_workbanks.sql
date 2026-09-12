create or replace view v_up_operational_orders with (security_invoker=true) as
with stock as (select s.organization_id,regexp_replace(s.product,'^#','') order_no,count(*) box_count,sum(s.production_units) remaining_units,min(s.source_timestamp) last_movement from v_current_stock s group by s.organization_id,regexp_replace(s.product,'^#','')),
putwall as (select organization_id,order_no,string_agg(distinct coalesce(nullif(to_location,''),from_location),', ' order by coalesce(nullif(to_location,''),from_location)) putwall_locations from v_current_workbank where upper(coalesce(from_zone,''))='PWL1' group by organization_id,order_no)
select s.organization_id,s.order_no,o.customer_name,o.delivery_desc screen,o.source_status status,o.source_priority priority,o.date_due,
greatest(0,current_date-coalesce(o.date_due::date,current_date)) age_days,s.box_count item_count,s.remaining_units,s.last_movement,p.putwall_locations,'At UP' progress_label
from stock s left join v_current_orders o on o.organization_id=s.organization_id and o.order_no=s.order_no left join putwall p on p.organization_id=s.organization_id and p.order_no=s.order_no;

create or replace view v_dtg_operational_orders with (security_invoker=true) as
select w.organization_id,w.order_no,max(coalesce(w.customer_name,o.customer_name)) customer_name,max(o.delivery_desc) screen,max(o.source_status) status,max(coalesce(w.source_priority,o.source_priority)) priority,min(coalesce(w.source_due_at,o.date_due)) date_due,
greatest(0,current_date-coalesce(min(coalesce(w.source_due_at,o.date_due))::date,current_date)) age_days,count(*) item_count,sum(w.production_units) remaining_units,null::timestamptz last_movement,
string_agg(distinct coalesce(nullif(w.to_location,''),w.from_location),', ' order by coalesce(nullif(w.to_location,''),w.from_location)) putwall_locations,'At DTG' progress_label
from v_current_workbank w left join v_current_orders o on o.organization_id=w.organization_id and o.order_no=w.order_no where upper(coalesce(w.from_zone,'')) like 'DTG%' group by w.organization_id,w.order_no;

revoke all on v_up_operational_orders,v_dtg_operational_orders from anon,authenticated;grant select on v_up_operational_orders,v_dtg_operational_orders to service_role;
