CREATE OR REPLACE FUNCTION public.enforce_manufacturing_order_line_boundary()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare parent production_orders%rowtype; demand production_demand_lines%rowtype;
begin
  select * into strict parent from production_orders where id=new.manufacturing_order_id and organization_id=new.organization_id;
  if parent.source_order_no is distinct from new.source_order_no then raise exception 'MO line Sales Order must equal parent Sales Order';end if;
  if parent.source_routing_id is distinct from new.routing_revision_id then raise exception 'MO line Routing must equal parent Routing';end if;
  if new.production_demand_line_id is not null then
    select * into strict demand from production_demand_lines where id=new.production_demand_line_id and organization_id=new.organization_id;
    if (demand.source_order_no,demand.source_order_line_id,demand.product_id,demand.routing_revision_id) is distinct from
       (new.source_order_no,new.source_order_line_id,new.product_id,new.routing_revision_id) then
      raise exception 'MO line does not match its demand line';
    end if;
  end if;
  new.updated_at:=now();return new;
end$function$
;

