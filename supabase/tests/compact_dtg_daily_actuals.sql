begin;

do $$
declare
  v_organization_id uuid;
begin
  select id into strict v_organization_id from public.organizations limit 1;

  delete from public.production_daily_actuals
  where organization_id = v_organization_id
    and operational_date = date '2099-01-01'
    and process = 'DTG';

  insert into public.production_daily_actuals(
    organization_id, operational_date, process, machine_code, shift_code,
    garments, prints, source_event_count, calculation_version
  ) values
    (v_organization_id, date '2099-01-01', 'DTG', 'TEST_MACHINE', 'SHIFT_1', 1, 1, 1, 'COMPACT_CONTRACT_TEST'),
    (v_organization_id, date '2099-01-01', 'DTG', 'TEST_MACHINE', 'SHIFT_2', 2, 3, 2, 'COMPACT_CONTRACT_TEST'),
    (v_organization_id, date '2099-01-01', 'DTG', 'TEST_MACHINE', 'OVERTIME', 4, 5, 4, 'COMPACT_CONTRACT_TEST');

  if (select count(*) from public.production_daily_actuals where organization_id = v_organization_id and operational_date = date '2099-01-01' and process = 'DTG') <> 3 then
    raise exception 'COMPACT_DTG_SHIFT_GRAIN_FAILED';
  end if;
end $$;

rollback;
