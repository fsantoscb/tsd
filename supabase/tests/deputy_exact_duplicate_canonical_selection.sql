-- Run only against a verified disposable PostgreSQL database at the canonical
-- migration baseline. The migration is included inside this rollback boundary.
-- psql -v ON_ERROR_STOP=1 -v migration_file=<absolute-new-migration-path> -f <this-file>
\set ON_ERROR_STOP on

begin;

create temp table _view_contract as
select c.relowner, c.relacl, c.reloptions, pg_get_viewdef(c.oid, true) as old_definition,
       array_agg(format('%s:%s:%s:%s', a.attnum, a.attname, a.atttypid, a.atttypmod)
                 order by a.attnum) as columns_and_types
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
where n.nspname = 'public' and c.relname = 'v_current_labour_segments'
group by c.oid, c.relowner, c.relacl, c.reloptions;

create temp table _test_org(id uuid primary key);
insert into _test_org values (gen_random_uuid());
insert into public.organizations(id, name)
select id, 'DEPUTY_EXACT_DEDUP_TEST' from _test_org;

create temp table _test_batches(n integer primary key, id uuid not null);
insert into _test_batches
select n, gen_random_uuid() from generate_series(1, 6) n;
insert into public.deputy_import_batches
  (id, organization_id, filename, source_type, source_timezone, content_hash, status)
select b.id, o.id, format('deputy-export-%s.csv', b.n), 'CSV',
       'Australia/Brisbane', format('exact-dedup-test-%s', b.n), 'COMPLETED'
from _test_batches b cross join _test_org o;

-- All duplicate copies differ in filename, import batch and source_row_key.
-- Business variation is explicit only in the separation cases below.
create temp table _fixture_spec(
  case_code text not null,
  copy_no integer not null,
  source_timesheet_id text,
  start_at timestamptz not null,
  end_at timestamptz not null,
  total_hours numeric not null,
  meal_break_hours numeric not null,
  primary key (case_code, copy_no)
);
insert into _fixture_spec
select 'duplicate_2', n, null, '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 2) n
union all
select 'duplicate_4', n, null, '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 4) n
union all
select 'duplicate_6', n, null, '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 6) n
union all
select 'same_stable_id', n, 'DEPUTY-42', '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 2) n
union all
select 'different_stable_id', n, format('DEPUTY-%s', n), '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 2) n
union all
select 'null_vs_stable_id', n, case when n = 1 then null else 'DEPUTY-42' end,
       '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0
from generate_series(1, 2) n
union all
select 'stewart_revision', n, null, '2099-01-01 05:30+10',
       case when n = 1 then '2099-01-01 14:00+10'::timestamptz
            else '2099-01-01 14:32+10'::timestamptz end,
       case when n = 1 then 8.5 else 8.53 end,
       case when n = 1 then 0 else 0.5033333333 end
from generate_series(1, 2) n
union all
select 'legitimate_distinct', n, null,
       case when n = 1 then '2099-01-01 05:30+10'::timestamptz
            else '2099-01-01 15:00+10'::timestamptz end,
       case when n = 1 then '2099-01-01 14:00+10'::timestamptz
            else '2099-01-01 23:30+10'::timestamptz end,
       8.5, 0
from generate_series(1, 2) n
union all
select 'single', 1, null, '2099-01-01 05:30+10', '2099-01-01 14:00+10', 8.5, 0;

create temp table _fixture_rows(case_code text not null, copy_no integer not null,
                                raw_id uuid not null, primary key(case_code, copy_no));
insert into _fixture_rows
select case_code, copy_no, md5(case_code || ':' || copy_no)::uuid
from _fixture_spec;

insert into public.deputy_raw_timesheets
  (id, organization_id, import_batch_id, source_row_key, source_timesheet_id,
   employee_id, person_key, display_name, timesheet_date, raw_area,
   normalized_area, start_at, end_at, total_hours, meal_break_hours,
   approval_status, row_status, raw_data)
select f.raw_id, o.id, b.id, format('%s:%s', s.case_code, s.copy_no),
       s.source_timesheet_id, null, 'NAME:' || upper(s.case_code),
       s.case_code, date '2099-01-01', 'DTG', 'DTG_OPERATOR',
       s.start_at, s.end_at, s.total_hours, s.meal_break_hours,
       'APPROVED', 'ACCEPTED',
       jsonb_build_object('Employee', s.case_code, 'Date', '2099-01-01',
                          'Clock In', s.start_at, 'Clock Out', s.end_at,
                          'Hours', s.total_hours, 'Area', 'DTG')
from _fixture_spec s
join _fixture_rows f using(case_code, copy_no)
join _test_batches b on b.n = s.copy_no
cross join _test_org o;

insert into public.labour_segments
  (organization_id, import_batch_id, source_timesheet_row_id, person_key,
   area_code, segment_start, segment_end, calendar_date, operational_date,
   hour_bucket, shift_code, paid_hours, regular_hours, overtime_hours,
   paid_break_hours, productive_hours, approval_status, week_start)
select o.id, b.id, f.raw_id, 'NAME:' || upper(s.case_code), 'DTG_OPERATOR',
       s.start_at, s.start_at + interval '1 hour', date '2099-01-01',
       date '2099-01-01', 5, 'SHIFT_1', 1, 1, 0, 0, 1,
       'APPROVED', date '2098-12-29'
from _fixture_spec s
join _fixture_rows f using(case_code, copy_no)
join _test_batches b on b.n = s.copy_no
cross join _test_org o;

create temp table _raw_before as
select to_jsonb(r) as row_value from public.deputy_raw_timesheets r
where r.organization_id = (select id from _test_org);
create temp table _batches_before as
select to_jsonb(b) as row_value from public.deputy_import_batches b
where b.organization_id = (select id from _test_org);
create temp table _segments_before as
select to_jsonb(s) as row_value from public.labour_segments s
where s.organization_id = (select id from _test_org);

\i :migration_file

do $$
declare
  v_case text;
  v_expected integer;
  v_actual integer;
  v_first uuid;
  v_second uuid;
begin
  for v_case, v_expected in
    select * from (values
      ('duplicate_2', 1), ('duplicate_4', 1), ('duplicate_6', 1),
      ('same_stable_id', 1), ('different_stable_id', 2),
      ('null_vs_stable_id', 2), ('stewart_revision', 2),
      ('legitimate_distinct', 2), ('single', 1)
    ) as expected(case_code, selected_rows)
  loop
    select count(*) into v_actual
    from public.v_current_labour_segments v
    join _fixture_rows f on f.raw_id = v.source_timesheet_row_id
    where f.case_code = v_case;
    if v_actual <> v_expected then
      raise exception 'canonical %: expected %, got %', v_case, v_expected, v_actual;
    end if;
  end loop;

  select raw_id into v_first from _fixture_rows
  where case_code = 'duplicate_6' order by raw_id limit 1;
  select v.source_timesheet_row_id into v_second
  from public.v_current_labour_segments v
  join _fixture_rows f on f.raw_id = v.source_timesheet_row_id
  where f.case_code = 'duplicate_6' order by v.source_timesheet_row_id limit 1;
  if v_first is distinct from v_second then
    raise exception 'lowest UUID representative not selected';
  end if;
  select v.source_timesheet_row_id into v_second
  from public.v_current_labour_segments v
  join _fixture_rows f on f.raw_id = v.source_timesheet_row_id
  where f.case_code = 'duplicate_6' order by v.source_timesheet_row_id limit 1;
  if v_first is distinct from v_second then
    raise exception 'representative changed on repeated read';
  end if;
end $$;

do $$
declare
  v_before _view_contract%rowtype;
  v_after record;
begin
  select * into strict v_before from _view_contract;
  select c.relowner, c.relacl, c.reloptions, pg_get_viewdef(c.oid, true) as new_definition,
         array_agg(format('%s:%s:%s:%s', a.attnum, a.attname, a.atttypid, a.atttypmod)
                   order by a.attnum) as columns_and_types
    into strict v_after
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
  where n.nspname = 'public' and c.relname = 'v_current_labour_segments'
  group by c.oid, c.relowner, c.relacl, c.reloptions;
  if v_before.relowner is distinct from v_after.relowner
     or v_before.relacl is distinct from v_after.relacl
     or v_before.reloptions is distinct from v_after.reloptions
     or v_before.columns_and_types is distinct from v_after.columns_and_types then
    raise exception 'view output/access contract changed';
  end if;
  if v_before.old_definition is not distinct from v_after.new_definition then
    raise exception 'canonical view definition did not change';
  end if;

  if exists (
    (select to_jsonb(r) from public.deputy_raw_timesheets r
     where r.organization_id = (select id from _test_org)
     except all select row_value from _raw_before)
    union all
    (select row_value from _raw_before except all
     select to_jsonb(r) from public.deputy_raw_timesheets r
     where r.organization_id = (select id from _test_org))
  ) or exists (
    (select to_jsonb(b) from public.deputy_import_batches b
     where b.organization_id = (select id from _test_org)
     except all select row_value from _batches_before)
    union all
    (select row_value from _batches_before except all
     select to_jsonb(b) from public.deputy_import_batches b
     where b.organization_id = (select id from _test_org))
  ) or exists (
    (select to_jsonb(s) from public.labour_segments s
     where s.organization_id = (select id from _test_org)
     except all select row_value from _segments_before)
    union all
    (select row_value from _segments_before except all
     select to_jsonb(s) from public.labour_segments s
     where s.organization_id = (select id from _test_org))
  ) then
    raise exception 'raw, batch, or segment history was modified';
  end if;
end $$;

-- Negative activation-gate fixture: lowest UUID has no segments, sibling has
-- one. This must be reported; the view must not prefer the sibling by recency.
savepoint missing_representative_segments;
insert into public.deputy_raw_timesheets
  (id, organization_id, import_batch_id, source_row_key, person_key,
   display_name, timesheet_date, raw_area, normalized_area, start_at,
   end_at, total_hours, meal_break_hours, approval_status, row_status, raw_data)
select x.id, o.id, b.id, x.source_row_key, 'NAME:NEGATIVE', 'Negative',
       date '2099-01-02', 'DTG', 'DTG_OPERATOR',
       '2099-01-02 05:30+10', '2099-01-02 14:00+10', 8.5, 0,
       'APPROVED', 'ACCEPTED', '{}'::jsonb
from (values
  ('00000000-0000-0000-0000-000000000001'::uuid, 1, 'negative:1'),
  ('00000000-0000-0000-0000-000000000002'::uuid, 2, 'negative:2')
) x(id, batch_no, source_row_key)
join _test_batches b on b.n = x.batch_no
cross join _test_org o;
insert into public.labour_segments
  (organization_id, import_batch_id, source_timesheet_row_id, person_key,
   area_code, segment_start, segment_end, calendar_date, operational_date,
   hour_bucket, shift_code, paid_hours, regular_hours, overtime_hours,
   paid_break_hours, productive_hours, approval_status, week_start)
select o.id, b.id, '00000000-0000-0000-0000-000000000002'::uuid,
       'NAME:NEGATIVE', 'DTG_OPERATOR', '2099-01-02 05:30+10',
       '2099-01-02 06:30+10', date '2099-01-02', date '2099-01-02',
       5, 'SHIFT_1', 1, 1, 0, 0, 1, 'APPROVED', date '2098-12-29'
from _test_org o cross join _test_batches b where b.n = 2;
do $$
begin
  if not exists (
    select 1
    from public.deputy_raw_timesheets representative
    join public.deputy_raw_timesheets sibling
      on sibling.organization_id = representative.organization_id
     and sibling.person_key = representative.person_key
     and sibling.timesheet_date = representative.timesheet_date
     and sibling.raw_area = representative.raw_area
     and sibling.normalized_area = representative.normalized_area
     and sibling.start_at = representative.start_at
     and sibling.end_at = representative.end_at
     and sibling.total_hours = representative.total_hours
     and sibling.meal_break_hours = representative.meal_break_hours
     and sibling.approval_status = representative.approval_status
     and sibling.row_status = representative.row_status
     and sibling.source_timesheet_id is not distinct from representative.source_timesheet_id
     and sibling.id <> representative.id
    where representative.id = '00000000-0000-0000-0000-000000000001'::uuid
      and sibling.id = '00000000-0000-0000-0000-000000000002'::uuid
      and not exists (select 1 from public.labour_segments s where s.source_timesheet_row_id = representative.id)
      and exists (select 1 from public.labour_segments s where s.source_timesheet_row_id = sibling.id)
      and not exists (select 1 from public.v_current_labour_segments v where v.source_timesheet_row_id = sibling.id)
  ) then
    raise exception 'missing-representative-segments audit failed to detect the fixture';
  end if;
end $$;
rollback to savepoint missing_representative_segments;
release savepoint missing_representative_segments;

rollback;
