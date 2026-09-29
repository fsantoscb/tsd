-- Run only against an authorized disposable database after the metadata migration.
-- This test does not certify Production or activate snapshot authority.
do $$
declare
  column_count integer;
  constraint_count integer;
begin
  select count(*) into column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'deputy_import_batches'
    and is_nullable = 'YES'
    and column_default is null
    and (
      (column_name in ('report_generated_at', 'certified_at') and data_type = 'timestamp with time zone')
      or (column_name in ('coverage_start', 'coverage_end') and data_type = 'date')
      or (column_name in ('snapshot_type', 'certified_by', 'certification_note') and data_type = 'text')
    );
  if column_count <> 7 then
    raise exception 'Deputy snapshot metadata columns differ from nullable contract';
  end if;

  select count(*) into constraint_count
  from pg_constraint
  where conrelid = 'public.deputy_import_batches'::regclass
    and conname in (
      'deputy_snapshot_type_check',
      'deputy_snapshot_coverage_order_check',
      'deputy_full_snapshot_certification_check'
    );
  if constraint_count <> 3 then
    raise exception 'Deputy snapshot metadata checks are missing';
  end if;
end $$;
