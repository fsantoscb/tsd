create table shift_rules (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id),
  weekday smallint not null check(weekday between 1 and 7), shift_code text not null check(shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3')),
  display_name text not null, start_time time not null, end_time time not null, cross_midnight boolean not null default false,
  tolerance_minutes integer not null default 20 check(tolerance_minutes between 0 and 180), activation_confirmation_minutes integer not null default 150 check(activation_confirmation_minutes between 0 and 720),
  active boolean not null default true, effective_from date not null, effective_to date,
  check(effective_to is null or effective_to >= effective_from), unique(organization_id,weekday,shift_code,effective_from)
);
create index shift_rules_lookup_idx on shift_rules(organization_id,weekday,effective_from,effective_to) where active;

create table kpi_rate_rules (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id),
  process text not null check(process in ('DTG','UP','SCREEN_PRINT')), rate_per_hour numeric not null check(rate_per_hour > 0),
  unit text not null, capacity_mode text not null, calculation_version text not null,
  effective_from date not null, effective_to date, active boolean not null default true,
  check(effective_to is null or effective_to >= effective_from), unique(organization_id,process,effective_from)
);

create table production_events (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references organizations(id),
  event_id text not null, event_ts_utc timestamptz not null, event_ts_local timestamp not null,
  calendar_date date not null, operational_date date not null, hour_bucket smallint not null check(hour_bucket between 0 and 23),
  shift_code text not null check(shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT')),
  area text not null, metric text not null check(metric in ('DTG_PRINT','DTG_PUTWALL_IN','DTG_PUTWALL_OUT','UP_IN','UP_OUT','SCREEN_PRINT','SCREEN_MACHINE_HOURS')),
  quantity numeric not null, unit text not null, source text not null, source_mode text not null,
  source_record_key text not null, quality_status text not null check(quality_status in ('COMPLETE','PARTIAL','PROVISIONAL','MISSING_SOURCE','NO_TARGET_HOURS','OUT_OF_SHIFT','REJECTED')),
  import_batch_id uuid, calculation_version text not null, is_partial_period boolean not null default false,
  operational_shift_overtime boolean not null default false, created_at timestamptz not null default now(),
  unique(organization_id,source,source_record_key,metric)
);
create index production_events_period_idx on production_events(organization_id,operational_date,shift_code,metric);
create index production_events_timestamp_idx on production_events(organization_id,event_ts_utc);

insert into shift_rules(organization_id,weekday,shift_code,display_name,start_time,end_time,cross_midnight,effective_from)
select o.id,d.weekday,s.shift_code,s.display_name,s.start_time,s.end_time,s.cross_midnight,date '2026-01-01'
from organizations o cross join (values (1),(2),(3),(4),(6),(7)) d(weekday)
cross join (values ('SHIFT_1','Shift 1','06:00'::time,'14:30'::time,false),('SHIFT_2','Shift 2','14:30'::time,'23:00'::time,false),('SHIFT_3','Shift 3','23:00'::time,'06:00'::time,true)) s(shift_code,display_name,start_time,end_time,cross_midnight)
on conflict do nothing;
insert into shift_rules(organization_id,weekday,shift_code,display_name,start_time,end_time,cross_midnight,effective_from)
select o.id,5,s.shift_code,s.display_name,s.start_time,s.end_time,false,date '2026-01-01' from organizations o cross join
(values ('SHIFT_1','Shift 1','06:00'::time,'12:00'::time),('SHIFT_2','Shift 2','12:00'::time,'18:00'::time),('SHIFT_3','Shift 3','18:00'::time,'23:00'::time)) s(shift_code,display_name,start_time,end_time) on conflict do nothing;
insert into kpi_rate_rules(organization_id,process,rate_per_hour,unit,capacity_mode,calculation_version,effective_from)
select o.id,r.process,r.rate,r.unit,r.mode,'ERP_KPI_V1',date '2026-01-01' from organizations o cross join
(values ('DTG',140::numeric,'prints/capacity-hour','SHIFT_WIDE'),('UP',75::numeric,'garments/capacity-hour','SHIFT_WIDE'),('SCREEN_PRINT',350::numeric,'garments/machine-hour','MACHINE_HOURS')) r(process,rate,unit,mode) on conflict do nothing;

alter table shift_rules enable row level security; alter table kpi_rate_rules enable row level security; alter table production_events enable row level security;
revoke all on shift_rules,kpi_rate_rules,production_events from anon,authenticated;
grant select,insert,update,delete on shift_rules,kpi_rate_rules to service_role;
grant select,insert,update on production_events to service_role;
