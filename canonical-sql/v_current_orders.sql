create or replace view public.v_current_orders
with (security_invoker = true)
as
select
  o.id,
  o.organization_id,
  o.sync_batch_id,
  o.order_no,
  o.date_received,
  o.date_due,
  o.date_released,
  o.source_status,
  o.source_sub_status,
  o.customer_code,
  o.customer_name,
  o.ship_to_name,
  o.customer_state,
  o.city,
  o.delivery_desc,
  o.client_so_number,
  o.source_priority,
  o.source_updated_at,
  o.created_at,
  o.site,
  o.source_route_id,
  o.cost_centre,
  o.stop_ship_flag,
  o.release_source_status
from public.source_orders o
join public.v_latest_completed_batch b
  on b.id = o.sync_batch_id
 and b.organization_id = o.organization_id;
