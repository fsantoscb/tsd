create or replace function dtg_machine_load()
returns table(order_no text,customer_name text,due_at timestamptz,warehouse_garments bigint,warehouse_prints numeric,print_garments bigint,print_prints numeric)
language sql stable security invoker set search_path=public as $$
with latest as(select id from v_latest_completed_batch limit 1)
select
  w.order_no,
  max(w.customer_name),
  min(w.source_due_at),
  coalesce(sum(w.production_units) filter(where upper(trim(w.from_zone))='PG11'),0)::bigint,
  0::numeric,
  coalesce(sum(w.production_units) filter(where upper(trim(w.from_zone))='DTGS'),0)::bigint,
  coalesce(sum(w.prints_per_garment) filter(where upper(trim(w.from_zone))='DTGS'),0)
from source_workbank_items w
join latest on latest.id=w.sync_batch_id
where upper(trim(w.from_zone)) in ('PG11','DTGS')
group by w.order_no;
$$;
