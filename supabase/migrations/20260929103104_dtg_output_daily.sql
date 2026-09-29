begin;

create table public.dtg_output_daily (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  operational_date date not null,
  shift_code text not null check (shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3','OVERTIME','OUT_OF_SHIFT')),
  output_type text not null check (output_type = 'DTG'),
  quantity numeric not null check (quantity >= 0),
  source_row_count bigint not null check (source_row_count >= 0),
  source_max_event_at timestamptz not null,
  refreshed_at timestamptz not null default now(),
  unique (organization_id, operational_date, shift_code, output_type)
);

create index dtg_output_daily_period_idx on public.dtg_output_daily (organization_id, operational_date);
alter table public.dtg_output_daily enable row level security;
create policy dtg_output_daily_read on public.dtg_output_daily for select to authenticated
  using (public.has_org_role(organization_id, array['viewer','operator','supervisor','maintenance','manager','admin']));
revoke all on public.dtg_output_daily from public, anon, authenticated;
grant select on public.dtg_output_daily to authenticated;
grant all on public.dtg_output_daily to service_role;

create function public.replace_dtg_output_daily(p_organization_id uuid, p_from date, p_to date, p_rows jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_count bigint;
begin
  if p_organization_id is null or p_from is null or p_to is null or p_from > p_to or p_rows is null
    or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 1000 then
    raise exception 'INVALID_DTG_OUTPUT_PAYLOAD';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_rows) r
    where nullif(r->>'operationalDate','') is null
      or (r->>'operationalDate')::date not between p_from and p_to
      or r->>'outputType' is distinct from 'DTG'
      or r->>'shiftCode' is null
      or r->>'shiftCode' not in ('SHIFT_1','SHIFT_2','SHIFT_3','OVERTIME','OUT_OF_SHIFT')
      or coalesce((r->>'quantity')::numeric,-1) < 0
      or coalesce((r->>'sourceRowCount')::bigint,-1) < 0
      or nullif(r->>'sourceMaxEventAt','') is null
  ) then raise exception 'INVALID_DTG_OUTPUT_ROW'; end if;
  if exists (
    select 1 from jsonb_array_elements(p_rows) r
    group by r->>'operationalDate', r->>'shiftCode', r->>'outputType'
    having count(*) > 1
  ) then raise exception 'DUPLICATE_DTG_OUTPUT_GRAIN'; end if;

  delete from public.dtg_output_daily
  where organization_id = p_organization_id and operational_date between p_from and p_to;
  insert into public.dtg_output_daily
    (organization_id, operational_date, shift_code, output_type, quantity, source_row_count, source_max_event_at)
  select p_organization_id, (r->>'operationalDate')::date, r->>'shiftCode', r->>'outputType',
    (r->>'quantity')::numeric, (r->>'sourceRowCount')::bigint, (r->>'sourceMaxEventAt')::timestamptz
  from jsonb_array_elements(p_rows) r;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function public.replace_dtg_output_daily(uuid,date,date,jsonb) from public,anon,authenticated;
grant execute on function public.replace_dtg_output_daily(uuid,date,date,jsonb) to service_role;

commit;
