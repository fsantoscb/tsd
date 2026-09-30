-- Disposable PostgreSQL only. Never run this fixture against Production.
-- psql -v ON_ERROR_STOP=1 -v migration_file=<absolute migration path> -f <this file>
\set ON_ERROR_STOP on
begin;

create temp table _view_contract as
select c.relowner, c.relacl, c.reloptions,
       array_agg(format('%s:%s:%s:%s', a.attnum, a.attname, a.atttypid, a.atttypmod)
                 order by a.attnum) as columns_and_types
from pg_class c join pg_namespace n on n.oid=c.relnamespace
join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
where n.nspname='public' and c.relname='v_current_labour_segments'
group by c.relowner,c.relacl,c.reloptions;

create temp table _org(id uuid primary key);
insert into _org values (gen_random_uuid());
insert into public.organizations(id,name) select id,'DEPUTY_HYBRID_TEST' from _org;

create temp table _batches(code text primary key,id uuid not null);
insert into _batches select code,gen_random_uuid() from unnest(array[
  'legacy1','legacy2','full_a','full_b','tie_a','tie_b','historical'
]) code;
insert into public.deputy_import_batches
  (id,organization_id,filename,source_type,source_timezone,content_hash,status,
   snapshot_type,report_generated_at,coverage_start,coverage_end,certified_at,
   certified_by,certification_note)
select b.id,o.id,b.code||'.csv','CSV','Australia/Brisbane','hybrid-'||b.code,
       'COMPLETED',
       case when b.code like 'legacy%' then null else 'FULL' end,
       case b.code when 'full_a' then '2099-01-04 08:00+10'::timestamptz
                   when 'full_b' then '2099-01-05 08:00+10'::timestamptz
                   when 'tie_a' then '2099-01-06 08:00+10'::timestamptz
                   when 'tie_b' then '2099-01-06 08:00+10'::timestamptz
                   when 'historical' then '2099-01-07 08:00+10'::timestamptz end,
       case when b.code='historical' then date '2098-01-01'
            when b.code in ('full_a','full_b') then date '2099-01-02'
            when b.code like 'tie_%' then date '2099-01-04' end,
       case when b.code='historical' then date '2098-01-01'
            when b.code in ('full_a','full_b') then date '2099-01-03'
            when b.code like 'tie_%' then date '2099-01-04' end,
       case when b.code like 'legacy%' then null else '2099-01-08 08:00+10'::timestamptz end,
       case when b.code like 'legacy%' then null else 'tester' end,
       case when b.code like 'legacy%' then null else 'complete source report' end
from _batches b cross join _org o;

create temp table _fixture(
  case_code text,batch_code text,copy_no int,source_date date,op_date date,
  raw_area text,normal_area text,clock_out timestamptz,productive numeric
);
insert into _fixture values
 ('fallback','legacy1',1,'2099-01-01','2099-01-01','DTG','DTG_OPERATOR','2099-01-01 14:00+10',1),
 ('fallback','legacy2',1,'2099-01-01','2099-01-01','DTG','DTG_OPERATOR','2099-01-01 14:00+10',1),
 ('unchanged','full_a',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('unchanged','full_b',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('revision','full_a',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('revision','full_b',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 15:00+10',2),
 ('deleted','full_a',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('new','full_b',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('area','full_a',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('area','full_b',1,'2099-01-02','2099-01-02','UP','UP_OPERATOR','2099-01-02 14:00+10',1),
 ('internal','full_b',1,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('internal','full_b',2,'2099-01-02','2099-01-02','DTG','DTG_OPERATOR','2099-01-02 14:00+10',1),
 ('cross_midnight','full_b',1,'2099-01-03','2099-01-02','DTG','DTG_OPERATOR','2099-01-03 06:00+10',1),
 ('tie','tie_a',1,'2099-01-04','2099-01-04','DTG','DTG_OPERATOR','2099-01-04 14:00+10',1),
 ('tie','tie_b',1,'2099-01-04','2099-01-04','UP','UP_OPERATOR','2099-01-04 14:00+10',1),
 ('historical','legacy1',1,'2098-01-01','2098-01-01','DTG','DTG_OPERATOR','2098-01-01 14:00+10',1),
 ('historical','historical',1,'2098-01-01','2098-01-01','DTG','DTG_OPERATOR','2098-01-01 15:00+10',2);

create temp table _fixture_rows as
select f.*,gen_random_uuid() raw_id from _fixture f;
insert into public.deputy_raw_timesheets
  (id,organization_id,import_batch_id,source_row_key,person_key,display_name,
   timesheet_date,raw_area,normalized_area,start_at,end_at,total_hours,
   meal_break_hours,approval_status,row_status,raw_data)
select f.raw_id,o.id,b.id,f.case_code||':'||f.copy_no,
       'NAME:'||upper(f.case_code),f.case_code,f.source_date,f.raw_area,f.normal_area,
       f.source_date::timestamp at time zone 'Australia/Brisbane' + interval '5 hours 30 minutes',
       f.clock_out,8.5,0,'APPROVED','ACCEPTED','{}'::jsonb
from _fixture_rows f join _batches b on b.code=f.batch_code cross join _org o;
insert into public.labour_segments
  (organization_id,import_batch_id,source_timesheet_row_id,person_key,area_code,
   segment_start,segment_end,calendar_date,operational_date,hour_bucket,
   shift_code,paid_hours,regular_hours,overtime_hours,paid_break_hours,
   productive_hours,approval_status,week_start)
select o.id,b.id,f.raw_id,'NAME:'||upper(f.case_code),f.normal_area,
       f.clock_out-interval '1 hour',f.clock_out,f.op_date,f.op_date,5,
       'SHIFT_1',f.productive,f.productive,0,0,f.productive,'APPROVED',
       date_trunc('week',f.op_date::timestamp)::date
from _fixture_rows f join _batches b on b.code=f.batch_code cross join _org o;

create temp table _before_counts as
select (select count(*) from public.deputy_import_batches where organization_id=o.id) batches,
       (select count(*) from public.deputy_raw_timesheets where organization_id=o.id) raw_rows,
       (select count(*) from public.labour_segments where organization_id=o.id) segments
from _org o;

\i :migration_file

do $$
declare v_count int; v_batch text; v_area text; v_hours numeric;
begin
  for v_batch,v_count in select * from (values
    ('fallback',1),('unchanged',1),('revision',1),('deleted',0),
    ('new',1),('area',1),('internal',1),('cross_midnight',1),
    ('tie',0),('historical',1)
  ) expected(case_code,n) loop
    select count(*) into v_hours from public.v_current_labour_segments v
    join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
    where f.case_code=v_batch;
    if v_hours<>v_count then raise exception '%: expected %, got %',v_batch,v_count,v_hours; end if;
  end loop;
  select f.batch_code,v.area_code,v.productive_hours into v_batch,v_area,v_hours
  from public.v_current_labour_segments v join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
  where f.case_code='revision';
  if (v_batch,v_area,v_hours) is distinct from ('full_b','DTG_OPERATOR',2::numeric) then
    raise exception 'latest FULL revision not selected';
  end if;
  select f.batch_code,v.area_code into v_batch,v_area
  from public.v_current_labour_segments v join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
  where f.case_code='area';
  if (v_batch,v_area) is distinct from ('full_b','UP_OPERATOR') then
    raise exception 'area revision not replaced';
  end if;
  if not exists (select 1 from public.v_current_labour_segments v
    join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
    where f.case_code='cross_midnight' and f.source_date='2099-01-03'
      and v.operational_date='2099-01-02') then
    raise exception 'source-date authority lost cross-midnight segment';
  end if;
  if exists (select 1 from public.v_current_labour_segments v
    join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
    where f.case_code='tie') then
    raise exception 'equal latest timestamp was not fail-closed';
  end if;
  select f.batch_code into v_batch
  from public.v_current_labour_segments v join _fixture_rows f on f.raw_id=v.source_timesheet_row_id
  where f.case_code='historical';
  if v_batch is distinct from 'historical' then
    raise exception 'late FULL historical correction did not replace legacy';
  end if;
  if exists (
    select 1 from _before_counts x cross join _org o
    where (x.batches,x.raw_rows,x.segments) is distinct from
          ((select count(*) from public.deputy_import_batches where organization_id=o.id),
           (select count(*) from public.deputy_raw_timesheets where organization_id=o.id),
           (select count(*) from public.labour_segments where organization_id=o.id))
  ) then raise exception 'migration modified source tables'; end if;
  -- Read-only ambiguity diagnostic: the conflicting FULL fixtures must be
  -- visible as a tie, rather than silently selected by import time or UUID.
  select count(*) into v_count
  from public.deputy_import_batches b join _org o on o.id=b.organization_id
  where b.status='COMPLETED' and b.snapshot_type='FULL'
    and b.coverage_start<=date '2099-01-04'
    and b.coverage_end>=date '2099-01-04'
    and b.report_generated_at=(
      select max(x.report_generated_at) from public.deputy_import_batches x
      where x.organization_id=o.id and x.status='COMPLETED'
        and x.snapshot_type='FULL' and x.certified_at is not null
        and x.certified_by is not null
        and x.coverage_start<=date '2099-01-04'
        and x.coverage_end>=date '2099-01-04'
    );
  if v_count<>2 then raise exception 'ambiguous authority diagnostic missed the tie'; end if;
  if exists (select 1 from _view_contract old cross join lateral (
    select c.relowner,c.relacl,c.reloptions,
           array_agg(format('%s:%s:%s:%s',a.attnum,a.attname,a.atttypid,a.atttypmod)
                     order by a.attnum) columns_and_types
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
    where n.nspname='public' and c.relname='v_current_labour_segments'
    group by c.relowner,c.relacl,c.reloptions
  ) now where (old.relowner,old.relacl,old.reloptions,old.columns_and_types)
              is distinct from
              (now.relowner,now.relacl,now.reloptions,now.columns_and_types)) then
    raise exception 'view contract changed';
  end if;
end $$;
rollback;
