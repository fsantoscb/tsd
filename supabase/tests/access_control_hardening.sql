begin;

do $$
declare v_count integer;
begin
  select count(*) into v_count
  from pg_policies
  where schemaname='public'
    and (roles @> array['public']::name[] or roles @> array['anon']::name[]);
  if v_count <> 0 then raise exception 'unjustified public/anon policies remain: %',v_count; end if;

  select count(*) into v_count
  from information_schema.role_table_grants
  where table_schema='public' and grantee='anon';
  if v_count <> 0 then raise exception 'anon table grants remain: %',v_count; end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='has_org_role' and p.prosecdef
  ) then raise exception 'central security-definer role helper missing'; end if;

  if exists (
    select 1 from pg_policies
    where schemaname='public'
      and policyname in ('manufacturing_order_lines_manage','production_demand_lines_manage')
  ) then raise exception 'service-owned derived tables retain human manage policies'; end if;
end $$;

rollback;
