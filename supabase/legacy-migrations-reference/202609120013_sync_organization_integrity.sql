create or replace function public.enforce_sync_batch_organization()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  batch_organization_id uuid;
begin
  select organization_id
    into batch_organization_id
    from public.sync_batches
   where id = new.sync_batch_id;

  if batch_organization_id is null then
    raise exception 'SYNC_BATCH_NOT_FOUND';
  end if;

  if batch_organization_id is distinct from new.organization_id then
    raise exception 'SYNC_BATCH_ORGANIZATION_MISMATCH';
  end if;

  return new;
end;
$$;

drop trigger if exists source_orders_batch_organization on public.source_orders;
create trigger source_orders_batch_organization
before insert or update of organization_id, sync_batch_id on public.source_orders
for each row execute function public.enforce_sync_batch_organization();

drop trigger if exists source_workbank_batch_organization on public.source_workbank_items;
create trigger source_workbank_batch_organization
before insert or update of organization_id, sync_batch_id on public.source_workbank_items
for each row execute function public.enforce_sync_batch_organization();

drop trigger if exists source_stock_batch_organization on public.source_stock_items;
create trigger source_stock_batch_organization
before insert or update of organization_id, sync_batch_id on public.source_stock_items
for each row execute function public.enforce_sync_batch_organization();

revoke all on function public.enforce_sync_batch_organization() from public, anon, authenticated;
