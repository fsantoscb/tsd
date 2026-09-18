CREATE OR REPLACE FUNCTION public.enforce_sync_batch_organization()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
$function$
;

