-- Stage A only: empty additive schema. No writer, trigger or backfill.
begin;

create table public.up_shift_daily_actuals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  operational_date date not null,
  shift_code text not null check (shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT')),
  garments numeric not null check (garments >= 0),
  source_event_count bigint not null check (source_event_count >= 0),
  last_source_timestamp timestamptz,
  synced_at timestamptz not null default now(),
  status text not null default 'CURRENT' check (status in ('CURRENT','STALE','MISSING')),
  source_system text not null default 'ORACLE_ISIS_AUDIT',
  calculation_version text not null default 'UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1',
  source_snapshot_id uuid not null,
  unique (organization_id, operational_date, shift_code)
);

alter table public.up_shift_daily_actuals owner to postgres;
alter table public.up_shift_daily_actuals enable row level security;
create policy up_shift_daily_actuals_read on public.up_shift_daily_actuals
  for select to authenticated
  using (public.has_org_role(organization_id, array['viewer','operator','supervisor','maintenance','manager','admin']));
revoke all on public.up_shift_daily_actuals from public, anon, authenticated;
grant select on public.up_shift_daily_actuals to authenticated;
grant all on public.up_shift_daily_actuals to service_role;

comment on column public.up_shift_daily_actuals.source_snapshot_id is
  'Common UP extraction identity; correlation only, not completeness certification. Supplied by future atomic writer, without a default.';
comment on column public.up_shift_daily_actuals.calculation_version is
  'UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1: existing UNDERPRINT exit predicate, WEIGHT only, canonical operational date and shift; no business rule change.';

-- Unique btree already covers organization_id + operational_date prefix queries.
-- No redundant period index; no change to up_daily_actuals or its RPC.
commit;
