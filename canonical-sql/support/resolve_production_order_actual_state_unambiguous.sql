CREATE OR REPLACE FUNCTION public.resolve_production_order_actual_state_unambiguous(p_organization_id uuid, p_production_order_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(orders_resolved integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_orders integer:=0; v_evidence integer:=0; v_exceptions integer:=0; v_count integer;
begin
  perform seed_source_operation_mappings(p_organization_id);

  with inserted as (
    insert into production_order_operation_evidence(
      organization_id,production_order_id,production_order_operation_id,source_mapping_id,source_dataset,
      source_record_key,source_audit_event_id,semantics,observed_at,quantity,source_value)
    select po.organization_id,po.id,poo.id,e.source_mapping_id,e.source_dataset,e.source_record_key,
      e.source_audit_event_id,e.completion_semantics,e.observed_at,e.quantity,e.source_value
    from production_orders po
    join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    join production_order_operations poo on poo.production_order_id=po.id
      and poo.organization_id=po.organization_id and poo.source_operation_id=e.operation_id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    on conflict do nothing returning 1
  ) select count(*) into v_evidence from inserted;

  with touched as (
    update production_order_operations poo set
      status=case
        when x.has_completion then 'COMPLETED'
        when poo.status in ('PENDING','READY') and x.has_entry then 'IN_PROGRESS'
        else poo.status end,
      started_at=coalesce(poo.started_at,x.first_observed_at),
      completed_at=case when x.has_completion then coalesce(poo.completed_at,x.last_completion_at) else poo.completed_at end,
      actual_quantity=greatest(poo.actual_quantity,coalesce(x.observed_quantity,0)),updated_at=now()
    from (
      select production_order_operation_id,
        bool_or(semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) has_completion,
        bool_or(semantics in ('CURRENT_LOCATION','ENTERED_OPERATION','MOVED_TO_OPERATION')) has_entry,
        min(observed_at) first_observed_at,
        max(observed_at) filter(where semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) last_completion_at,
        sum(coalesce(quantity,0)) observed_quantity
      from production_order_operation_evidence
      where organization_id=p_organization_id and (p_production_order_id is null or production_order_id=p_production_order_id)
      group by production_order_operation_id
    ) x where poo.id=x.production_order_operation_id
    returning poo.production_order_id
  ) select count(distinct production_order_id) into v_orders from touched;

  with observed as (
    select po.id production_order_id,max(poo.sequence) max_observed_sequence
    from production_orders po join production_order_operations poo on poo.production_order_id=po.id
    join production_order_operation_evidence e on e.production_order_operation_id=poo.id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    group by po.id
  ), inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,production_order_operation_id,exception_type,description)
    select poo.organization_id,poo.production_order_id,poo.id,'SKIPPED_OPERATION',
      'Required operation '||poo.operation_code_snapshot||' has no source evidence before a later observed operation.'
    from observed o join production_order_operations poo on poo.production_order_id=o.production_order_id
    where poo.required and poo.sequence<o.max_observed_sequence
      and not exists(select 1 from production_order_operation_evidence e where e.production_order_operation_id=poo.id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  with inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
    select po.organization_id,po.id,'UNEXPECTED_OPERATION',
      'Mapped source operation is not present in the Production Order routing snapshot.',e.source_dataset,e.source_record_key
    from production_orders po join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
      and not exists(select 1 from production_order_operations poo where poo.production_order_id=po.id and poo.source_operation_id=e.operation_id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  update production_orders po set
    production_status=case
      when not exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status<>'COMPLETED') then 'COMPLETED'
      when exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status='IN_PROGRESS') then 'IN_PROGRESS'
      else po.production_status end,
    actual_quantity=coalesce((select max(x.actual_quantity) from production_order_operations x where x.production_order_id=po.id),po.actual_quantity),
    updated_at=now()
  where po.organization_id=p_organization_id and po.production_status<>'UNROUTED'
    and (p_production_order_id is null or po.id=p_production_order_id);

  return query select v_orders,v_evidence,v_exceptions;
end $function$
;

