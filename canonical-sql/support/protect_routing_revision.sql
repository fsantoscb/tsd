CREATE OR REPLACE FUNCTION public.protect_routing_revision()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if tg_op='DELETE' and old.status<>'DRAFT' then raise exception 'Only draft routing revisions may be deleted';end if;
  if tg_op='UPDATE' and old.status='ACTIVE' and (new.code,new.name,new.revision,new.effective_from,new.organization_id)is distinct from(old.code,old.name,old.revision,old.effective_from,old.organization_id)then raise exception 'Active routing revisions are immutable';end if;
  if tg_op='UPDATE' and old.status='INACTIVE' and new is distinct from old then raise exception 'Inactive routing revisions are immutable';end if;
  if tg_op='UPDATE' and not((old.status=new.status)or(old.status='DRAFT'and new.status in('ACTIVE','INACTIVE'))or(old.status='ACTIVE'and new.status='INACTIVE'))then raise exception 'Invalid routing status transition';end if;
  return case when tg_op='DELETE'then old else new end;
end$function$
;

