CREATE OR REPLACE FUNCTION public.update_manufacturing_order_line_quantity(p_organization_id uuid, p_source_system text, p_source_order_no text, p_source_order_line_id text, p_new_quantity numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d production_demand_lines%rowtype;line manufacturing_order_lines%rowtype;po production_orders%rowtype;
begin
  if p_new_quantity<=0 then raise exception 'Quantity must be positive';end if;
  select * into strict d from production_demand_lines where organization_id=p_organization_id and source_system=p_source_system and source_order_no=p_source_order_no and source_order_line_id=p_source_order_line_id for update;
  select * into line from manufacturing_order_lines where production_demand_line_id=d.id;
  if line.id is null then update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;return 'DEMAND_UPDATED';end if;
  select * into strict po from production_orders where id=line.manufacturing_order_id for update;
  if po.production_status in('UNROUTED','PLANNED','RELEASED') then
    update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;
    update manufacturing_order_lines set planned_quantity=p_new_quantity where id=line.id;
    return 'MO_UPDATED';
  end if;
  insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
  values(p_organization_id,po.id,'SOURCE_QUANTITY_CHANGE',format('Source quantity changed from %s to %s (delta %s)',d.quantity,p_new_quantity,p_new_quantity-d.quantity),'ORDER_LINE',p_source_order_no||':'||p_source_order_line_id);
  return 'EXCEPTION_CREATED';
end$function$
;

