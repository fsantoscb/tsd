create or replace view public.v_dtg_order_history
with (security_invoker = true)
as
select
  order_no,
  count(*) filter (
    where upper(from_zone) = 'DTGS' and upper(to_zone) = 'PWL1'
  )::bigint as printed,
  min(event_at) filter (
    where upper(from_zone) = 'PG11' and upper(to_zone) = 'DTGS'
  ) as first_pick,
  min(event_at) filter (
    where upper(from_zone) = 'DTGS' and upper(to_zone) = 'PWL1'
  ) as first_print,
  max(event_at) filter (
    where upper(from_zone) = 'DTGS' and upper(to_zone) = 'PWL1'
  ) as last_print
from public.source_audit_events
where
  (upper(from_zone) = 'PG11' and upper(to_zone) = 'DTGS')
  or (upper(from_zone) = 'DTGS' and upper(to_zone) = 'PWL1')
group by order_no;

grant select on public.v_dtg_order_history to authenticated, service_role;

