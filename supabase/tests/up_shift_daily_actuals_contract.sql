-- Authorized disposable DB ONLY. Apply the Stage A migration first.
-- Explicit opt-in: SET tsd.disposable_db = 'true';
-- Run with psql -v ON_ERROR_STOP=1; all fixture writes roll back.
begin;
do $$ begin
  if current_setting('tsd.disposable_db', true) is distinct from 'true' then
    raise exception 'DISPOSABLE_DATABASE_REQUIRED';
  end if;
  if to_regclass('public.up_shift_daily_actuals') is null then
    raise exception 'UP_SHIFT_SCHEMA_MISSING';
  end if;
end $$;

create temporary table old_up_contract as
select
  (select jsonb_agg(to_jsonb(c) order by ordinal_position) from information_schema.columns c
   where table_schema='public' and table_name='up_daily_actuals') column_contract,
  (select jsonb_agg(to_jsonb(r) order by id) from public.up_daily_actuals r) row_contract,
  (select pg_get_functiondef(oid) from pg_proc where oid=
   'public.replace_up_daily_actuals(uuid,date,date,jsonb)'::regprocedure) writer;

create function pg_temp.expect_error(statement text, expected_state text)
returns void language plpgsql as $$
declare actual_state text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual_state = returned_sqlstate;
    if actual_state <> expected_state then
      raise exception 'Unexpected SQLSTATE %, expected %', actual_state, expected_state;
    end if;
    return;
  end;
  raise exception 'Statement unexpectedly succeeded: %', statement;
end $$;

insert into public.organizations(id,name)
values ('00000000-0000-4000-8000-000000000a01','UP disposable contract fixture');

insert into public.up_shift_daily_actuals
  (organization_id,operational_date,shift_code,garments,source_event_count,source_snapshot_id,calculation_version)
select '00000000-0000-4000-8000-000000000a01','2026-09-29',s,2058.053,1,
  '00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1'
from unnest(array['SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT']) s;

do $test$
declare prefix text := 'insert into public.up_shift_daily_actuals (organization_id,operational_date,shift_code,garments,source_event_count,source_snapshot_id,calculation_version) values ';
begin
  if (select count(*) from public.up_shift_daily_actuals where organization_id='00000000-0000-4000-8000-000000000a01'
      and garments=2058.053 and source_event_count=1) <> 4 then
    raise exception 'Valid shifts or exact fractional numeric round-trip failed';
  end if;
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a01','2026-09-30','INVALID',1,1,'00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23514');
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a01','2026-09-29','SHIFT_1',1,1,'00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23505');
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a01','2026-09-30','SHIFT_1',-1,1,'00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23514');
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a01','2026-09-30','SHIFT_1',1,-1,'00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23514');
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a99','2026-09-30','SHIFT_1',1,1,'00000000-0000-4000-8000-000000000a02','UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23503');
  perform pg_temp.expect_error(prefix || $$('00000000-0000-4000-8000-000000000a01','2026-09-30','SHIFT_1',1,1,null,'UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')$$, '23502');
  perform pg_temp.expect_error($$update public.up_shift_daily_actuals set status='UNKNOWN' where organization_id='00000000-0000-4000-8000-000000000a01'$$, '23514');
end $test$;

do $$
declare relation regclass := 'public.up_shift_daily_actuals'::regclass;
begin
  if (select count(*) from information_schema.columns where table_schema='public' and table_name='up_shift_daily_actuals') <> 12
    or exists (select 1 from information_schema.columns where table_schema='public' and table_name='up_shift_daily_actuals'
      and (column_name='jobs' or (column_name='source_snapshot_id' and (is_nullable<>'NO' or column_default is not null)))) then
    raise exception 'Shift schema shape or snapshot contract changed';
  end if;
  if (select pg_get_userbyid(relowner) <> 'postgres' or not relrowsecurity from pg_class where oid=relation) then
    raise exception 'Owner/RLS contract changed';
  end if;
  if not has_table_privilege('authenticated',relation,'SELECT')
    or has_table_privilege('authenticated',relation,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
    or has_table_privilege('anon',relation,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then
    raise exception 'Read-only/anonymous ACL contract changed';
  end if;
  if not has_table_privilege('service_role',relation,'SELECT') or not has_table_privilege('service_role',relation,'INSERT')
    or not has_table_privilege('service_role',relation,'UPDATE') or not has_table_privilege('service_role',relation,'DELETE') then
    raise exception 'Service role ingest access missing';
  end if;
  if (select count(*) from pg_policy where polrelid=relation) <> 1
    or exists(select 1 from pg_policy where polrelid=relation
      and (polcmd <> 'r' or not polpermissive or polroles <> array[(select oid from pg_roles where rolname='authenticated')]))
    or (select pg_get_expr(polqual,polrelid) from pg_policy where polrelid=relation) is distinct from
       (select pg_get_expr(polqual,polrelid) from pg_policy where polrelid='public.up_daily_actuals'::regclass and polname='up_daily_actuals_read') then
    raise exception 'Organization SELECT policy differs from daily authority';
  end if;
  if exists(select 1 from pg_constraint where conrelid=relation and contype='f' and (confdeltype<>'a' or confupdtype<>'a'))
    or (select count(*) from pg_constraint where conrelid=relation and contype='f') <> 1 then
    raise exception 'Organization FK semantics changed';
  end if;
  if (select count(*) from pg_index where indrelid=relation) <> 2
    or exists(select 1 from pg_trigger where tgrelid=relation and not tgisinternal) then
    raise exception 'Unexpected index or user trigger';
  end if;
  if exists(select 1 from old_up_contract b where
    b.column_contract is distinct from (select jsonb_agg(to_jsonb(c) order by ordinal_position) from information_schema.columns c where table_schema='public' and table_name='up_daily_actuals')
    or b.row_contract is distinct from (select jsonb_agg(to_jsonb(r) order by id) from public.up_daily_actuals r)
    or b.writer is distinct from (select pg_get_functiondef('public.replace_up_daily_actuals(uuid,date,date,jsonb)'::regprocedure))) then
    raise exception 'Existing daily contract/data/writer changed';
  end if;
end $$;
rollback;
