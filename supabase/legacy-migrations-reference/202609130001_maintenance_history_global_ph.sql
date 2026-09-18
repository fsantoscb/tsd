create extension if not exists btree_gist;

alter table maintenance_assets add column if not exists asset_kind text not null default 'FIXED' check(asset_kind in('FIXED','MOVABLE'));
alter table maintenance_assets add column if not exists asset_type text;
alter table maintenance_assets add column if not exists asset_category text;
alter table maintenance_assets add column if not exists commission_date date;
alter table maintenance_assets add column if not exists retire_date date;
alter table maintenance_assets add column if not exists notes text;
alter table maintenance_assets drop constraint if exists maintenance_assets_status_check;
alter table maintenance_assets add constraint maintenance_assets_status_check check(status in('operational','down','maintenance','standby','retired','scrapped'));

create table if not exists maintenance_asset_installations(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references organizations(id),
 movement_id text,
 movable_asset_id uuid not null references maintenance_assets(id),
 host_asset_id uuid not null references maintenance_assets(id),
 host_system_asset_id uuid references maintenance_assets(id),
 position text,
 channel text,
 installed_at timestamptz not null,
 removed_at timestamptz,
 movement_reason text,
 installed_by text,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(organization_id,movement_id),
 check(movable_asset_id<>host_asset_id),
 check(removed_at is null or installed_at<removed_at),
 exclude using gist(movable_asset_id with =,tstzrange(installed_at,coalesce(removed_at,'infinity'::timestamptz),'[)') with &&)
);
create unique index if not exists maintenance_one_active_installation on maintenance_asset_installations(movable_asset_id)where removed_at is null;
create index if not exists maintenance_install_movable_idx on maintenance_asset_installations(organization_id,movable_asset_id,installed_at desc);
create index if not exists maintenance_install_host_idx on maintenance_asset_installations(organization_id,host_asset_id,installed_at desc);

alter table maintenance_downtime_events add column if not exists event_code text;
alter table maintenance_downtime_events add column if not exists event_date date;
alter table maintenance_downtime_events add column if not exists host_asset_id uuid references maintenance_assets(id);
alter table maintenance_downtime_events add column if not exists host_system_asset_id uuid references maintenance_assets(id);
alter table maintenance_downtime_events add column if not exists affected_asset_id uuid references maintenance_assets(id);
alter table maintenance_downtime_events add column if not exists downtime_minutes numeric;
alter table maintenance_downtime_events add column if not exists event_type text;
alter table maintenance_downtime_events add column if not exists maintenance_class text;
alter table maintenance_downtime_events add column if not exists failure_category text;
alter table maintenance_downtime_events add column if not exists failure_mode text;
alter table maintenance_downtime_events add column if not exists root_cause text;
alter table maintenance_downtime_events add column if not exists action_taken text;
alter table maintenance_downtime_events add column if not exists spare_parts_text text;
alter table maintenance_downtime_events add column if not exists description text;
alter table maintenance_downtime_events add column if not exists counts_as_failure boolean not null default false;
alter table maintenance_downtime_events add column if not exists counts_as_downtime boolean not null default true;
alter table maintenance_downtime_events add column if not exists event_status text;
alter table maintenance_downtime_events add column if not exists source_system text;
alter table maintenance_downtime_events add column if not exists source_key text;
alter table maintenance_downtime_events add column if not exists source_row integer;
alter table maintenance_downtime_events add column if not exists original_duration_minutes numeric;
alter table maintenance_downtime_events add column if not exists clock_duration_minutes numeric;
alter table maintenance_downtime_events add column if not exists correction_factor numeric;
alter table maintenance_downtime_events add column if not exists data_quality_status text;
alter table maintenance_downtime_events add column if not exists correction_confidence text;
alter table maintenance_downtime_events add column if not exists correction_method text;
alter table maintenance_downtime_events add column if not exists correction_note text;
alter table maintenance_downtime_events add column if not exists raw_reason text;
alter table maintenance_downtime_events add column if not exists historical_asset_reference text;
alter table maintenance_downtime_events add column if not exists created_at timestamptz not null default now();
alter table maintenance_downtime_events add column if not exists updated_at timestamptz not null default now();
update maintenance_downtime_events set host_asset_id=asset_id,event_date=(started_at at time zone 'Australia/Brisbane')::date,downtime_minutes=greatest(0,extract(epoch from(coalesce(ended_at,now())-started_at))/60) where host_asset_id is null;
create unique index if not exists maintenance_event_source_unique on maintenance_downtime_events(organization_id,source_system,source_key) where source_system is not null and source_key is not null;
create index if not exists maintenance_event_host_idx on maintenance_downtime_events(organization_id,host_asset_id,event_date);
create index if not exists maintenance_event_affected_idx on maintenance_downtime_events(organization_id,affected_asset_id,event_date);
create index if not exists maintenance_event_date_idx on maintenance_downtime_events(organization_id,event_date);

create table if not exists maintenance_import_batches(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references organizations(id),
 file_name text not null,file_hash text not null,source_system text not null,status text not null check(status in('VALIDATING','READY','IMPORTING','COMPLETED','FAILED','ROLLED_BACK')),
 uploaded_by uuid,started_at timestamptz not null default now(),completed_at timestamptz,total_rows integer not null default 0,
 valid_rows integer not null default 0,warning_rows integer not null default 0,error_rows integer not null default 0,
 inserted_rows integer not null default 0,updated_rows integer not null default 0,skipped_rows integer not null default 0,
 import_report jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),unique(organization_id,file_hash)
);
create table if not exists maintenance_import_staging(
 id uuid primary key default gen_random_uuid(),batch_id uuid not null references maintenance_import_batches(id) on delete cascade,
 organization_id uuid not null references organizations(id),source_row integer,row_status text not null check(row_status in('VALID','WARNING','ERROR','DUPLICATE','UNRESOLVED_PH')),
 source_key text,host_asset_code text,affected_asset_code text,historical_asset_reference text,
 errors text[] not null default '{}',warnings text[] not null default '{}',payload jsonb not null,created_at timestamptz not null default now()
);
create index if not exists maintenance_staging_batch_idx on maintenance_import_staging(batch_id,row_status);

create or replace view maintenance_asset_current_installations as select i.*,m.asset_code movable_asset_code,h.asset_code host_asset_code,s.asset_code host_system_asset_code
from maintenance_asset_installations i join maintenance_assets m on m.id=i.movable_asset_id join maintenance_assets h on h.id=i.host_asset_id
left join maintenance_assets s on s.id=i.host_system_asset_id where i.removed_at is null;

alter table maintenance_asset_installations enable row level security;
alter table maintenance_import_batches enable row level security;
alter table maintenance_import_staging enable row level security;
revoke all on maintenance_asset_installations,maintenance_import_batches,maintenance_import_staging from anon,authenticated;
grant all on maintenance_asset_installations,maintenance_import_batches,maintenance_import_staging to service_role;
grant select on maintenance_asset_current_installations to service_role;

create or replace function maintenance_import_history(p_organization_id uuid,p_file_name text,p_file_hash text,p_assets jsonb,p_events jsonb,p_report jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$declare b uuid;r jsonb;a uuid;h uuid;s uuid;ph uuid;ins integer:=0;upd integer:=0;begin
 insert into maintenance_import_batches(organization_id,file_name,file_hash,source_system,status,total_rows,valid_rows,warning_rows,error_rows,import_report)
 values(p_organization_id,p_file_name,p_file_hash,'ERP_MAINTENANCE_HISTORY','IMPORTING',jsonb_array_length(p_events),(p_report->>'valid_rows')::int,(p_report->>'warning_rows')::int,(p_report->>'error_rows')::int,p_report)
 on conflict(organization_id,file_hash)do update set import_report=excluded.import_report returning id into b;
 if exists(select 1 from maintenance_import_batches where id=b and status='COMPLETED')then return jsonb_build_object('batch_id',b,'status','duplicate');end if;
 if coalesce((p_report->>'error_rows')::int,0)>0 then raise exception 'Blocking dry-run errors remain';end if;
 for r in select * from jsonb_array_elements(p_assets)loop
  insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,asset_kind,asset_type,asset_category,status,active,notes)
  values(p_organization_id,r->>'asset_code',r->>'asset_name',r->>'asset_name',
   (select id from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'parent_asset_code','')),
   coalesce(r->>'asset_kind','FIXED'),r->>'asset_type',r->>'category',
   case upper(coalesce(r->>'status','ACTIVE'))when 'ACTIVE'then'operational'when'STORED'then'standby'when'UNDER_MAINTENANCE'then'maintenance'when'SCRAPPED'then'scrapped'else'retired'end,
   upper(coalesce(r->>'status','ACTIVE'))not in('RETIRED','SCRAPPED'),r->>'notes')
  on conflict(organization_id,asset_code)do update set name=excluded.name,asset_name=excluded.asset_name,
   asset_kind=excluded.asset_kind,asset_type=coalesce(excluded.asset_type,maintenance_assets.asset_type),
   asset_category=coalesce(excluded.asset_category,maintenance_assets.asset_category),
   notes=coalesce(excluded.notes,maintenance_assets.notes),updated_at=now();
 end loop;
 for r in select * from jsonb_array_elements(p_events)loop
  select id into h from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'parent_asset_code';
  select id into a from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'asset_code';
  select id into s from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'host_print_system_code','');
  select id into ph from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'ph_asset_code','') and asset_kind='MOVABLE';
  if h is null or a is null then raise exception 'Unresolved required asset at source row %',r->>'source_row';end if;
  insert into maintenance_import_staging(batch_id,organization_id,source_row,row_status,source_key,host_asset_code,affected_asset_code,historical_asset_reference,payload)
  values(b,p_organization_id,(r->>'source_row')::int,case when ph is null and nullif(r->>'ph_reference','')is not null then'UNRESOLVED_PH'else'VALID'end,
   r->>'source_key',r->>'parent_asset_code',r->>'ph_asset_code',r->>'ph_reference',r);
  if exists(select 1 from maintenance_downtime_events where organization_id=p_organization_id and source_system=r->>'source_system' and source_key=r->>'source_key')then upd:=upd+1;else ins:=ins+1;end if;
  insert into maintenance_downtime_events(organization_id,asset_id,event_code,event_date,host_asset_id,host_system_asset_id,affected_asset_id,
   started_at,ended_at,downtime_minutes,event_type,maintenance_class,failure_category,failure_mode,root_cause,action_taken,spare_parts_text,
   description,counts_as_failure,counts_as_downtime,event_status,source_system,source_key,source_row,original_duration_minutes,
   clock_duration_minutes,correction_factor,data_quality_status,correction_confidence,correction_method,correction_note,raw_reason,historical_asset_reference,reason)
  values(p_organization_id,a,r->>'event_id',(r->>'event_date')::date,h,s,ph,(r->>'started_at')::timestamptz,(r->>'ended_at')::timestamptz,
   (r->>'downtime_minutes')::numeric,r->>'event_type',r->>'maintenance_class',r->>'failure_category',r->>'failure_mode',
   r->>'root_cause_inferred',r->>'action_inferred',r->>'spare_parts_text',r->>'description',(r->>'counts_as_failure')='YES',
   (r->>'counts_as_downtime')='YES',r->>'status',r->>'source_system',r->>'source_key',(r->>'source_row')::int,
   nullif(r->>'original_duration_minutes','')::numeric,nullif(r->>'clock_duration_minutes','')::numeric,nullif(r->>'correction_factor','')::numeric,
   r->>'data_quality_status',r->>'correction_confidence',r->>'correction_method',r->>'correction_note',r->>'raw_reason',r->>'ph_reference',r->>'raw_reason')
  on conflict(organization_id,source_system,source_key)where source_system is not null and source_key is not null do update set
   host_asset_id=excluded.host_asset_id,host_system_asset_id=excluded.host_system_asset_id,affected_asset_id=excluded.affected_asset_id,
   downtime_minutes=excluded.downtime_minutes,event_type=excluded.event_type,maintenance_class=excluded.maintenance_class,
   failure_category=excluded.failure_category,failure_mode=excluded.failure_mode,counts_as_failure=excluded.counts_as_failure,
   counts_as_downtime=excluded.counts_as_downtime,original_duration_minutes=excluded.original_duration_minutes,
   clock_duration_minutes=excluded.clock_duration_minutes,correction_factor=excluded.correction_factor,data_quality_status=excluded.data_quality_status,
   correction_confidence=excluded.correction_confidence,correction_method=excluded.correction_method,correction_note=excluded.correction_note,
   historical_asset_reference=excluded.historical_asset_reference,updated_at=now();
 end loop;
 update maintenance_import_batches set status='COMPLETED',inserted_rows=ins,updated_rows=upd,completed_at=now() where id=b;
 return jsonb_build_object('batch_id',b,'status','COMPLETED','inserted_rows',ins,'updated_rows',upd);
end$$;
revoke all on function maintenance_import_history(uuid,text,text,jsonb,jsonb,jsonb)from public,anon,authenticated;
grant execute on function maintenance_import_history(uuid,text,text,jsonb,jsonb,jsonb)to service_role;
