-- Six independent UV V1 quantities from the existing current Workbank and Stock snapshots.
-- Stock PRODUCT is an order marker, not a product/SKU classification.
create view public.v_uv_operational_orders
with (security_invoker = true)
as
with workbank_by_order as (
  select
    organization_id,
    order_no,
    coalesce(round(sum(production_units) filter (where from_zone = 'PG02')), 0) as uv_pick_qty,
    coalesce(round(sum(production_units) filter (where from_zone in ('PG04', 'PG42'))), 0) as finished_pick_qty
  from public.v_current_workbank
  where from_zone in ('PG02', 'PG04', 'PG42')
  group by organization_id, order_no
),
stock_by_order as (
  select
    organization_id,
    substring(product from 2) as order_no,
    bool_or(source_weight is null and location = 'UV') as uv_to_print_missing_weight,
    coalesce(round(sum(source_weight) filter (where location = 'UV')), 0) as uv_to_print_qty,
    bool_or(source_weight is null and location = 'UVPRNT') as uv_printing_missing_weight,
    coalesce(round(sum(source_weight) filter (where location = 'UVPRNT')), 0) as uv_printing_qty,
    bool_or(source_weight is null and location like '%STICKRDROP%') as sticker_missing_weight,
    -- STICKER_WEIGHT_DIVISOR = 13; divide only after summing all matching packs.
    coalesce(round(sum(source_weight) filter (where location like '%STICKRDROP%') / 13), 0) as sticker_print_qty,
    bool_or(source_weight is null and location like '%PWL3%') as uv_pack_missing_weight,
    coalesce(round(sum(source_weight) filter (where location like '%PWL3%')), 0) as uv_pack_qty
  from public.v_current_stock
  where product ~ '^#[0-9]+$'
    and (location = 'UV' or location = 'UVPRNT'
      or location like '%STICKRDROP%' or location like '%PWL3%')
  group by organization_id, substring(product from 2)
),
source_orders as (
  select organization_id, order_no from workbank_by_order
  union
  select organization_id, order_no from stock_by_order
)
select
  o.organization_id,
  o.order_no,
  o.customer_name,
  o.source_priority,
  o.date_received,
  o.date_released,
  o.date_due,
  coalesce(w.uv_pick_qty, 0) as uv_pick_qty,
  case when s.uv_to_print_missing_weight then null else coalesce(s.uv_to_print_qty, 0) end as uv_to_print_qty,
  case when s.uv_printing_missing_weight then null else coalesce(s.uv_printing_qty, 0) end as uv_printing_qty,
  case when s.sticker_missing_weight then null else coalesce(s.sticker_print_qty, 0) end as sticker_print_qty,
  coalesce(w.finished_pick_qty, 0) as finished_pick_qty,
  case when s.uv_pack_missing_weight then null else coalesce(s.uv_pack_qty, 0) end as uv_pack_qty
from source_orders x
join public.v_current_orders o
  on o.organization_id = x.organization_id and o.order_no = x.order_no
left join workbank_by_order w
  on w.organization_id = x.organization_id and w.order_no = x.order_no
left join stock_by_order s
  on s.organization_id = x.organization_id and s.order_no = x.order_no;

grant select on public.v_uv_operational_orders to authenticated, service_role;
