CREATE OR REPLACE FUNCTION public.enforce_production_resource_asset_organization()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin if new.asset_id is not null and not exists(select 1 from maintenance_assets a where a.id=new.asset_id and a.organization_id=new.organization_id)then raise exception 'Production resource asset must belong to the same organization';end if;return new;end$function$
;

