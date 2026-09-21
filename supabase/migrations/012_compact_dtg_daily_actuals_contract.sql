begin;

alter table public.production_daily_actuals
  drop constraint if exists production_daily_actuals_organization_id_operational_date_p_key;

alter table public.production_daily_actuals
  drop constraint if exists production_daily_actuals_shift_code_check;

alter table public.production_daily_actuals
  add constraint production_daily_actuals_shift_code_check
  check (shift_code = any (array['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OVERTIME'::text, 'OUT_OF_SHIFT'::text]));

alter table public.production_daily_actuals
  drop constraint if exists production_daily_actuals_shift_grain_key;

alter table public.production_daily_actuals
  add constraint production_daily_actuals_shift_grain_key
  unique (organization_id, operational_date, process, machine_code, shift_code);

commit;
