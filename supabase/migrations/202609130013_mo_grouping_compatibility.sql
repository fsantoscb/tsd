-- Compatibility follow-up for databases where 202609130012 was already applied.
alter table production_orders drop constraint if exists production_orders_mo_identity_check;
alter table production_orders add constraint production_orders_mo_identity_check check(
  source_routing_id is null or nullif(trim(source_order_no),'') is not null
);

drop function if exists create_manufacturing_orders(uuid,text);
create function create_manufacturing_orders(p_organization_id uuid,p_source_system text default 'ORACLE_WMS')
returns table(out_manufacturing_order_id uuid,out_mo_number text,out_source_order_no text,out_routing_id uuid,out_planned_quantity numeric)
language plpgsql security definer set search_path=public as $$
declare g record;mo uuid;number text;
begin
  for g in
    select d.source_order_no,d.routing_revision_id,sum(d.quantity)::numeric(14,3) qty,
      min(d.due_date)::date planned_date,min(d.planner_priority) planner_priority,r.code routing_code
    from production_demand_lines d join routings r on r.id=d.routing_revision_id and r.organization_id=d.organization_id
    where d.organization_id=p_organization_id and d.source_system=p_source_system and d.status='READY' and d.resolution_status='RESOLVED'
    group by d.source_order_no,d.routing_revision_id,r.code order by d.source_order_no,r.code
  loop
    number:='MO-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code||'-1';
    insert into production_orders(organization_id,order_no,mo_number,source_system,source_order_no,source_routing_id,planned_quantity,planned_date,planner_priority,split_number)
    values(p_organization_id,number,number,p_source_system,g.source_order_no,g.routing_revision_id,g.qty,g.planned_date,g.planner_priority,1)
    on conflict on constraint production_orders_so_routing_split_key do update set updated_at=now()
    returning id into mo;
    insert into manufacturing_order_lines(organization_id,manufacturing_order_id,production_demand_line_id,source_order_no,source_order_line_id,product_id,routing_revision_id,planned_quantity,sequence)
    select d.organization_id,mo,d.id,d.source_order_no,d.source_order_line_id,d.product_id,d.routing_revision_id,d.quantity,
      row_number()over(order by d.source_order_line_id)::integer
    from production_demand_lines d where d.organization_id=p_organization_id and d.source_system=p_source_system
      and d.source_order_no=g.source_order_no and d.routing_revision_id=g.routing_revision_id and d.status='READY' and d.resolution_status='RESOLVED'
    on conflict(production_demand_line_id) do nothing;
    update production_demand_lines set status='GROUPED',updated_at=now() where organization_id=p_organization_id and source_system=p_source_system
      and source_order_no=g.source_order_no and routing_revision_id=g.routing_revision_id and status='READY';
    return query select po.id,po.mo_number,po.source_order_no,po.source_routing_id,po.planned_quantity from production_orders po where po.id=mo;
  end loop;
end$$;
revoke all on function create_manufacturing_orders(uuid,text) from public,anon,authenticated;
grant execute on function create_manufacturing_orders(uuid,text) to service_role;
