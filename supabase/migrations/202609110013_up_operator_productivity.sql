create or replace view public.v_up_operator_daily_productivity
with (security_invoker = true)
as
select
  p.organization_id,
  p.operational_date,
  p.shift_code,
  coalesce(nullif(trim(a.username), ''), 'UNASSIGNED') as operator,
  sum(p.quantity)::numeric as output,
  count(distinct coalesce(nullif(a.from_pack_id, ''), nullif(a.to_pack_id, ''), nullif(a.order_no, ''), a.source_audit_id))::bigint as pid,
  max(
    extract(epoch from (
      case when s.cross_midnight
        then (timestamp '2000-01-02' + s.end_time) - (timestamp '2000-01-01' + s.start_time)
        else (timestamp '2000-01-01' + s.end_time) - (timestamp '2000-01-01' + s.start_time)
      end
    )) / 3600
  )::numeric as hours
from public.production_events p
join public.source_audit_events a
  on a.organization_id = p.organization_id
 and coalesce(a.source_audit_id, a.raw_hash) = p.source_record_key
left join public.shift_rules s
  on s.organization_id = p.organization_id
 and s.shift_code = p.shift_code
 and s.weekday = extract(isodow from p.operational_date)
 and s.active
 and s.effective_from <= p.operational_date
 and (s.effective_to is null or s.effective_to >= p.operational_date)
where p.area = 'UP'
  and p.metric = 'UP_OUT'
  and coalesce(a.username, '') !~* '^DTG[0-9]+$'
group by p.organization_id, p.operational_date, p.shift_code,
  coalesce(nullif(trim(a.username), ''), 'UNASSIGNED');

grant select on public.v_up_operator_daily_productivity to service_role;
