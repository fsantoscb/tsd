-- A routed MO may contain multiple products, so product ownership lives on MO lines.
create or replace function prepare_production_order_snapshot()returns trigger language plpgsql security definer set search_path=public as $$
declare p products%rowtype;r routings%rowtype;resolved_routing uuid;
begin
  if tg_op='UPDATE'and old.source_routing_id is not null and(new.product_id,new.source_routing_id,new.routing_code_snapshot,new.routing_name_snapshot,new.routing_revision_snapshot)is distinct from(old.product_id,old.source_routing_id,old.routing_code_snapshot,old.routing_name_snapshot,old.routing_revision_snapshot)then
    raise exception 'Production order routing snapshot is immutable';
  end if;
  if new.product_id is null and new.source_routing_id is null then return new;end if;
  if new.product_id is not null then
    select * into p from products where id=new.product_id and organization_id=new.organization_id and active;
    if p.id is null then raise exception 'Invalid or inactive product';end if;
  end if;
  resolved_routing:=coalesce(new.source_routing_id,p.default_routing_id);
  select * into r from routings where id=resolved_routing and organization_id=new.organization_id and status='ACTIVE'and active
    and(effective_from is null or effective_from<=current_date)and(effective_to is null or effective_to>=current_date);
  if r.id is null then raise exception 'Manufacturing Order requires an active effective routing';end if;
  if not exists(select 1 from routing_operations where routing_id=r.id and organization_id=r.organization_id)then raise exception 'Routing has no operations';end if;
  new.source_order_no:=coalesce(new.source_order_no,new.order_no);
  new.source_routing_id:=r.id;
  new.routing_code_snapshot:=r.code;
  new.routing_name_snapshot:=r.name;
  new.routing_revision_snapshot:=r.revision;
  if new.production_status='UNROUTED'then new.production_status:='PLANNED';end if;
  return new;
end$$;
