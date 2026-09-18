-- public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p production_plans%rowtype;n text;po production_orders%rowtype;units numeric;seq integer;added integer:=0;begin select*into p from production_plans where id=p_plan_id for update;if p.id is null then raise exception 'Plan not found';end if;if p.status<>'draft'then raise exception 'Only drafts can be edited';end if;select coalesce(max(sequence),0)into seq from production_plan_items where production_plan_id=p_plan_id;foreach n in array p_order_nos loop select*into po from production_orders where organization_id=p.organization_id and order_no=n and planning_status in('planned','ready','in_progress');if po.id is null then raise exception 'Order % is not planned',n;end if;select remaining_units into units from v_production_planning where organization_id=p.organization_id and order_no=n and line=(select code from production_areas where id=p.production_area_id)limit 1;if units is null or units<=0 then raise exception 'Order unavailable in area';end if;seq=seq+1;insert into production_plan_items(production_plan_id,production_order_id,order_no,sequence,planned_units,special_instruction)values(p_plan_id,po.id,n,seq,units,po.special_instruction)on conflict(production_plan_id,production_order_id)do nothing;if found then added=added+1;end if;end loop;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)values(p_plan_id,'items_added',p_actor_id,p_actor_email,jsonb_build_object('orders',p_order_nos,'added',added));return added;end$function$
;

-- public.append_oracle_line_ingestion_batch(p_organization_id uuid, p_run_id uuid, p_lines jsonb, p_first_order_no text, p_first_line_number integer, p_last_order_no text, p_last_line_number integer)
CREATE OR REPLACE FUNCTION public.append_oracle_line_ingestion_batch(p_organization_id uuid, p_run_id uuid, p_lines jsonb, p_first_order_no text, p_first_line_number integer, p_last_order_no text, p_last_line_number integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare r oracle_line_ingestion_runs;n integer;bn integer;started timestamptz:=clock_timestamp();begin select*into r from oracle_line_ingestion_runs where id=p_run_id and organization_id=p_organization_id for update;if r.status<>'RUNNING'or r.snapshot_status<>'PARTIAL'then raise exception'INGESTION_RUN_NOT_RUNNING';end if;if r.last_order_no is not null and(p_first_order_no<r.last_order_no or(p_first_order_no=r.last_order_no and p_first_line_number<=r.last_line_number))then raise exception'NON_MONOTONIC_CURSOR';end if;select count(*)into n from jsonb_array_elements(p_lines);if n=0 or n>r.batch_size then raise exception'INVALID_BATCH_SIZE';end if;bn:=r.batches_completed+1;
insert into oracle_line_ingestion_staging(organization_id,ingestion_run_id,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at,source_routing,source_operational_code,source_operational_codes,operational_code_conflict,process_origin_code,process_origin_codes,process_origin_conflict,process_origin_at)
select p_organization_id,p_run_id,x."orderNo",x."lineNumber"::text,x."productCode",x."sourceDescription",greatest(coalesce(x.quantity,0),0),case upper(trim(coalesce(x.released,'')))when'Y'then true when'N'then false else null end,upper(trim(coalesce(x.released,''))),x."sourceStatus",x."quantityProcessed",x.weight,x."stockReservedFlag",x."sourceUpdatedAt",x."sourceRouting",x."sourceOperationalCode",x."sourceOperationalCodes",coalesce(x."operationalCodeConflict",false),x."processOriginCode",x."processOriginCodes",coalesce(x."processOriginConflict",false),x."processOriginAt"
from jsonb_to_recordset(p_lines)x("orderNo"text,"lineNumber"integer,"productCode"text,"sourceDescription"text,quantity numeric,weight numeric,released text,"sourceStatus"text,"quantityProcessed"numeric,"stockReservedFlag"text,"sourceUpdatedAt"timestamptz,"sourceRouting"text,"sourceOperationalCode"text,"sourceOperationalCodes"text,"operationalCodeConflict"boolean,"processOriginCode"text,"processOriginCodes"text,"processOriginConflict"boolean,"processOriginAt"timestamptz)
on conflict(ingestion_run_id,source_order_no,source_line_id)do update set source_product_code=excluded.source_product_code,source_description=excluded.source_description,production_units=excluded.production_units,released=excluded.released,raw_release_value=excluded.raw_release_value,source_line_status=excluded.source_line_status,quantity_processed=excluded.quantity_processed,source_weight=excluded.source_weight,stock_reserved_flag=excluded.stock_reserved_flag,source_updated_at=excluded.source_updated_at,source_routing=excluded.source_routing,source_operational_code=excluded.source_operational_code,source_operational_codes=excluded.source_operational_codes,operational_code_conflict=excluded.operational_code_conflict,process_origin_code=excluded.process_origin_code,process_origin_codes=excluded.process_origin_codes,process_origin_conflict=excluded.process_origin_conflict,process_origin_at=excluded.process_origin_at;
insert into oracle_line_ingestion_batches(organization_id,ingestion_run_id,batch_number,first_order_no,first_line_number,last_order_no,last_line_number,source_row_count,inserted_count,completed_at,duration_ms,sync_batch_id)values(p_organization_id,p_run_id,bn,p_first_order_no,p_first_line_number,p_last_order_no,p_last_line_number,n,n,clock_timestamp(),extract(epoch from(clock_timestamp()-started))*1000,r.sync_batch_id);update oracle_line_ingestion_runs set last_order_no=p_last_order_no,last_line_number=p_last_line_number,batches_completed=bn,rows_processed=rows_processed+n,updated_at=now()where id=p_run_id returning*into r;return jsonb_build_object('runId',r.id,'batchesCompleted',r.batches_completed,'rowsProcessed',r.rows_processed,'status',r.status);end$function$
;

-- public.apply_kpi_target_status()
CREATE OR REPLACE FUNCTION public.apply_kpi_target_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare t kpi_targets%rowtype;dir text;begin
select direction into dir from kpi_definitions where id=new.kpi_definition_id;
select*into t from kpi_targets where organization_id=new.organization_id and kpi_definition_id=new.kpi_definition_id and(production_area_id is null or production_area_id=new.production_area_id)and(shift_id is null or shift_id=new.shift_id)and effective_from<=new.production_date and(effective_to is null or effective_to>=new.production_date)order by(production_area_id is not null)desc,(shift_id is not null)desc,effective_from desc limit 1;
if new.value is null then new.status='NO_DATA';new.target_value=null;return new;end if;if t.id is null then new.status='NO_TARGET';new.target_value=null;return new;end if;new.target_value=t.target_value;
if dir='HIGHER_IS_BETTER'then new.status=case when new.value>=t.target_value then'GOOD'when t.warning_value is not null and new.value>=t.warning_value then'WARNING'else'CRITICAL'end;elsif dir='LOWER_IS_BETTER'then new.status=case when new.value<=t.target_value then'GOOD'when t.warning_value is not null and new.value<=t.warning_value then'WARNING'else'CRITICAL'end;else new.status=case when t.critical_value is not null and abs(new.value-t.target_value)>t.critical_value then'CRITICAL'when t.warning_value is not null and abs(new.value-t.target_value)>t.warning_value then'WARNING'else'GOOD'end;end if;return new;end$function$
;

-- public.apply_production_planning(p_organization_id uuid, p_order_nos text[], p_changes jsonb, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.apply_production_planning(p_organization_id uuid, p_order_nos text[], p_changes jsonb, p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n text; row_id uuid; old_row jsonb; new_row jsonb; old_status text; new_status text; changed integer:=0;
begin
  if coalesce(array_length(p_order_nos,1),0)=0 then raise exception 'At least one order is required'; end if;
  if p_changes ? 'planned_shift_id' and nullif(p_changes->>'planned_shift_id','') is not null and not exists(select 1 from shift_templates where id=(p_changes->>'planned_shift_id')::uuid and organization_id=p_organization_id and active) then raise exception 'Invalid shift'; end if;
  foreach n in array p_order_nos loop
    if not exists(select 1 from v_current_orders where organization_id=p_organization_id and order_no=n) then raise exception 'Unknown source order %',n; end if;
    insert into production_orders(organization_id,order_no,updated_by) values(p_organization_id,n,p_actor_id) on conflict do nothing;
    select id,to_jsonb(po),planning_status into row_id,old_row,old_status from production_orders po where organization_id=p_organization_id and order_no=n for update;
    new_status=coalesce(nullif(p_changes->>'planning_status',''),old_status);
    if new_status<>old_status and not ((old_status='unplanned' and new_status in ('planned','cancelled')) or (old_status='planned' and new_status in ('unplanned','ready','blocked','waiting','cancelled')) or (old_status='ready' and new_status in ('planned','in_progress','blocked','waiting','cancelled')) or (old_status='in_progress' and new_status in ('blocked','waiting','completed','cancelled')) or (old_status in ('blocked','waiting') and new_status in ('planned','ready','in_progress','cancelled')) or (old_status in ('completed','cancelled') and new_status='unplanned')) then raise exception 'Invalid status transition: % to %',old_status,new_status; end if;
    update production_orders set
      planner_priority=case when p_changes?'planner_priority' then nullif(p_changes->>'planner_priority','')::integer else planner_priority end,
      planned_date=case when p_changes?'planned_date' then nullif(p_changes->>'planned_date','')::date else planned_date end,
      planned_shift_id=case when p_changes?'planned_shift_id' then nullif(p_changes->>'planned_shift_id','')::uuid else planned_shift_id end,
      planning_status=new_status,
      special_instruction=case when p_changes?'special_instruction' then nullif(trim(p_changes->>'special_instruction'),'') else special_instruction end,
      planner_note=case when p_changes?'planner_note' then nullif(trim(p_changes->>'planner_note'),'') else planner_note end,
      blocked_reason=case when new_status='blocked' then nullif(trim(p_changes->>'blocked_reason'),'') else null end,
      updated_at=now(),updated_by=p_actor_id where id=row_id returning to_jsonb(production_orders.*) into new_row;
    insert into production_order_history(production_order_id,organization_id,order_no,changed_by,changed_by_email,before_state,after_state) values(row_id,p_organization_id,n,p_actor_id,p_actor_email,old_row,new_row);
    changed=changed+1;
  end loop;
  return changed;
end $function$
;

-- public.assign_source_product_routing(p_source_sku text, p_product_family_id uuid, p_product_type_id uuid, p_routing_id uuid, p_process_code text)
CREATE OR REPLACE FUNCTION public.assign_source_product_routing(p_source_sku text, p_product_family_id uuid, p_product_type_id uuid, p_routing_id uuid, p_process_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare org uuid;pid uuid;begin select organization_id into org from maintenance_members where user_id=auth.uid()and active and role in('admin','supervisor')limit 1;if org is null then raise exception'Permission denied';end if;if p_process_code not in('DTG','UNDERPRINT','SCREEN_PRINT')then raise exception'Invalid process';end if;select product_id into pid from product_source_mappings where organization_id=org and source_system='ORACLE_WMS'and source_product_code=p_source_sku and active;if pid is null then insert into products(organization_id,sku,description,product_family_id,product_type_id,source_system,source_product_code)select org,p_source_sku,max(description),p_product_family_id,p_product_type_id,'ORACLE_WMS',p_source_sku from v_routing_product_coverage where organization_id=org and source_sku=p_source_sku returning id into pid;insert into product_source_mappings(organization_id,source_system,source_product_code,product_id)values(org,'ORACLE_WMS',p_source_sku,pid);else update products set product_family_id=p_product_family_id,product_type_id=p_product_type_id,updated_at=now()where id=pid and organization_id=org;end if;insert into product_routing_assignments(organization_id,product_id,process_code,routing_id,assignment_source,approved,approved_by,approved_at)values(org,pid,p_process_code,p_routing_id,'MANUAL',true,auth.uid(),now())on conflict(organization_id,product_id,process_code)do update set routing_id=excluded.routing_id,assignment_source='MANUAL',approved=true,approved_by=auth.uid(),approved_at=now(),updated_at=now();return pid;end$function$
;

-- public.backfill_active_wip_manufacturing_orders(p_organization_id uuid, p_source_system text)
CREATE OR REPLACE FUNCTION public.backfill_active_wip_manufacturing_orders(p_organization_id uuid, p_source_system text DEFAULT 'ORACLE_WMS'::text)
 RETURNS TABLE(run_id uuid, staged_lines integer, created_mos integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare rid uuid;staged integer:=0;mos integer:=0;ev integer:=0;ex integer:=0;cov integer:=0;r record;begin
insert into active_wip_backfill_runs(organization_id,source_system)values(p_organization_id,p_source_system)returning id into rid;
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,source_product_code,source_description,quantity,due_date,source_priority,status,resolution_status)
select w.organization_id,p_source_system,w.order_no,'WORKBANK:'||w.source_row_id,p.id,p.default_routing_id,p.default_routing_id,w.product_code,w.product_description,w.production_units,w.source_due_at,w.source_priority,case when p.id is not null and rt.id is not null then'READY'else'EXCEPTION'end,case when p.id is null then'PRODUCT_UNMAPPED'when rt.id is null then'ROUTING_UNMAPPED'else'RESOLVED'end from v_current_workbank w left join product_source_mappings pm on pm.organization_id=w.organization_id and pm.source_system=p_source_system and pm.source_product_code=w.product_code and pm.active left join products p on p.id=pm.product_id and p.organization_id=w.organization_id and p.active left join routings rt on rt.id=p.default_routing_id and rt.organization_id=w.organization_id and rt.status='ACTIVE'and rt.active and(rt.effective_from is null or rt.effective_from<=current_date)and(rt.effective_to is null or rt.effective_to>=current_date)where w.organization_id=p_organization_id and nullif(w.source_row_id,'')is not null and w.production_units>0 and w.product_code!~'^#?[0-9]+$'and(upper(trim(coalesce(w.queue,'')))in('SP11','PCOR')or upper(trim(coalesce(w.from_location,'')))like'%UP')
on conflict(organization_id,source_system,source_order_no,source_order_line_id)do update set product_id=excluded.product_id,routing_id=excluded.routing_id,routing_revision_id=excluded.routing_revision_id,source_product_code=excluded.source_product_code,source_description=excluded.source_description,quantity=excluded.quantity,due_date=excluded.due_date,source_priority=excluded.source_priority,status=case when production_demand_lines.status='GROUPED'then'GROUPED'else excluded.status end,resolution_status=case when production_demand_lines.status='GROUPED'then production_demand_lines.resolution_status else excluded.resolution_status end,updated_at=now();get diagnostics staged=row_count;
insert into production_demand_exceptions(organization_id,production_demand_line_id,exception_type,description)select d.organization_id,d.id,d.resolution_status,'Active WIP line requires governed Product and Routing setup before MO creation.'from production_demand_lines d where d.organization_id=p_organization_id and d.source_system=p_source_system and d.status='EXCEPTION'on conflict do nothing;get diagnostics ex=row_count;
select count(*)into mos from create_manufacturing_orders(p_organization_id,p_source_system);select*into r from resolve_production_order_actual_state(p_organization_id,null);ev:=coalesce(r.evidence_added,0);ex:=ex+coalesce(r.exceptions_added,0);
insert into active_wip_coverage_exceptions(organization_id,source_system,source_order_no,stage_code,units,primary_cause,blocking_cause,explanation,status)select c.organization_id,p_source_system,c.source_order_no,c.stage_code,c.units,'PRE_EXISTING_WIP',case when not c.line_source_available then'SOURCE_LINE_MISSING'when exists(select 1 from production_demand_lines d where d.organization_id=c.organization_id and d.source_order_no=c.source_order_no and d.resolution_status='PRODUCT_UNMAPPED')then'PRODUCT_UNMAPPED'when exists(select 1 from production_demand_lines d where d.organization_id=c.organization_id and d.source_order_no=c.source_order_no and d.resolution_status in('ROUTING_UNMAPPED','ROUTING_INACTIVE'))then'ROUTING_UNMAPPED'else'MO_GENERATION_BUG'end,'Order was active before canonical MO coverage. No MO is fabricated from header-only or unmapped evidence.','ACCEPTED'from v_active_wip_mo_coverage c where c.organization_id=p_organization_id and c.canonical_mos=0 on conflict(organization_id,source_system,source_order_no,stage_code)do update set units=excluded.units,primary_cause=excluded.primary_cause,blocking_cause=excluded.blocking_cause,explanation=excluded.explanation,status='ACCEPTED',last_detected_at=now(),resolved_at=null;get diagnostics cov=row_count;ex:=ex+cov;
update active_wip_coverage_exceptions e set status='RESOLVED',resolved_at=now(),last_detected_at=now()where e.organization_id=p_organization_id and e.source_system=p_source_system and e.status<>'RESOLVED'and not exists(select 1 from v_active_wip_mo_coverage c where c.organization_id=e.organization_id and c.source_order_no=e.source_order_no and c.stage_code=e.stage_code and c.canonical_mos=0);
update active_wip_backfill_runs set completed_at=now(),staged_lines=staged,created_mos=mos,evidence_added=ev,exceptions_added=ex,status='COMPLETED'where id=rid;return query select rid,staged,mos,ev,ex;exception when others then update active_wip_backfill_runs set completed_at=now(),status='FAILED'where id=rid;raise;end$function$
;

-- public.backfill_phase_e51_pilot(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.backfill_phase_e51_pilot(p_organization_id uuid)
 RETURNS TABLE(pilot_orders integer, manufacturing_orders integer, demand_lines integer, evidence_rows integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare po_count integer:=0;mo_count integer:=0;line_count integer:=0;ev_count integer:=0;g record;moid uuid;mon text;begin
select count(*)into po_count from mo_backfill_pilot_orders where organization_id=p_organization_id and status='SELECTED';
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,source_product_code,source_description,quantity,due_date,source_priority,status,resolution_status,production_process_code)
select l.organization_id,'ORACLE_WMS',l.source_order_no,'E51:'||l.process_code||':'||l.source_line_id,p.id,rr.routing_id,rr.routing_id,l.source_sku,l.source_description,l.quantity,o.date_due,o.source_priority,case when rr.routing_id is null then'EXCEPTION'else'READY'end,case when rr.routing_id is null then'ROUTING_UNMAPPED'else'RESOLVED'end,l.process_code from v_active_source_product_lines l join mo_backfill_pilot_orders pilot on pilot.organization_id=l.organization_id and pilot.source_order_no=l.source_order_no and pilot.status='SELECTED'join product_source_mappings pm on pm.organization_id=l.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=l.source_sku and pm.active join products p on p.id=pm.product_id and p.active left join v_current_orders o on o.organization_id=l.organization_id and o.order_no=l.source_order_no cross join lateral(select resolve_product_process_routing(l.organization_id,p.id,l.process_code,null)routing_id)rr where l.organization_id=p_organization_id and l.source_sku is not null on conflict(organization_id,source_system,source_order_no,source_order_line_id)do update set product_id=excluded.product_id,routing_id=excluded.routing_id,routing_revision_id=excluded.routing_revision_id,quantity=excluded.quantity,due_date=excluded.due_date,source_priority=excluded.source_priority,production_process_code=excluded.production_process_code,status=case when production_demand_lines.status='GROUPED'then'GROUPED'else excluded.status end,resolution_status=case when production_demand_lines.status='GROUPED'then production_demand_lines.resolution_status else excluded.resolution_status end,updated_at=now();get diagnostics line_count=row_count;
for g in select d.source_order_no,d.routing_revision_id,d.production_process_code,sum(d.quantity)::numeric(14,3)qty,min(d.due_date)::date due_date,min(d.source_priority)priority,r.code routing_code from production_demand_lines d join routings r on r.id=d.routing_revision_id where d.organization_id=p_organization_id and d.source_system='ORACLE_WMS'and d.source_order_line_id like'E51:%'and d.status='READY'and d.resolution_status='RESOLVED'group by d.source_order_no,d.routing_revision_id,d.production_process_code,r.code loop mon:='MO-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code||'-1';insert into production_orders(organization_id,order_no,mo_number,source_system,source_order_no,source_routing_id,planned_quantity,planned_date,planner_priority,split_number)values(p_organization_id,mon,mon,'ORACLE_WMS',g.source_order_no,g.routing_revision_id,g.qty,g.due_date,g.priority,1)on conflict on constraint production_orders_so_routing_split_key do update set updated_at=now()returning id into moid;insert into manufacturing_order_lines(organization_id,manufacturing_order_id,production_demand_line_id,source_order_no,source_order_line_id,product_id,routing_revision_id,planned_quantity,sequence)select d.organization_id,moid,d.id,d.source_order_no,d.source_order_line_id,d.product_id,d.routing_revision_id,d.quantity,row_number()over(order by d.source_order_line_id)::integer from production_demand_lines d where d.organization_id=p_organization_id and d.source_order_no=g.source_order_no and d.routing_revision_id=g.routing_revision_id and d.source_order_line_id like'E51:%'on conflict(production_demand_line_id)do nothing;update production_demand_lines set status='GROUPED',updated_at=now()where organization_id=p_organization_id and source_order_no=g.source_order_no and routing_revision_id=g.routing_revision_id and source_order_line_id like'E51:%';mo_count:=mo_count+1;end loop;
with candidates as(select po.organization_id,po.id production_order_id,op.id operation_id,e.source_mapping_id,e.source_dataset,e.source_record_key,e.source_audit_event_id,e.completion_semantics,e.observed_at,e.quantity,e.source_value,row_number()over(partition by e.source_dataset,e.source_record_key,e.operation_id order by po.id)matches from production_orders po join mo_backfill_pilot_orders pilot on pilot.organization_id=po.organization_id and pilot.source_order_no=po.source_order_no join production_order_operations op on op.production_order_id=po.id join v_source_operation_evidence e on e.organization_id=po.organization_id and e.order_no=po.source_order_no and e.operation_id=op.source_operation_id where po.organization_id=p_organization_id and((po.routing_code_snapshot='DTG_STANDARD'and(e.source_dataset<>'STOCK'or e.source_value not ilike'%UNDERPRINT%'))or(po.routing_code_snapshot='UNDERPRINT_STANDARD'and(e.source_dataset='STOCK'or e.source_value ilike'%UP%'or e.source_value='UPMOVE')))),ins as(insert into production_order_operation_evidence(organization_id,production_order_id,production_order_operation_id,source_mapping_id,source_dataset,source_record_key,source_audit_event_id,semantics,observed_at,quantity,source_value)select organization_id,production_order_id,operation_id,source_mapping_id,source_dataset,source_record_key,source_audit_event_id,completion_semantics,observed_at,quantity,source_value from candidates where matches=1 on conflict do nothing returning 1)select count(*)into ev_count from ins;
with observed as(select e.production_order_id,max(op.sequence)sequence from production_order_operation_evidence e join production_order_operations op on op.id=e.production_order_operation_id where e.organization_id=p_organization_id and exists(select 1 from mo_backfill_pilot_orders p join production_orders po on po.organization_id=p.organization_id and po.source_order_no=p.source_order_no where po.id=e.production_order_id)group by e.production_order_id)update production_order_operations op set validation_provenance=case when op.sequence=o.sequence then'SOURCE_CONFIRMED'else'INFERRED'end,validation_note=case when op.sequence=o.sequence then'Current source evidence observed; timestamp retained from source.'else'Previous operation inferred from later current source state; no timestamp fabricated.'end,status=case when op.sequence=o.sequence and op.status in('PENDING','READY')then'IN_PROGRESS'else op.status end,actual_quantity=case when op.sequence=o.sequence then greatest(op.actual_quantity,coalesce((select sum(e.quantity)from production_order_operation_evidence e where e.production_order_operation_id=op.id),0))else op.actual_quantity end,started_at=case when op.sequence=o.sequence then coalesce(op.started_at,(select min(e.observed_at)from production_order_operation_evidence e where e.production_order_operation_id=op.id))else op.started_at end from observed o where op.production_order_id=o.production_order_id and op.sequence<=o.sequence;
update production_orders po set production_status='IN_PROGRESS',actual_quantity=coalesce((select max(actual_quantity)from production_order_operations op where op.production_order_id=po.id),0),updated_at=now()where po.organization_id=p_organization_id and exists(select 1 from mo_backfill_pilot_orders p where p.organization_id=po.organization_id and p.source_order_no=po.source_order_no)and exists(select 1 from production_order_operations op where op.production_order_id=po.id and op.status='IN_PROGRESS');update mo_backfill_pilot_orders p set status=case when exists(select 1 from production_orders po where po.organization_id=p.organization_id and po.source_order_no=p.source_order_no and po.source_routing_id is not null)then'BACKFILLED'else'EXCEPTION'end where p.organization_id=p_organization_id and p.status='SELECTED';return query select po_count,mo_count,line_count,ev_count;end$function$
;

-- public.begin_or_resume_oracle_line_ingestion(p_organization_id uuid, p_agent_id text, p_batch_size integer)
CREATE OR REPLACE FUNCTION public.begin_or_resume_oracle_line_ingestion(p_organization_id uuid, p_agent_id text, p_batch_size integer DEFAULT 1000)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare r oracle_line_ingestion_runs;begin select*into r from oracle_line_ingestion_runs where organization_id=p_organization_id and status in('RUNNING','FAILED')and snapshot_status='PARTIAL'order by started_at desc limit 1;if r.id is null then insert into oracle_line_ingestion_runs(organization_id,sync_batch_id,agent_id,batch_size)select p_organization_id,id,p_agent_id,p_batch_size from sync_batches where organization_id=p_organization_id and status='completed'order by completed_at desc limit 1 returning*into r;else update oracle_line_ingestion_runs set status='RUNNING',error=null,updated_at=now()where id=r.id returning*into r;end if;return jsonb_build_object('runId',r.id,'lastOrderNo',r.last_order_no,'lastLineNumber',r.last_line_number,'batchesCompleted',r.batches_completed,'rowsProcessed',r.rows_processed,'status',r.status);end$function$
;

-- public.bootstrap_phase_e5_master_data(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.bootstrap_phase_e5_master_data(p_organization_id uuid)
 RETURNS TABLE(products_created integer, mappings_created integer, assignments_created integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pc integer:=0;mc integer:=0;ac integer:=0;rid uuid;begin
 insert into product_families(organization_id,code,name)values(p_organization_id,'ADULT_TSHIRTS','Adult T-Shirts'),(p_organization_id,'KIDS_TSHIRTS','Kids T-Shirts'),(p_organization_id,'HOODIES_SWEATSHIRTS','Hoodies / Sweatshirts'),(p_organization_id,'TOTES','Totes'),(p_organization_id,'OTHER','Other'),(p_organization_id,'UNMAPPED','Unmapped')on conflict(organization_id,code)do nothing;
 insert into product_types(organization_id,code,name)values(p_organization_id,'GARMENT','Garment'),(p_organization_id,'ACCESSORY','Accessory'),(p_organization_id,'UNMAPPED','Unmapped')on conflict(organization_id,code)do nothing;
 insert into operations(organization_id,code,name)values(p_organization_id,'PICKING','Picking'),(p_organization_id,'DTG_PRINT','DTG Print'),(p_organization_id,'PUTWALL','Putwall'),(p_organization_id,'UNDERPRINT','Underprint'),(p_organization_id,'SCREEN_PRINT','Screen Print'),(p_organization_id,'DISPATCH','Dispatch')on conflict(organization_id,code)do nothing;
 insert into routings(organization_id,code,name,revision,status,active,effective_from)values(p_organization_id,'DTG_STANDARD','DTG Standard',1,'DRAFT',true,current_date),(p_organization_id,'UNDERPRINT_STANDARD','Underprint Standard',1,'DRAFT',true,current_date),(p_organization_id,'SCREEN_PRINT_STANDARD','Screen Print Standard',1,'DRAFT',true,current_date)on conflict(organization_id,code,revision)do nothing;
 insert into routing_operations(organization_id,routing_id,sequence,operation_id)select p_organization_id,r.id,x.sequence,o.id from(values('DTG_STANDARD',10,'PICKING'),('DTG_STANDARD',20,'DTG_PRINT'),('DTG_STANDARD',30,'PUTWALL'),('DTG_STANDARD',40,'DISPATCH'),('UNDERPRINT_STANDARD',10,'PICKING'),('UNDERPRINT_STANDARD',20,'UNDERPRINT'),('UNDERPRINT_STANDARD',30,'DISPATCH'),('SCREEN_PRINT_STANDARD',10,'PICKING'),('SCREEN_PRINT_STANDARD',20,'SCREEN_PRINT'),('SCREEN_PRINT_STANDARD',30,'DISPATCH'))x(routing_code,sequence,operation_code)join routings r on r.organization_id=p_organization_id and r.code=x.routing_code and r.revision=1 and r.status='DRAFT'join operations o on o.organization_id=p_organization_id and o.code=x.operation_code on conflict(routing_id,sequence)do nothing;
 update routings set status='ACTIVE',active=true where organization_id=p_organization_id and code in('DTG_STANDARD','UNDERPRINT_STANDARD','SCREEN_PRINT_STANDARD')and revision=1 and status='DRAFT';perform seed_source_operation_mappings(p_organization_id);
 insert into products(organization_id,sku,description,product_family_id,product_type_id,source_system,source_product_code)
 select c.organization_id,c.source_sku,max(c.description),pf.id,pt.id,'ORACLE_WMS',c.source_sku from v_routing_product_coverage c join product_families pf on pf.organization_id=c.organization_id and pf.name=c.suggested_product_family join product_types pt on pt.organization_id=c.organization_id and pt.code='GARMENT'where c.organization_id=p_organization_id and c.source_sku is not null and c.current_product_id is null group by c.organization_id,c.source_sku,pf.id,pt.id on conflict(organization_id,sku)do nothing;get diagnostics pc=row_count;
 insert into product_source_mappings(organization_id,source_system,source_product_code,product_id)select p_organization_id,'ORACLE_WMS',p.sku,p.id from products p where p.organization_id=p_organization_id and p.active and exists(select 1 from v_routing_product_coverage c where c.organization_id=p.organization_id and c.source_sku=p.sku)on conflict(organization_id,source_system,source_product_code)do nothing;get diagnostics mc=row_count;
 insert into product_routing_assignments(organization_id,product_id,process_code,routing_id,assignment_source,approved,approved_at)
 select distinct p_organization_id,p.id,c.process_code,r.id,'DETERMINISTIC_SOURCE',true,now()from v_routing_product_coverage c join product_source_mappings pm on pm.organization_id=c.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=c.source_sku join products p on p.id=pm.product_id join routings r on r.organization_id=c.organization_id and r.code=case c.process_code when'DTG'then'DTG_STANDARD'when'UNDERPRINT'then'UNDERPRINT_STANDARD'else'SCREEN_PRINT_STANDARD'end and r.status='ACTIVE'and r.active where c.organization_id=p_organization_id and c.source_sku is not null on conflict(organization_id,product_id,process_code)do nothing;get diagnostics ac=row_count;
 update products p set default_routing_id=x.routing_id,updated_at=now()from(select product_id,min(routing_id::text)::uuid routing_id from product_routing_assignments where organization_id=p_organization_id and approved group by product_id having count(distinct routing_id)=1)x where p.id=x.product_id and p.organization_id=p_organization_id and p.default_routing_id is null;
 return query select pc,mc,ac;end$function$
;

-- public.canonical_mo_planned_quantity(p_mo uuid)
CREATE OR REPLACE FUNCTION public.canonical_mo_planned_quantity(p_mo uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce(sum(ml.planned_quantity)filter(where d.status in('READY','GROUPED')),0)::numeric(14,3)from manufacturing_order_lines ml join production_demand_lines d on d.id=ml.production_demand_line_id where ml.manufacturing_order_id=p_mo$function$
;

-- public.capture_sales_order_release_transitions(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.capture_sales_order_release_transitions(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin insert into sales_order_release_history(organization_id,source_order_no,previous_release_status,new_release_status,eligibility_snapshot,blockers_snapshot,source_status_snapshot,source_sync_batch_id)select q.organization_id,q.source_order_no,h.new_release_status,q.release_status,q.release_eligibility,to_jsonb(q.release_blockers),jsonb_build_object('status',q.source_status,'date_released',q.date_released),q.sync_batch_id from v_release_queue q left join lateral(select new_release_status from sales_order_release_history x where x.organization_id=q.organization_id and x.source_order_no=q.source_order_no order by changed_at desc limit 1)h on true where q.organization_id=p_organization_id and h.new_release_status is distinct from q.release_status on conflict do nothing;get diagnostics n=row_count;return n;end$function$
;

-- public.cash_dist(money, money)
CREATE OR REPLACE FUNCTION public.cash_dist(money, money)
 RETURNS money
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$cash_dist$function$
;

-- public.clone_routing_revision(p_routing_id uuid)
CREATE OR REPLACE FUNCTION public.clone_routing_revision(p_routing_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare source routings%rowtype;new_id uuid;new_revision integer;begin
  select * into strict source from routings where id=p_routing_id;
  perform pg_advisory_xact_lock(hashtext(source.organization_id::text||source.code));
  select coalesce(max(revision),0)+1 into new_revision from routings where organization_id=source.organization_id and code=source.code;
  insert into routings(organization_id,code,name,revision,status,active)values(source.organization_id,source.code,source.name,new_revision,'DRAFT',true)returning id into new_id;
  insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions)
  select organization_id,new_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions from routing_operations where routing_id=p_routing_id order by sequence;
  return new_id;
end$function$
;

-- public.copy_production_order_operations()
CREATE OR REPLACE FUNCTION public.copy_production_order_operations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.source_routing_id is null or exists(select 1 from production_order_operations where production_order_id=new.id)then return new;end if;
  insert into production_order_operations(organization_id,production_order_id,source_routing_operation_id,source_operation_id,sequence,operation_code_snapshot,operation_name_snapshot,work_center_code_snapshot,work_center_name_snapshot,required,setup_minutes_snapshot,run_rate_snapshot,queue_minutes_snapshot,instructions_snapshot,planned_quantity,planned_date,planned_shift_id)
  select new.organization_id,new.id,ro.id,o.id,ro.sequence,o.code,o.name,w.code,w.name,ro.required,ro.setup_minutes,ro.run_rate,ro.queue_minutes,ro.instructions,new.planned_quantity,new.planned_date,new.planned_shift_id
  from routing_operations ro join operations o on o.id=ro.operation_id and o.organization_id=ro.organization_id left join work_centers w on w.id=ro.work_center_id and w.organization_id=ro.organization_id
  where ro.routing_id=new.source_routing_id and ro.organization_id=new.organization_id order by ro.sequence;
  return new;
end$function$
;

-- public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare result uuid;begin if not exists(select 1 from shift_templates where id=p_shift_id and organization_id=p_organization_id and active)then raise exception 'Invalid shift';end if;if not exists(select 1 from production_areas where id=p_area_id and organization_id=p_organization_id and active and code<>'UNMAPPED')then raise exception 'Invalid area';end if;insert into production_plans(organization_id,production_date,shift_template_id,production_area_id,created_by)values(p_organization_id,p_production_date,p_shift_id,p_area_id,p_actor_id)returning id into result;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select result,'created',p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=result;return result;end$function$
;

-- public.create_manufacturing_orders(p_organization_id uuid, p_source_system text)
CREATE OR REPLACE FUNCTION public.create_manufacturing_orders(p_organization_id uuid, p_source_system text DEFAULT 'ORACLE_WMS'::text)
 RETURNS TABLE(out_manufacturing_order_id uuid, out_mo_number text, out_source_order_no text, out_routing_id uuid, out_planned_quantity numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end$function$
;

-- public.date_dist(date, date)
CREATE OR REPLACE FUNCTION public.date_dist(date, date)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$date_dist$function$
;

-- public.dtg_machine_load()
CREATE OR REPLACE FUNCTION public.dtg_machine_load()
 RETURNS TABLE(order_no text, customer_name text, due_at timestamp with time zone, warehouse_garments bigint, warehouse_prints numeric, print_garments bigint, print_prints numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with latest as(select id from v_latest_completed_batch limit 1)
select
  w.order_no,
  max(w.customer_name),
  min(w.source_due_at),
  coalesce(sum(w.production_units) filter(where upper(trim(w.from_zone))='PG11'),0)::bigint,
  0::numeric,
  coalesce(sum(w.production_units) filter(where upper(trim(w.from_zone))='DTGS'),0)::bigint,
  coalesce(sum(w.prints_per_garment) filter(where upper(trim(w.from_zone))='DTGS'),0)
from source_workbank_items w
join latest on latest.id=w.sync_batch_id
where upper(trim(w.from_zone)) in ('PG11','DTGS')
group by w.order_no;
$function$
;

-- public.e56_mo_status_is_reconcilable(p_status text)
CREATE OR REPLACE FUNCTION public.e56_mo_status_is_reconcilable(p_status text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$select p_status in('PLANNED','PENDING','READY')$function$
;

-- public.e6_scope_fingerprint(p_run uuid)
CREATE OR REPLACE FUNCTION public.e6_scope_fingerprint(p_run uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'extensions'
AS $function$select encode(extensions.digest(coalesce(string_agg(organization_id::text||'|'||replace(source_order_no,'|','||')||'|'||replace(source_line_id,'|','||')||'|'||to_char(quantity,'FM999999999999990.000')||'|'||case when prepared_released then'1'when prepared_released=false then'0'else'<NULL>'end||'|'||coalesce(replace(prepared_raw_release_value,'|','||'),'<NULL>')||'|'||coalesce(product_id::text,'<NULL>')||'|'||coalesce(routing_id::text,'<NULL>')||'|'||coalesce(replace(process_code,'|','||'),'<NULL>')||'|'||coalesce(replace(scope_classification,'|','||'),'<NULL>'),E'\n'order by organization_id,source_order_no,source_line_id),''),'sha256'),'hex')from e6_scope_classifications where run_id=p_run$function$
;

-- public.enforce_manufacturing_order_line_boundary()
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

-- public.enforce_production_resource_asset_organization()
CREATE OR REPLACE FUNCTION public.enforce_production_resource_asset_organization()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin if new.asset_id is not null and not exists(select 1 from maintenance_assets a where a.id=new.asset_id and a.organization_id=new.organization_id)then raise exception 'Production resource asset must belong to the same organization';end if;return new;end$function$
;

-- public.enforce_sync_batch_organization()
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

-- public.fail_oracle_line_ingestion(p_organization_id uuid, p_run_id uuid, p_error text)
CREATE OR REPLACE FUNCTION public.fail_oracle_line_ingestion(p_organization_id uuid, p_run_id uuid, p_error text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin update oracle_line_ingestion_runs set status='FAILED',error=p_error,updated_at=now()where id=p_run_id and organization_id=p_organization_id and snapshot_status='PARTIAL';return jsonb_build_object('runId',p_run_id,'status','FAILED');end$function$
;

-- public.finalize_e6_backfill(p_run_id uuid)
CREATE OR REPLACE FUNCTION public.finalize_e6_backfill(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_pending integer;v_qty numeric;begin
 select count(*)into v_pending from e6_backfill_batches where run_id=p_run_id and status<>'COMPLETED';if v_pending>0 then raise exception'E6_BATCHES_INCOMPLETE:%',v_pending;end if;
 select coalesce(sum(ml.planned_quantity),0)into v_qty from e6_scope_classifications c join lateral(select d.id from production_demand_lines d where d.organization_id=c.organization_id and d.source_system='ORACLE_WMS'and d.source_order_no=c.source_order_no and d.source_order_line_id in('E56:'||c.source_line_id,'E6:'||c.source_line_id)limit 1)d on true join manufacturing_order_lines ml on ml.production_demand_line_id=d.id where c.run_id=p_run_id and c.scope_classification='MO_REQUIRED_SUPPORTED';
 update e6_backfill_runs set status='COMPLETED',completed_at=now(),represented_quantity=v_qty,error=null where id=p_run_id;return jsonb_build_object('runId',p_run_id,'representedQuantity',v_qty);end$function$
;

-- public.finalize_oracle_line_ingestion(p_organization_id uuid, p_run_id uuid, p_expected_rows integer)
CREATE OR REPLACE FUNCTION public.finalize_oracle_line_ingestion(p_organization_id uuid, p_run_id uuid, p_expected_rows integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare r oracle_line_ingestion_runs;n integer;dupes integer;unknowns integer;begin select*into r from oracle_line_ingestion_runs where id=p_run_id and organization_id=p_organization_id for update;select count(*),count(*)filter(where raw_release_value not in('Y','N'))into n,unknowns from oracle_line_ingestion_staging where ingestion_run_id=p_run_id;select count(*)-count(distinct(source_order_no,source_line_id))into dupes from oracle_line_ingestion_staging where ingestion_run_id=p_run_id;if r.status<>'RUNNING'or n=0 or n<>p_expected_rows or n<>r.rows_processed or dupes<>0 then raise exception'INCOMPLETE_SNAPSHOT rows=% expected=% processed=% duplicates=%',n,p_expected_rows,r.rows_processed,dupes;end if;
update source_order_release_lines set source_presence='NOT_SEEN_IN_LATEST_COMPLETE_SNAPSHOT'where organization_id=p_organization_id and source_system='ORACLE_WMS';
insert into source_order_release_lines(organization_id,sync_batch_id,source_system,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at,ingestion_run_id,source_presence,source_routing,source_operational_code,source_operational_codes,operational_code_conflict)
select s.organization_id,r.sync_batch_id,'ORACLE_WMS',s.source_order_no,s.source_line_id,s.source_product_code,s.source_description,s.production_units,s.released,s.raw_release_value,s.source_line_status,s.quantity_processed,s.source_weight,s.stock_reserved_flag,s.source_updated_at,p_run_id,'ACTIVE',s.source_routing,s.source_operational_code,s.source_operational_codes,s.operational_code_conflict from oracle_line_ingestion_staging s where s.ingestion_run_id=p_run_id
on conflict(organization_id,source_system,source_order_no,source_line_id)do update set sync_batch_id=excluded.sync_batch_id,source_product_code=excluded.source_product_code,source_description=excluded.source_description,production_units=excluded.production_units,released=excluded.released,raw_release_value=excluded.raw_release_value,source_line_status=excluded.source_line_status,quantity_processed=excluded.quantity_processed,source_weight=excluded.source_weight,stock_reserved_flag=excluded.stock_reserved_flag,source_updated_at=excluded.source_updated_at,ingestion_run_id=excluded.ingestion_run_id,source_presence='ACTIVE',source_routing=excluded.source_routing,source_operational_code=excluded.source_operational_code,source_operational_codes=excluded.source_operational_codes,operational_code_conflict=excluded.operational_code_conflict;
update oracle_line_ingestion_runs set status='COMPLETED',snapshot_status='COMPLETE',completed_at=now(),updated_at=now()where id=p_run_id;perform capture_sales_order_release_transitions(p_organization_id); perform reconcile_release_reactivations(p_organization_id,p_run_id,true);return jsonb_build_object('runId',p_run_id,'status','COMPLETE','sourceRows',n,'duplicateKeys',dupes,'unknownReleasedValues',unknowns);end$function$
;

-- public.float4_dist(real, real)
CREATE OR REPLACE FUNCTION public.float4_dist(real, real)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$float4_dist$function$
;

-- public.float8_dist(double precision, double precision)
CREATE OR REPLACE FUNCTION public.float8_dist(double precision, double precision)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$float8_dist$function$
;

-- public.gbt_bit_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_compress$function$
;

-- public.gbt_bit_consistent(internal, bit, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_consistent(internal, bit, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_consistent$function$
;

-- public.gbt_bit_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_penalty$function$
;

-- public.gbt_bit_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_picksplit$function$
;

-- public.gbt_bit_same(gbtreekey_var, gbtreekey_var, internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_same(gbtreekey_var, gbtreekey_var, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_same$function$
;

-- public.gbt_bit_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bit_union(internal, internal)
 RETURNS gbtreekey_var
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bit_union$function$
;

-- public.gbt_bool_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_compress$function$
;

-- public.gbt_bool_consistent(internal, boolean, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_consistent(internal, boolean, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_consistent$function$
;

-- public.gbt_bool_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_fetch$function$
;

-- public.gbt_bool_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_penalty$function$
;

-- public.gbt_bool_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_picksplit$function$
;

-- public.gbt_bool_same(gbtreekey2, gbtreekey2, internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_same(gbtreekey2, gbtreekey2, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_same$function$
;

-- public.gbt_bool_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bool_union(internal, internal)
 RETURNS gbtreekey2
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/btree_gist', $function$gbt_bool_union$function$
;

-- public.gbt_bpchar_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_bpchar_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bpchar_compress$function$
;

-- public.gbt_bpchar_consistent(internal, character, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_bpchar_consistent(internal, character, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bpchar_consistent$function$
;

-- public.gbt_bytea_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_compress$function$
;

-- public.gbt_bytea_consistent(internal, bytea, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_consistent(internal, bytea, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_consistent$function$
;

-- public.gbt_bytea_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_penalty$function$
;

-- public.gbt_bytea_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_picksplit$function$
;

-- public.gbt_bytea_same(gbtreekey_var, gbtreekey_var, internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_same(gbtreekey_var, gbtreekey_var, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_same$function$
;

-- public.gbt_bytea_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_bytea_union(internal, internal)
 RETURNS gbtreekey_var
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_bytea_union$function$
;

-- public.gbt_cash_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_compress$function$
;

-- public.gbt_cash_consistent(internal, money, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_consistent(internal, money, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_consistent$function$
;

-- public.gbt_cash_distance(internal, money, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_distance(internal, money, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_distance$function$
;

-- public.gbt_cash_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_fetch$function$
;

-- public.gbt_cash_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_penalty$function$
;

-- public.gbt_cash_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_picksplit$function$
;

-- public.gbt_cash_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_same$function$
;

-- public.gbt_cash_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_cash_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_cash_union$function$
;

-- public.gbt_date_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_date_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_compress$function$
;

-- public.gbt_date_consistent(internal, date, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_consistent(internal, date, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_consistent$function$
;

-- public.gbt_date_distance(internal, date, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_distance(internal, date, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_distance$function$
;

-- public.gbt_date_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_date_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_fetch$function$
;

-- public.gbt_date_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_penalty$function$
;

-- public.gbt_date_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_picksplit$function$
;

-- public.gbt_date_same(gbtreekey8, gbtreekey8, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_same(gbtreekey8, gbtreekey8, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_same$function$
;

-- public.gbt_date_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_date_union(internal, internal)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_date_union$function$
;

-- public.gbt_decompress(internal)
CREATE OR REPLACE FUNCTION public.gbt_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_decompress$function$
;

-- public.gbt_enum_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_compress$function$
;

-- public.gbt_enum_consistent(internal, anyenum, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_consistent(internal, anyenum, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_consistent$function$
;

-- public.gbt_enum_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_fetch$function$
;

-- public.gbt_enum_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_penalty$function$
;

-- public.gbt_enum_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_picksplit$function$
;

-- public.gbt_enum_same(gbtreekey8, gbtreekey8, internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_same(gbtreekey8, gbtreekey8, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_same$function$
;

-- public.gbt_enum_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_enum_union(internal, internal)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_enum_union$function$
;

-- public.gbt_float4_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_compress$function$
;

-- public.gbt_float4_consistent(internal, real, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_consistent(internal, real, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_consistent$function$
;

-- public.gbt_float4_distance(internal, real, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_distance(internal, real, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_distance$function$
;

-- public.gbt_float4_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_fetch$function$
;

-- public.gbt_float4_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_penalty$function$
;

-- public.gbt_float4_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_picksplit$function$
;

-- public.gbt_float4_same(gbtreekey8, gbtreekey8, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_same(gbtreekey8, gbtreekey8, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_same$function$
;

-- public.gbt_float4_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float4_union(internal, internal)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float4_union$function$
;

-- public.gbt_float8_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_compress$function$
;

-- public.gbt_float8_consistent(internal, double precision, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_consistent(internal, double precision, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_consistent$function$
;

-- public.gbt_float8_distance(internal, double precision, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_distance(internal, double precision, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_distance$function$
;

-- public.gbt_float8_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_fetch$function$
;

-- public.gbt_float8_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_penalty$function$
;

-- public.gbt_float8_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_picksplit$function$
;

-- public.gbt_float8_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_same$function$
;

-- public.gbt_float8_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_float8_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_float8_union$function$
;

-- public.gbt_inet_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_compress$function$
;

-- public.gbt_inet_consistent(internal, inet, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_consistent(internal, inet, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_consistent$function$
;

-- public.gbt_inet_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_penalty$function$
;

-- public.gbt_inet_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_picksplit$function$
;

-- public.gbt_inet_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_same$function$
;

-- public.gbt_inet_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_inet_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_inet_union$function$
;

-- public.gbt_int2_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_compress$function$
;

-- public.gbt_int2_consistent(internal, smallint, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_consistent(internal, smallint, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_consistent$function$
;

-- public.gbt_int2_distance(internal, smallint, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_distance(internal, smallint, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_distance$function$
;

-- public.gbt_int2_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_fetch$function$
;

-- public.gbt_int2_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_penalty$function$
;

-- public.gbt_int2_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_picksplit$function$
;

-- public.gbt_int2_same(gbtreekey4, gbtreekey4, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_same(gbtreekey4, gbtreekey4, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_same$function$
;

-- public.gbt_int2_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int2_union(internal, internal)
 RETURNS gbtreekey4
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int2_union$function$
;

-- public.gbt_int4_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_compress$function$
;

-- public.gbt_int4_consistent(internal, integer, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_consistent(internal, integer, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_consistent$function$
;

-- public.gbt_int4_distance(internal, integer, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_distance(internal, integer, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_distance$function$
;

-- public.gbt_int4_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_fetch$function$
;

-- public.gbt_int4_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_penalty$function$
;

-- public.gbt_int4_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_picksplit$function$
;

-- public.gbt_int4_same(gbtreekey8, gbtreekey8, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_same(gbtreekey8, gbtreekey8, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_same$function$
;

-- public.gbt_int4_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int4_union(internal, internal)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int4_union$function$
;

-- public.gbt_int8_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_compress$function$
;

-- public.gbt_int8_consistent(internal, bigint, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_consistent(internal, bigint, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_consistent$function$
;

-- public.gbt_int8_distance(internal, bigint, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_distance(internal, bigint, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_distance$function$
;

-- public.gbt_int8_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_fetch$function$
;

-- public.gbt_int8_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_penalty$function$
;

-- public.gbt_int8_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_picksplit$function$
;

-- public.gbt_int8_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_same$function$
;

-- public.gbt_int8_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_int8_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_int8_union$function$
;

-- public.gbt_intv_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_compress$function$
;

-- public.gbt_intv_consistent(internal, interval, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_consistent(internal, interval, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_consistent$function$
;

-- public.gbt_intv_decompress(internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_decompress$function$
;

-- public.gbt_intv_distance(internal, interval, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_distance(internal, interval, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_distance$function$
;

-- public.gbt_intv_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_fetch$function$
;

-- public.gbt_intv_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_penalty$function$
;

-- public.gbt_intv_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_picksplit$function$
;

-- public.gbt_intv_same(gbtreekey32, gbtreekey32, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_same(gbtreekey32, gbtreekey32, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_same$function$
;

-- public.gbt_intv_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_intv_union(internal, internal)
 RETURNS gbtreekey32
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_intv_union$function$
;

-- public.gbt_macad8_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_compress$function$
;

-- public.gbt_macad8_consistent(internal, macaddr8, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_consistent(internal, macaddr8, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_consistent$function$
;

-- public.gbt_macad8_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_fetch$function$
;

-- public.gbt_macad8_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_penalty$function$
;

-- public.gbt_macad8_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_picksplit$function$
;

-- public.gbt_macad8_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_same$function$
;

-- public.gbt_macad8_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad8_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad8_union$function$
;

-- public.gbt_macad_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_compress$function$
;

-- public.gbt_macad_consistent(internal, macaddr, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_consistent(internal, macaddr, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_consistent$function$
;

-- public.gbt_macad_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_fetch$function$
;

-- public.gbt_macad_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_penalty$function$
;

-- public.gbt_macad_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_picksplit$function$
;

-- public.gbt_macad_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_same$function$
;

-- public.gbt_macad_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_macad_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_macad_union$function$
;

-- public.gbt_numeric_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_compress$function$
;

-- public.gbt_numeric_consistent(internal, numeric, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_consistent(internal, numeric, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_consistent$function$
;

-- public.gbt_numeric_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_penalty$function$
;

-- public.gbt_numeric_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_picksplit$function$
;

-- public.gbt_numeric_same(gbtreekey_var, gbtreekey_var, internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_same(gbtreekey_var, gbtreekey_var, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_same$function$
;

-- public.gbt_numeric_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_numeric_union(internal, internal)
 RETURNS gbtreekey_var
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_numeric_union$function$
;

-- public.gbt_oid_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_compress$function$
;

-- public.gbt_oid_consistent(internal, oid, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_consistent(internal, oid, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_consistent$function$
;

-- public.gbt_oid_distance(internal, oid, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_distance(internal, oid, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_distance$function$
;

-- public.gbt_oid_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_fetch$function$
;

-- public.gbt_oid_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_penalty$function$
;

-- public.gbt_oid_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_picksplit$function$
;

-- public.gbt_oid_same(gbtreekey8, gbtreekey8, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_same(gbtreekey8, gbtreekey8, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_same$function$
;

-- public.gbt_oid_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_oid_union(internal, internal)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_oid_union$function$
;

-- public.gbt_text_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_text_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_compress$function$
;

-- public.gbt_text_consistent(internal, text, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_text_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_consistent$function$
;

-- public.gbt_text_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_text_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_penalty$function$
;

-- public.gbt_text_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_text_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_picksplit$function$
;

-- public.gbt_text_same(gbtreekey_var, gbtreekey_var, internal)
CREATE OR REPLACE FUNCTION public.gbt_text_same(gbtreekey_var, gbtreekey_var, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_same$function$
;

-- public.gbt_text_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_text_union(internal, internal)
 RETURNS gbtreekey_var
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_text_union$function$
;

-- public.gbt_time_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_time_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_compress$function$
;

-- public.gbt_time_consistent(internal, time without time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_consistent(internal, time without time zone, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_consistent$function$
;

-- public.gbt_time_distance(internal, time without time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_distance(internal, time without time zone, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_distance$function$
;

-- public.gbt_time_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_time_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_fetch$function$
;

-- public.gbt_time_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_penalty$function$
;

-- public.gbt_time_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_picksplit$function$
;

-- public.gbt_time_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_same$function$
;

-- public.gbt_time_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_time_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_time_union$function$
;

-- public.gbt_timetz_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_timetz_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_timetz_compress$function$
;

-- public.gbt_timetz_consistent(internal, time with time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_timetz_consistent(internal, time with time zone, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_timetz_consistent$function$
;

-- public.gbt_ts_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_compress$function$
;

-- public.gbt_ts_consistent(internal, timestamp without time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_consistent(internal, timestamp without time zone, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_consistent$function$
;

-- public.gbt_ts_distance(internal, timestamp without time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_distance(internal, timestamp without time zone, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_distance$function$
;

-- public.gbt_ts_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_fetch$function$
;

-- public.gbt_ts_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_penalty$function$
;

-- public.gbt_ts_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_picksplit$function$
;

-- public.gbt_ts_same(gbtreekey16, gbtreekey16, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_same(gbtreekey16, gbtreekey16, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_same$function$
;

-- public.gbt_ts_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_ts_union(internal, internal)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_ts_union$function$
;

-- public.gbt_tstz_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_tstz_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_tstz_compress$function$
;

-- public.gbt_tstz_consistent(internal, timestamp with time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_tstz_consistent(internal, timestamp with time zone, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_tstz_consistent$function$
;

-- public.gbt_tstz_distance(internal, timestamp with time zone, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_tstz_distance(internal, timestamp with time zone, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_tstz_distance$function$
;

-- public.gbt_uuid_compress(internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_compress$function$
;

-- public.gbt_uuid_consistent(internal, uuid, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_consistent(internal, uuid, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_consistent$function$
;

-- public.gbt_uuid_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_fetch$function$
;

-- public.gbt_uuid_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_penalty$function$
;

-- public.gbt_uuid_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_picksplit$function$
;

-- public.gbt_uuid_same(gbtreekey32, gbtreekey32, internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_same(gbtreekey32, gbtreekey32, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_same$function$
;

-- public.gbt_uuid_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gbt_uuid_union(internal, internal)
 RETURNS gbtreekey32
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_uuid_union$function$
;

-- public.gbt_var_decompress(internal)
CREATE OR REPLACE FUNCTION public.gbt_var_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_var_decompress$function$
;

-- public.gbt_var_fetch(internal)
CREATE OR REPLACE FUNCTION public.gbt_var_fetch(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbt_var_fetch$function$
;

-- public.gbtreekey16_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey16_in(cstring)
 RETURNS gbtreekey16
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey16_out(gbtreekey16)
CREATE OR REPLACE FUNCTION public.gbtreekey16_out(gbtreekey16)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.gbtreekey2_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey2_in(cstring)
 RETURNS gbtreekey2
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey2_out(gbtreekey2)
CREATE OR REPLACE FUNCTION public.gbtreekey2_out(gbtreekey2)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.gbtreekey32_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey32_in(cstring)
 RETURNS gbtreekey32
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey32_out(gbtreekey32)
CREATE OR REPLACE FUNCTION public.gbtreekey32_out(gbtreekey32)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.gbtreekey4_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey4_in(cstring)
 RETURNS gbtreekey4
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey4_out(gbtreekey4)
CREATE OR REPLACE FUNCTION public.gbtreekey4_out(gbtreekey4)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.gbtreekey8_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey8_in(cstring)
 RETURNS gbtreekey8
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey8_out(gbtreekey8)
CREATE OR REPLACE FUNCTION public.gbtreekey8_out(gbtreekey8)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.gbtreekey_var_in(cstring)
CREATE OR REPLACE FUNCTION public.gbtreekey_var_in(cstring)
 RETURNS gbtreekey_var
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_in$function$
;

-- public.gbtreekey_var_out(gbtreekey_var)
CREATE OR REPLACE FUNCTION public.gbtreekey_var_out(gbtreekey_var)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$gbtreekey_out$function$
;

-- public.ingest_audit_backfill(p_organization_id uuid, p_events jsonb, p_rebuild boolean)
CREATE OR REPLACE FUNCTION public.ingest_audit_backfill(p_organization_id uuid, p_events jsonb, p_rebuild boolean DEFAULT false)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rebuilt bigint := 0;
begin
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 1000 then
    raise exception 'INVALID_BACKFILL_PAYLOAD';
  end if;

  insert into public.source_audit_events (
    organization_id, source_audit_id, order_no, username, from_zone, to_zone,
    from_location, to_location, product, from_pack_id, to_pack_id, source_qty,
    source_weight, production_units, event_at, raw_hash
  )
  select
    p_organization_id,
    event->>'sourceAuditId',
    coalesce(event->>'orderNo', ''),
    event->>'username', event->>'fromZone', event->>'toZone',
    event->>'fromLocation', event->>'toLocation', event->>'product',
    event->>'fromPackId', event->>'toPackId',
    nullif(event->>'sourceQty', '')::numeric,
    nullif(event->>'sourceWeight', '')::numeric,
    coalesce(nullif(event->>'productionUnits', '')::numeric, 0),
    (event->>'eventAt')::timestamptz,
    event->>'rawHash'
  from jsonb_array_elements(p_events) as event
  on conflict (organization_id, source_audit_id) do nothing;

  if p_rebuild then
    select public.rebuild_production_events(p_organization_id) into v_rebuilt;
  end if;
  return v_rebuilt;
end;
$function$
;

-- public.ingest_authoritative_release_lines(p_organization_id uuid, p_sync_batch_id uuid, p_lines jsonb)
CREATE OR REPLACE FUNCTION public.ingest_authoritative_release_lines(p_organization_id uuid, p_sync_batch_id uuid, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 if not exists(select 1 from sync_batches where id=p_sync_batch_id and organization_id=p_organization_id and status='completed')then raise exception 'INVALID_COMPLETED_SYNC_BATCH';end if;
 delete from source_order_release_lines where organization_id=p_organization_id and source_system='ORACLE_WMS';
 insert into source_order_release_lines(organization_id,sync_batch_id,source_system,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at)
 select p_organization_id,p_sync_batch_id,'ORACLE_WMS',x."orderNo",x."lineNumber"::text,x."productCode",x."sourceDescription",greatest(coalesce(x.quantity,0),0),case upper(trim(coalesce(x.released,'')))when'Y'then true when'N'then false else null end,upper(trim(coalesce(x.released,''))),x."sourceStatus",x."quantityProcessed",x.weight,x."stockReservedFlag",x."sourceUpdatedAt"
 from jsonb_to_recordset(p_lines)x("orderNo" text,"lineNumber" integer,"productCode" text,"sourceDescription" text,quantity numeric,weight numeric,released text,"sourceStatus" text,"quantityProcessed" numeric,"stockReservedFlag" text,"sourceUpdatedAt" timestamptz);
 get diagnostics n=row_count;return n;end$function$
;

-- public.ingest_release_header_context(p_organization_id uuid, p_orders jsonb)
CREATE OR REPLACE FUNCTION public.ingest_release_header_context(p_organization_id uuid, p_orders jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin update source_orders o set source_route_id=x."sourceRouteId",cost_centre=x."costCentre",stop_ship_flag=x."stopShipFlag"from jsonb_to_recordset(p_orders)x("orderNo"text,"sourceRouteId"text,"costCentre"text,"stopShipFlag"text)where o.organization_id=p_organization_id and o.order_no=x."orderNo";get diagnostics n=row_count;return n;end$function$
;

-- public.ingest_sync_batch(payload jsonb)
CREATE OR REPLACE FUNCTION public.ingest_sync_batch(payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  batch_id uuid;
  audit_count integer;
  v_organization_id uuid := (payload->>'organizationId')::uuid;
begin
  -- One full snapshot writer at a time for each organization.
  perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text, 0));

  insert into sync_batches(organization_id,status,connector_version)
  values(v_organization_id,'running',payload->>'connectorVersion')
  returning id into batch_id;

  begin
    -- These tables are replaceable snapshots. Audit remains append-only.
    truncate table source_orders,source_workbank_items,source_stock_items;

    insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,source_updated_at)
    select v_organization_id,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x."sourceUpdatedAt"
    from jsonb_to_recordset(payload->'orders') x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,"sourceUpdatedAt" timestamptz);

    insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,prints_per_garment,queue,task)
    select v_organization_id,batch_id,x.*
    from jsonb_to_recordset(payload->'workbank') x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"printsPerGarment" numeric,queue text,task text);

    insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_timestamp,source_qty,source_weight,production_units)
    select v_organization_id,batch_id,x.*
    from jsonb_to_recordset(payload->'stock') x(product text,"packId" text,location text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);

    insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)
    select v_organization_id,x.*
    from jsonb_to_recordset(payload->'auditEvents') x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text)
    on conflict do nothing;
    get diagnostics audit_count=row_count;

    update sync_batches set
      status='completed',completed_at=now(),
      orders_count=jsonb_array_length(payload->'orders'),
      workbank_count=jsonb_array_length(payload->'workbank'),
      stock_count=jsonb_array_length(payload->'stock'),
      audit_new_count=audit_count
    where id=batch_id;

    -- Batch rows are lightweight metadata; keep the latest 100 for diagnosis.
    delete from sync_batches b
    where b.organization_id=v_organization_id
      and b.id<>batch_id
      and b.id not in (
        select k.id from sync_batches k
        where k.organization_id=v_organization_id
        order by k.created_at desc
        limit 99
      );
  exception when others then
    update sync_batches set status='failed',error_message=left(sqlerrm,1000)
    where id=batch_id;
    raise;
  end;

  return batch_id;
end $function$
;

-- public.int2_dist(smallint, smallint)
CREATE OR REPLACE FUNCTION public.int2_dist(smallint, smallint)
 RETURNS smallint
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$int2_dist$function$
;

-- public.int4_dist(integer, integer)
CREATE OR REPLACE FUNCTION public.int4_dist(integer, integer)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$int4_dist$function$
;

-- public.int8_dist(bigint, bigint)
CREATE OR REPLACE FUNCTION public.int8_dist(bigint, bigint)
 RETURNS bigint
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$int8_dist$function$
;

-- public.interval_dist(interval, interval)
CREATE OR REPLACE FUNCTION public.interval_dist(interval, interval)
 RETURNS interval
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$interval_dist$function$
;

-- public.maintenance_audit_change()
CREATE OR REPLACE FUNCTION public.maintenance_audit_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare row_data jsonb;org uuid;eid uuid;begin row_data:=case when tg_op='DELETE'then to_jsonb(old)else to_jsonb(new)end;org:=(row_data->>'organization_id')::uuid;eid:=nullif(row_data->>'id','')::uuid;insert into maintenance_audit_log(organization_id,user_id,entity_type,entity_id,action,old_values,new_values)values(org,auth.uid(),tg_table_name,eid,tg_op,case when tg_op in('UPDATE','DELETE')then to_jsonb(old)end,case when tg_op in('INSERT','UPDATE')then to_jsonb(new)end);return case when tg_op='DELETE'then old else new end;end$function$
;

-- public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)
CREATE OR REPLACE FUNCTION public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p text;c uuid;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select prefix,category_id into p,c from maintenance_asset_prefixes where id=p_prefix_id and organization_id=p_organization_id and active for share;if p is null then raise exception'Invalid or inactive asset prefix';end if;insert into maintenance_asset_code_sequences values(p_organization_id,p,0,now())on conflict do nothing;update maintenance_asset_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and prefix=p returning last_number into n;if n>999 then raise exception'Asset sequence exhausted';end if;code:=p||'-'||lpad(n::text,3,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,category_id,prefix_id,location,manufacturer,model,serial_number,description,criticality,status,installation_date,purchase_date,purchase_cost,warranty_expiry,installed_at,created_by)values(p_organization_id,code,p_name,p_name,c,p_prefix_id,nullif(trim(p_location),''),nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,p_purchase_date,p_purchase_cost,p_warranty_expiry,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
;

-- public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)
CREATE OR REPLACE FUNCTION public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pc text;p text;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select asset_code into pc from maintenance_assets where id=p_parent_asset_id and organization_id=p_organization_id and active for share;select prefix into p from maintenance_component_prefixes where id=p_component_prefix_id and organization_id=p_organization_id and active for share;if pc is null or p is null then raise exception'Invalid parent or component prefix';end if;insert into maintenance_component_code_sequences values(p_organization_id,p_parent_asset_id,p,0,now())on conflict do nothing;update maintenance_component_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and parent_asset_id=p_parent_asset_id and component_prefix=p returning last_number into n;if n>99 then raise exception'Component sequence exhausted';end if;code:=pc||'-'||p||'-'||lpad(n::text,2,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,manufacturer,model,serial_number,description,criticality,status,installation_date,installed_at,created_by)values(p_organization_id,code,p_name,p_name,p_parent_asset_id,nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
;

-- public.maintenance_generate_due_pm(p_organization_id uuid, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_generate_due_pm(p_organization_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p record;w uuid;n text;made integer:=0;begin for p in select*from maintenance_preventive_plans where organization_id=p_organization_id and active and trigger_type='calendar'and next_due_at<=now()+(lead_time_days||' days')::interval and not exists(select 1 from maintenance_work_orders where preventive_plan_id=maintenance_preventive_plans.id and status not in('completed','cancelled'))for update skip locked loop n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,work_order_type,preventive_plan_id,status,priority,title,problem_description,requested_by,requested_by_email,due_at)values(p_organization_id,n,p.asset_id,'preventive',p.id,'open',p.priority,p.name,p.description,p_actor_id,p_actor_email,p.next_due_at)returning id into w;insert into maintenance_work_order_checklist(organization_id,work_order_id,sequence,task,instructions,required)select p_organization_id,w,sequence,task,instructions,required from maintenance_preventive_plan_tasks where preventive_plan_id=p.id;insert into maintenance_work_order_history(organization_id,work_order_id,to_status,changed_by,changed_by_email)values(p_organization_id,w,'open',p_actor_id,p_actor_email);made:=made+1;end loop;return made;end$function$
;

-- public.maintenance_import_history(p_organization_id uuid, p_file_name text, p_file_hash text, p_assets jsonb, p_events jsonb, p_report jsonb)
CREATE OR REPLACE FUNCTION public.maintenance_import_history(p_organization_id uuid, p_file_name text, p_file_hash text, p_assets jsonb, p_events jsonb, p_report jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare b uuid;r jsonb;a uuid;h uuid;s uuid;ph uuid;ins integer:=0;upd integer:=0;begin
 insert into maintenance_import_batches(organization_id,file_name,file_hash,source_system,status,total_rows,valid_rows,warning_rows,error_rows,import_report)
 values(p_organization_id,p_file_name,p_file_hash,'ERP_MAINTENANCE_HISTORY','IMPORTING',jsonb_array_length(p_events),(p_report->>'valid_rows')::int,(p_report->>'warning_rows')::int,(p_report->>'error_rows')::int,p_report)
 on conflict(organization_id,file_hash)do update set import_report=excluded.import_report returning id into b;
 if exists(select 1 from maintenance_import_batches where id=b and status='COMPLETED')then return jsonb_build_object('batch_id',b,'status','duplicate');end if;
 if coalesce((p_report->>'error_rows')::int,0)>0 then raise exception 'Blocking dry-run errors remain';end if;
 for r in select * from jsonb_array_elements(p_assets)loop
  insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,asset_kind,asset_type,asset_category,status,active,notes)
  values(p_organization_id,r->>'asset_code',r->>'asset_name',r->>'asset_name',
   (select id from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'parent_asset_code','')),
   coalesce(r->>'asset_kind','FIXED'),r->>'asset_type',r->>'category',
   case upper(coalesce(r->>'status','ACTIVE'))when 'ACTIVE'then'operational'when'STORED'then'standby'when'UNDER_MAINTENANCE'then'maintenance'when'SCRAPPED'then'scrapped'else'retired'end,
   upper(coalesce(r->>'status','ACTIVE'))not in('RETIRED','SCRAPPED'),r->>'notes')
  on conflict(organization_id,asset_code)do update set name=excluded.name,asset_name=excluded.asset_name,
   asset_kind=excluded.asset_kind,asset_type=coalesce(excluded.asset_type,maintenance_assets.asset_type),
   asset_category=coalesce(excluded.asset_category,maintenance_assets.asset_category),
   notes=coalesce(excluded.notes,maintenance_assets.notes),updated_at=now();
 end loop;
 for r in select * from jsonb_array_elements(p_events)loop
  select id into h from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'parent_asset_code';
  select id into a from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'asset_code';
  select id into s from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'host_print_system_code','');
  select id into ph from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'ph_asset_code','') and asset_kind='MOVABLE';
  if h is null or a is null then raise exception 'Unresolved required asset at source row %',r->>'source_row';end if;
  insert into maintenance_import_staging(batch_id,organization_id,source_row,row_status,source_key,host_asset_code,affected_asset_code,historical_asset_reference,payload)
  values(b,p_organization_id,(r->>'source_row')::int,case when ph is null and nullif(r->>'ph_reference','')is not null then'UNRESOLVED_PH'else'VALID'end,
   r->>'source_key',r->>'parent_asset_code',r->>'ph_asset_code',r->>'ph_reference',r);
  if exists(select 1 from maintenance_downtime_events where organization_id=p_organization_id and source_system=r->>'source_system' and source_key=r->>'source_key')then upd:=upd+1;else ins:=ins+1;end if;
  insert into maintenance_downtime_events(organization_id,asset_id,event_code,event_date,host_asset_id,host_system_asset_id,affected_asset_id,
   started_at,ended_at,downtime_minutes,event_type,maintenance_class,failure_category,failure_mode,root_cause,action_taken,spare_parts_text,
   description,counts_as_failure,counts_as_downtime,event_status,source_system,source_key,source_row,original_duration_minutes,
   clock_duration_minutes,correction_factor,data_quality_status,correction_confidence,correction_method,correction_note,raw_reason,historical_asset_reference,reason)
  values(p_organization_id,a,r->>'event_id',(r->>'event_date')::date,h,s,ph,(r->>'started_at')::timestamptz,(r->>'ended_at')::timestamptz,
   (r->>'downtime_minutes')::numeric,r->>'event_type',r->>'maintenance_class',r->>'failure_category',r->>'failure_mode',
   r->>'root_cause_inferred',r->>'action_inferred',r->>'spare_parts_text',r->>'description',(r->>'counts_as_failure')='YES',
   (r->>'counts_as_downtime')='YES',r->>'status',r->>'source_system',r->>'source_key',(r->>'source_row')::int,
   nullif(r->>'original_duration_minutes','')::numeric,nullif(r->>'clock_duration_minutes','')::numeric,nullif(r->>'correction_factor','')::numeric,
   r->>'data_quality_status',r->>'correction_confidence',r->>'correction_method',r->>'correction_note',r->>'raw_reason',r->>'ph_reference',r->>'raw_reason')
  on conflict(organization_id,source_system,source_key)where source_system is not null and source_key is not null do update set
   host_asset_id=excluded.host_asset_id,host_system_asset_id=excluded.host_system_asset_id,affected_asset_id=excluded.affected_asset_id,
   downtime_minutes=excluded.downtime_minutes,event_type=excluded.event_type,maintenance_class=excluded.maintenance_class,
   failure_category=excluded.failure_category,failure_mode=excluded.failure_mode,counts_as_failure=excluded.counts_as_failure,
   counts_as_downtime=excluded.counts_as_downtime,original_duration_minutes=excluded.original_duration_minutes,
   clock_duration_minutes=excluded.clock_duration_minutes,correction_factor=excluded.correction_factor,data_quality_status=excluded.data_quality_status,
   correction_confidence=excluded.correction_confidence,correction_method=excluded.correction_method,correction_note=excluded.correction_note,
   historical_asset_reference=excluded.historical_asset_reference,updated_at=now();
 end loop;
 update maintenance_import_batches set status='COMPLETED',inserted_rows=ins,updated_rows=upd,completed_at=now() where id=b;
 return jsonb_build_object('batch_id',b,'status','COMPLETED','inserted_rows',ins,'updated_rows',upd);
end$function$
;

-- public.maintenance_operator_classify(p_organization_id uuid, p_work_order_id uuid, p_problem_area text, p_symptom text, p_comment text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_operator_classify(p_organization_id uuid, p_work_order_id uuid, p_problem_area text, p_symptom text, p_comment text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin update maintenance_work_orders set problem_description=concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')),updated_at=now()where id=p_work_order_id and organization_id=p_organization_id;if not found then raise exception'Work order not found';end if;insert into maintenance_work_order_comments(organization_id,work_order_id,user_id,author_email,comment)select p_organization_id,p_work_order_id,p_actor_id,p_actor_email,concat('Operator classification: ',concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')))where coalesce(trim(p_problem_area),'')<>''or coalesce(trim(p_symptom),'')<>''or coalesce(trim(p_comment),'')<>'';end$function$
;

-- public.maintenance_operator_escalate(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_operator_escalate(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;begin select status into old from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='WAITING_MAINTENANCE',request_type='CORRECTIVE_NOW',maintenance_requested_at=coalesce(maintenance_requested_at,now()),updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'WAITING_MAINTENANCE',p_actor_id,p_actor_email);end if;end$function$
;

-- public.maintenance_operator_pm_action(p_organization_id uuid, p_work_order_id uuid, p_action text, p_checklist_id uuid, p_completed boolean, p_no_parts_used boolean, p_resolution text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_operator_pm_action(p_organization_id uuid, p_work_order_id uuid, p_action text, p_checklist_id uuid, p_completed boolean, p_no_parts_used boolean, p_resolution text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare w maintenance_work_orders%rowtype;p maintenance_preventive_plans%rowtype;old_status text;missing_tasks integer;has_parts boolean;
begin
 select * into w from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id and work_order_type='preventive' for update;
 if w.id is null then raise exception'Preventive work order not found';end if;
 select * into p from maintenance_preventive_plans where id=w.preventive_plan_id and organization_id=p_organization_id;old_status:=w.status;
 if p_action='start' then
  if w.status not in('open','in_progress')then raise exception'Preventive work cannot be started from this status';end if;
  update maintenance_work_orders set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()where id=w.id;
  if old_status<>'in_progress'then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'in_progress',p_actor_id,p_actor_email);end if;
  if p.requires_downtime and not exists(select 1 from maintenance_downtime_events where work_order_id=w.id and ended_at is null)then
   insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,w.asset_id,w.asset_id,w.id,w.title,p_actor_id,'PLANNED',false,true);
   update maintenance_assets set status='maintenance',updated_at=now()where id=w.asset_id and status<>'down';
  end if;
 elsif p_action='check'then
  if w.status<>'in_progress'then raise exception'Start preventive work first';end if;
  update maintenance_work_order_checklist set completed=p_completed,completed_at=case when p_completed then now()else null end,completed_by=case when p_completed then p_actor_id else null end where id=p_checklist_id and work_order_id=w.id and organization_id=p_organization_id;
  if not found then raise exception'Checklist item not found';end if;
 elsif p_action='parts_confirm'then
  update maintenance_work_orders set no_parts_used_confirmed=p_no_parts_used,no_parts_used_confirmed_at=case when p_no_parts_used then now()else null end,no_parts_used_confirmed_by=case when p_no_parts_used then p_actor_id else null end,updated_at=now()where id=w.id;
 elsif p_action='complete'then
  if w.status<>'in_progress'then raise exception'Preventive work must be in progress';end if;
  select count(*)into missing_tasks from maintenance_work_order_checklist where work_order_id=w.id and required and not completed;
  if missing_tasks>0 then raise exception'Complete all required checklist items';end if;
  select exists(select 1 from maintenance_inventory_transactions where work_order_id=w.id and transaction_type='issue')into has_parts;
  if not(w.no_parts_used_confirmed or has_parts)then raise exception'Record parts used or confirm No Parts Used';end if;
  update maintenance_work_orders set status='completed',resolution=coalesce(nullif(trim(p_resolution),''),'Preventive maintenance completed'),completed_at=now(),updated_at=now()where id=w.id;
  insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'completed',p_actor_id,p_actor_email);
  update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=w.id and ended_at is null;
  update maintenance_assets set status='operational',updated_at=now()where id=w.asset_id and not exists(select 1 from maintenance_downtime_events where asset_id=w.asset_id and ended_at is null);
  update maintenance_preventive_plans set next_due_at=case frequency_unit when'day'then greatest(next_due_at,now())+make_interval(days=>frequency_value)when'week'then greatest(next_due_at,now())+make_interval(days=>frequency_value*7)when'month'then greatest(next_due_at,now())+make_interval(months=>frequency_value)when'year'then greatest(next_due_at,now())+make_interval(years=>frequency_value)else next_due_at end,updated_at=now()where id=w.preventive_plan_id;
 else raise exception'Unsupported PM action';end if;
end$function$
;

-- public.maintenance_operator_resolve(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_operator_resolve(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='completed',resolution='Resolved by operator',completed_at=now(),updated_at=now()where id=p_work_order_id;update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'completed',p_actor_id,p_actor_email);end if;end$function$
;

-- public.maintenance_operator_start_request(p_organization_id uuid, p_asset_id uuid, p_request_type text, p_request_key text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_operator_start_request(p_organization_id uuid, p_asset_id uuid, p_request_type text, p_request_key text, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare w uuid;n text;s text;stopped boolean;event_start timestamptz;begin if p_request_type not in('OPERATOR_FIX','CORRECTIVE_NOW','SCHEDULE_CORRECTIVE')then raise exception'Invalid request type';end if;perform pg_advisory_xact_lock(hashtext(p_asset_id::text));select id into w from maintenance_work_orders where organization_id=p_organization_id and operator_request_key=p_request_key limit 1;if w is not null then return w;end if;stopped:=p_request_type in('OPERATOR_FIX','CORRECTIVE_NOW');if stopped then select work_order_id into w from maintenance_downtime_events where organization_id=p_organization_id and asset_id=p_asset_id and ended_at is null order by started_at limit 1;if w is not null then return w;end if;end if;if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;s:=case p_request_type when'OPERATOR_FIX'then'OPEN_OPERATOR'when'CORRECTIVE_NOW'then'WAITING_MAINTENANCE'else'REQUESTED'end;event_start:=case when stopped then clock_timestamp() else null end;n:='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,status,priority,title,requested_by,requested_by_email,request_type,maintenance_requested_at,counts_as_downtime,operator_request_key,downtime_started_at)values(p_organization_id,n,p_asset_id,s,case when p_request_type='CORRECTIVE_NOW'then'critical'when p_request_type='OPERATOR_FIX'then'high'else'medium'end,replace(p_request_type,'_',' '),p_actor_id,p_actor_email,p_request_type,case when p_request_type='CORRECTIVE_NOW'then event_start end,stopped,p_request_key,event_start)returning id into w;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w,null,s,p_actor_id,p_actor_email);if stopped then insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_at,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,p_asset_id,p_asset_id,w,replace(p_request_type,'_',' '),event_start,p_actor_id,'CORRECTIVE',true,true);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$
;

-- public.maintenance_post_inventory(p_organization_id uuid, p_part_id uuid, p_location_id uuid, p_work_order_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric, p_notes text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_post_inventory(p_organization_id uuid, p_part_id uuid, p_location_id uuid, p_work_order_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric, p_notes text, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare id uuid;q numeric;available numeric;begin if p_quantity<=0 then raise exception'Quantity must be positive';end if;if not exists(select 1 from maintenance_parts where id=p_part_id and organization_id=p_organization_id and active)or not exists(select 1 from maintenance_inventory_locations where id=p_location_id and organization_id=p_organization_id and active)then raise exception'Invalid inventory reference';end if;q:=case when p_type='issue'then-p_quantity else p_quantity end;if p_type='issue'then select coalesce(sum(quantity),0)into available from maintenance_inventory_transactions where part_id=p_part_id and location_id=p_location_id;if available<p_quantity then raise exception'Insufficient stock';end if;end if;insert into maintenance_inventory_transactions(organization_id,part_id,location_id,work_order_id,transaction_type,quantity,unit_cost_snapshot,notes,created_by,created_by_email)values(p_organization_id,p_part_id,p_location_id,p_work_order_id,p_type,q,p_unit_cost,p_notes,p_actor_id,p_actor_email)returning maintenance_inventory_transactions.id into id;return id;end$function$
;

-- public.maintenance_report_problem(p_organization_id uuid, p_asset_id uuid, p_title text, p_description text, p_priority text, p_machine_stopped boolean, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_report_problem(p_organization_id uuid, p_asset_id uuid, p_title text, p_description text, p_priority text, p_machine_stopped boolean, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare w uuid;n text;begin if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,priority,title,problem_description,requested_by,requested_by_email)values(p_organization_id,n,p_asset_id,p_priority,p_title,p_description,p_actor_id,p_actor_email)returning id into w;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,w,null,'open',p_actor_id,p_actor_email,now());if p_machine_stopped then insert into maintenance_downtime_events(organization_id,asset_id,work_order_id,reason,started_by)values(p_organization_id,p_asset_id,w,p_title,p_actor_id);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$
;

-- public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email,now());if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$
;

-- public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text, p_cancel_reason text)
CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text, p_cancel_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;allowed boolean:=false;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;allowed:=case old when'open'then p_status in('open','in_progress','cancelled')when'in_progress'then p_status in('in_progress','waiting_parts','waiting_external','completed')when'waiting_parts'then p_status in('waiting_parts','in_progress','cancelled')when'waiting_external'then p_status in('waiting_external','in_progress','cancelled')else p_status=old end;if not allowed then raise exception'Invalid work order transition';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;if p_status='cancelled'and nullif(trim(p_cancel_reason),'')is null then raise exception'Cancellation reason required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),cancel_reason=coalesce(nullif(trim(p_cancel_reason),''),cancel_reason),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;if old<>p_status then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email);end if;if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$
;

-- public.move_routing_operation(p_operation_id uuid, p_direction text)
CREATE OR REPLACE FUNCTION public.move_routing_operation(p_operation_id uuid, p_direction text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare route uuid;ids uuid[];position integer;swap uuid;i integer;begin
  if p_direction not in('up','down')then raise exception 'Direction must be up or down';end if;
  select routing_id into strict route from routing_operations where id=p_operation_id;
  select array_agg(id order by sequence)into ids from routing_operations where routing_id=route;
  position:=array_position(ids,p_operation_id);if position is null or(p_direction='up'and position=1)or(p_direction='down'and position=array_length(ids,1))then return;end if;
  i:=case when p_direction='up'then position-1 else position+1 end;swap:=ids[i];ids[i]:=ids[position];ids[position]:=swap;
  update routing_operations set sequence=sequence+100000 where routing_id=route;
  for i in 1..array_length(ids,1)loop update routing_operations set sequence=i*10 where id=ids[i];end loop;
end$function$
;

-- public.normalize_production_event_units()
CREATE OR REPLACE FUNCTION public.normalize_production_event_units()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin
 if new.source='ORACLE_AUDIT'and new.metric<>'DTG_PRINT'then select coalesce(a.source_weight,a.source_qty,a.production_units)into new.quantity from source_audit_events a where a.organization_id=new.organization_id and coalesce(a.source_audit_id,a.raw_hash)=new.source_record_key limit 1;end if;
 return new;end$function$
;

-- public.oid_dist(oid, oid)
CREATE OR REPLACE FUNCTION public.oid_dist(oid, oid)
 RETURNS oid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$oid_dist$function$
;

-- public.prepare_e62_incremental_reconciliation(p_e6_run_id uuid, p_batch_size integer)
CREATE OR REPLACE FUNCTION public.prepare_e62_incremental_reconciliation(p_e6_run_id uuid, p_batch_size integer DEFAULT 25)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare oldrun e6_backfill_runs%rowtype;newrun uuid;begin select*into strict oldrun from e6_backfill_runs where id=p_e6_run_id and status='COMPLETED';
 perform snapshot_e62_resolution(p_e6_run_id);
 insert into e6_backfill_runs(organization_id,snapshot_run_id,batch_size,released_lines,released_quantity)select oldrun.organization_id,oldrun.snapshot_run_id,p_batch_size,count(*),coalesce(sum(quantity),0)from e62_resolution_audit where e6_run_id=p_e6_run_id returning id into newrun;
 insert into e6_scope_classifications(run_id,organization_id,snapshot_run_id,source_order_no,source_line_id,source_product_code,product_id,routing_id,process_code,quantity,scope_classification,reason_code,reason_detail)
 select newrun,a.organization_id,oldrun.snapshot_run_id,a.source_order_no,a.source_line_id,a.source_product_code,a.product_id,a.routing_id,a.process_code,a.quantity,
 case when a.resolution_status='RESOLVED_SUPPORTED'and exists(select 1 from production_orders po where po.organization_id=a.organization_id and po.source_order_no=a.source_order_no and po.source_routing_id=a.routing_id and not e56_mo_status_is_reconcilable(po.production_status))then'MO_ALREADY_IN_PROGRESS'
      when a.resolution_status='RESOLVED_SUPPORTED'then'MO_REQUIRED_SUPPORTED'else'CONTROLLED_EXCEPTION'end,
 case when a.resolution_status='RESOLVED_SUPPORTED'then'E62_'||a.resolution_status else'E62_'||a.resolution_status end,
 a.resolution_rule||'; product='||a.product_confidence||'; process='||a.process_confidence from e62_resolution_audit a where a.e6_run_id=p_e6_run_id;
 with orders as(select distinct source_order_no from e6_scope_classifications where run_id=newrun and scope_classification='MO_REQUIRED_SUPPORTED'),numbered as(select source_order_no,1+((row_number()over(order by source_order_no)-1)/p_batch_size)::integer batch_no from orders)
 insert into e6_backfill_batch_orders(run_id,batch_no,source_order_no)select newrun,batch_no,source_order_no from numbered;
 insert into e6_backfill_batches(run_id,batch_no,sales_orders,source_lines,quantity)select newrun,b.batch_no,count(distinct b.source_order_no),count(*),sum(c.quantity)from e6_backfill_batch_orders b join e6_scope_classifications c on c.run_id=b.run_id and c.source_order_no=b.source_order_no and c.scope_classification='MO_REQUIRED_SUPPORTED'where b.run_id=newrun group by b.batch_no;
 return newrun;end$function$
;

-- public.prepare_e63_screen_print_reconciliation(p_source_run uuid, p_batch_size integer)
CREATE OR REPLACE FUNCTION public.prepare_e63_screen_print_reconciliation(p_source_run uuid, p_batch_size integer DEFAULT 25)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_org uuid;v_snapshot uuid;v_run uuid;begin
 select organization_id,snapshot_run_id into strict v_org,v_snapshot from e6_backfill_runs where id=p_source_run;

 insert into product_routing_assignments(organization_id,product_id,process_code,routing_id,assignment_source,approved,approved_at)
 select distinct a.organization_id,pm.product_id,'SCREEN_PRINT',r.id,'DETERMINISTIC_SOURCE',true,now()
 from e63_process_resolution_audit a
 join product_source_mappings pm on pm.organization_id=a.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=a.source_product_code and pm.active
 join routings r on r.organization_id=a.organization_id and r.code='SCREEN_PRINT_STANDARD'and r.status='ACTIVE'and r.active
 where a.run_id=p_source_run and a.resolved_process='SCREEN_PRINT'and a.resolution_status='CURRENT_SUPPORTED_PROCESS'
 on conflict(organization_id,product_id,process_code)do nothing;

 insert into e6_backfill_runs(organization_id,snapshot_run_id,batch_size)values(v_org,v_snapshot,p_batch_size)returning id into v_run;
 insert into e6_scope_classifications(run_id,organization_id,snapshot_run_id,source_order_no,source_line_id,source_product_code,product_id,routing_id,process_code,source_tasks,quantity,scope_classification,reason_code,reason_detail)
 select v_run,a.organization_id,v_snapshot,a.source_order_no,a.source_line_id,a.source_product_code,pm.product_id,r.id,'SCREEN_PRINT',a.observed_codes,a.quantity,'MO_REQUIRED_SUPPORTED','E63_SOURCE_OPERATIONAL_CODE','PAK7 -> SCREEN_PRINT / PICKING'
 from e63_process_resolution_audit a
 join product_source_mappings pm on pm.organization_id=a.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=a.source_product_code and pm.active
 join routings r on r.organization_id=a.organization_id and r.code='SCREEN_PRINT_STANDARD'and r.status='ACTIVE'and r.active
 join v_authoritative_release_lines l on l.organization_id=a.organization_id and l.source_order_no=a.source_order_no and l.source_line_id=a.source_line_id and l.released is true
 where a.run_id=p_source_run and a.resolved_process='SCREEN_PRINT'and a.resolution_status='CURRENT_SUPPORTED_PROCESS';

 insert into e6_backfill_batch_orders(run_id,batch_no,source_order_no)
 select v_run,((row_number()over(order by source_order_no)-1)/p_batch_size+1)::integer,source_order_no from(select distinct source_order_no from e6_scope_classifications where run_id=v_run)s;
 insert into e6_backfill_batches(run_id,batch_no,sales_orders,source_lines,quantity)
 select v_run,b.batch_no,count(distinct b.source_order_no),count(*),sum(c.quantity)from e6_backfill_batch_orders b join e6_scope_classifications c on c.run_id=b.run_id and c.source_order_no=b.source_order_no where b.run_id=v_run group by b.batch_no;
 update e6_backfill_runs set released_lines=(select count(*)from e6_scope_classifications where run_id=v_run),released_quantity=(select coalesce(sum(quantity),0)from e6_scope_classifications where run_id=v_run)where id=v_run;
 return v_run;
end$function$
;

-- public.prepare_e64_supported_reconciliation(p_e63_run uuid, p_ingestion_run uuid, p_batch_size integer)
CREATE OR REPLACE FUNCTION public.prepare_e64_supported_reconciliation(p_e63_run uuid, p_ingestion_run uuid, p_batch_size integer DEFAULT 25)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_org uuid;v_snapshot uuid;v_run uuid;begin
 select organization_id,id into strict v_org,v_snapshot from oracle_line_ingestion_runs where id=p_ingestion_run and status='COMPLETED'and snapshot_status='COMPLETE';
 insert into product_routing_assignments(organization_id,product_id,process_code,routing_id,assignment_source,approved,approved_at)
 select distinct a.organization_id,pm.product_id,a.manufacturing_process,r.id,'DETERMINISTIC_SOURCE',true,now()
 from e64_process_resolution_audit a join product_source_mappings pm on pm.organization_id=a.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=a.source_product_code and pm.active
 join routings r on r.organization_id=a.organization_id and r.code=a.manufacturing_process||'_STANDARD'and r.status='ACTIVE'and r.active
 where a.source_e63_run_id=p_e63_run and a.ingestion_run_id=p_ingestion_run and a.resolution_status='CURRENT_SUPPORTED_PROCESS'and a.source_released=true
 on conflict(organization_id,product_id,process_code)do nothing;
 insert into e6_backfill_runs(organization_id,snapshot_run_id,batch_size)values(v_org,v_snapshot,p_batch_size)returning id into v_run;
 insert into e6_scope_classifications(run_id,organization_id,snapshot_run_id,source_order_no,source_line_id,source_product_code,product_id,routing_id,process_code,source_tasks,quantity,scope_classification,reason_code,reason_detail)
 select v_run,a.organization_id,v_snapshot,a.source_order_no,a.source_line_id,a.source_product_code,pm.product_id,pra.routing_id,a.manufacturing_process,array_remove(array[a.current_operational_code,a.process_origin_code],null),a.quantity,
 case when po.production_status='IN_PROGRESS'then'MO_ALREADY_IN_PROGRESS'else'MO_REQUIRED_SUPPORTED'end,
 'E64_'||a.provenance,a.reason
 from e64_process_resolution_audit a join product_source_mappings pm on pm.organization_id=a.organization_id and pm.source_system='ORACLE_WMS'and pm.source_product_code=a.source_product_code and pm.active
 join product_routing_assignments pra on pra.organization_id=a.organization_id and pra.product_id=pm.product_id and pra.process_code=a.manufacturing_process and pra.approved
 left join production_orders po on po.organization_id=a.organization_id and po.source_order_no=a.source_order_no and po.source_routing_id=pra.routing_id
 where a.source_e63_run_id=p_e63_run and a.ingestion_run_id=p_ingestion_run and a.resolution_status='CURRENT_SUPPORTED_PROCESS'and a.source_released=true;
 insert into e6_backfill_batch_orders(run_id,batch_no,source_order_no)
 select v_run,((row_number()over(order by source_order_no)-1)/p_batch_size+1)::integer,source_order_no from(select distinct source_order_no from e6_scope_classifications where run_id=v_run and scope_classification='MO_REQUIRED_SUPPORTED')s;
 insert into e6_backfill_batches(run_id,batch_no,sales_orders,source_lines,quantity)
 select v_run,b.batch_no,count(distinct b.source_order_no),count(*),sum(c.quantity)from e6_backfill_batch_orders b join e6_scope_classifications c on c.run_id=b.run_id and c.source_order_no=b.source_order_no and c.scope_classification='MO_REQUIRED_SUPPORTED'where b.run_id=v_run group by b.batch_no;
 update e6_backfill_runs set released_lines=(select count(*)from e6_scope_classifications where run_id=v_run),released_quantity=(select coalesce(sum(quantity),0)from e6_scope_classifications where run_id=v_run)where id=v_run;return v_run;
end$function$
;

-- public.prepare_e6_backfill(p_organization_id uuid, p_batch_size integer)
CREATE OR REPLACE FUNCTION public.prepare_e6_backfill(p_organization_id uuid, p_batch_size integer DEFAULT 25)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_snapshot uuid;v_run uuid;begin
 if p_batch_size not between 1 and 500 then raise exception'INVALID_BATCH_SIZE';end if;
 select id into v_snapshot from oracle_line_ingestion_runs where organization_id=p_organization_id and status='COMPLETED'and snapshot_status='COMPLETE'order by completed_at desc limit 1;
 if v_snapshot is null then raise exception'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;
 insert into e6_backfill_runs(organization_id,snapshot_run_id,batch_size)values(p_organization_id,v_snapshot,p_batch_size)returning id into v_run;
 insert into e6_scope_classifications(run_id,organization_id,snapshot_run_id,source_order_no,source_line_id,source_product_code,product_id,routing_id,process_code,source_tasks,quantity,scope_classification,reason_code,reason_detail)
 select v_run,r.organization_id,v_snapshot,r.source_order_no,r.source_line_id,a.source_product_code,r.product_id,r.resolved_routing_id,r.resolved_process,r.source_tasks,r.source_quantity,
 case when r.source_quantity<=0 then'CONTROLLED_EXCEPTION'
      when r.eligibility_status='ELIGIBLE'and exists(select 1 from production_orders po where po.organization_id=r.organization_id and po.source_order_no=r.source_order_no and po.source_routing_id=r.resolved_routing_id and not e56_mo_status_is_reconcilable(po.production_status))then'MO_ALREADY_IN_PROGRESS'
      when r.eligibility_status='ELIGIBLE'and r.resolved_process in('DTG','UNDERPRINT','SCREEN_PRINT')then'MO_REQUIRED_SUPPORTED'
      when r.resolved_process is not null and r.resolved_process not in('DTG','UNDERPRINT','SCREEN_PRINT')then'PROCESS_NOT_YET_SUPPORTED'
      else'CONTROLLED_EXCEPTION'end,
 case when r.source_quantity<=0 then'INVALID_ZERO_QUANTITY'
      when r.eligibility_status='ELIGIBLE'and exists(select 1 from production_orders po where po.organization_id=r.organization_id and po.source_order_no=r.source_order_no and po.source_routing_id=r.resolved_routing_id and not e56_mo_status_is_reconcilable(po.production_status))then'MO_ALREADY_IN_PROGRESS'
      when r.eligibility_status='ELIGIBLE'then'MO_REQUIRED_SUPPORTED'else r.eligibility_status end,
 case when r.eligibility_status='ELIGIBLE'then coalesce('Process '||r.resolved_process||'; routing '||r.resolved_routing_id::text,'Eligible canonical demand')else coalesce(r.blocker,'Released demand requires controlled review')end
 from v_released_demand_resolution r join v_authoritative_release_lines a on a.organization_id=r.organization_id and a.source_order_no=r.source_order_no and a.source_line_id=r.source_line_id
 where r.organization_id=p_organization_id and a.ingestion_run_id=v_snapshot;
 with orders as(select distinct source_order_no from e6_scope_classifications where run_id=v_run and scope_classification='MO_REQUIRED_SUPPORTED'),numbered as(select source_order_no,1+((row_number()over(order by source_order_no)-1)/p_batch_size)::integer batch_no from orders)
 insert into e6_backfill_batch_orders(run_id,batch_no,source_order_no)select v_run,batch_no,source_order_no from numbered;
 insert into e6_backfill_batches(run_id,batch_no,sales_orders,source_lines,quantity)
 select v_run,b.batch_no,count(distinct b.source_order_no),count(*),sum(c.quantity)from e6_backfill_batch_orders b join e6_scope_classifications c on c.run_id=b.run_id and c.source_order_no=b.source_order_no and c.scope_classification='MO_REQUIRED_SUPPORTED'where b.run_id=v_run group by b.batch_no;
 update e6_backfill_runs set released_lines=(select count(*)from e6_scope_classifications where run_id=v_run),released_quantity=(select coalesce(sum(quantity),0)from e6_scope_classifications where run_id=v_run)where id=v_run;
 update e6_scope_classifications c set prepared_released=s.released,prepared_raw_release_value=s.raw_release_value from oracle_line_ingestion_staging s where c.run_id=v_run and s.ingestion_run_id=v_snapshot and s.organization_id=c.organization_id and s.source_order_no=c.source_order_no and s.source_line_id=c.source_line_id; update e6_backfill_runs set prepared_scope_rows=(select count(*)from e6_scope_classifications where run_id=v_run),prepared_scope_quantity=(select coalesce(sum(quantity),0)from e6_scope_classifications where run_id=v_run),prepared_scope_fingerprint=e6_scope_fingerprint(v_run)where id=v_run; return v_run;end$function$
;

-- public.prepare_production_order_snapshot()
CREATE OR REPLACE FUNCTION public.prepare_production_order_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end$function$
;

-- public.protect_active_operation_deactivation()
CREATE OR REPLACE FUNCTION public.protect_active_operation_deactivation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if old.active and not new.active and exists(select 1 from routing_operations ro join routings r on r.id=ro.routing_id and r.organization_id=ro.organization_id where ro.operation_id=old.id and ro.organization_id=old.organization_id and r.status='ACTIVE')then raise exception 'Operation is used by an active routing revision';end if;return new;
end$function$
;

-- public.protect_production_operation_snapshot()
CREATE OR REPLACE FUNCTION public.protect_production_operation_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE'then raise exception 'Production operation snapshots cannot be deleted';end if;
  if(new.organization_id,new.production_order_id,new.source_routing_operation_id,new.source_operation_id,new.sequence,new.operation_code_snapshot,new.operation_name_snapshot,new.work_center_code_snapshot,new.work_center_name_snapshot,new.required,new.setup_minutes_snapshot,new.run_rate_snapshot,new.queue_minutes_snapshot,new.instructions_snapshot)is distinct from(old.organization_id,old.production_order_id,old.source_routing_operation_id,old.source_operation_id,old.sequence,old.operation_code_snapshot,old.operation_name_snapshot,old.work_center_code_snapshot,old.work_center_name_snapshot,old.required,old.setup_minutes_snapshot,old.run_rate_snapshot,old.queue_minutes_snapshot,old.instructions_snapshot)then raise exception 'Production operation definition snapshot is immutable';end if;
  if new.status<>old.status and not((old.status='PENDING'and new.status in('READY','IN_PROGRESS','SKIPPED'))or(old.status='READY'and new.status in('IN_PROGRESS','SKIPPED'))or(old.status='IN_PROGRESS'and new.status in('ON_HOLD','COMPLETED'))or(old.status='ON_HOLD'and new.status in('IN_PROGRESS','SKIPPED')))then raise exception 'Invalid production operation status transition';end if;
  if new.status='IN_PROGRESS'and old.status<>'IN_PROGRESS'then new.started_at:=coalesce(new.started_at,now());end if;
  if new.status in('COMPLETED','SKIPPED')and old.status not in('COMPLETED','SKIPPED')then new.completed_at:=coalesce(new.completed_at,now());end if;
  new.updated_at:=now();return new;
end$function$
;

-- public.protect_routing_operation_change()
CREATE OR REPLACE FUNCTION public.protect_routing_operation_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare route_status text;operation_active boolean;begin
  select status into route_status from routings where id=coalesce(new.routing_id,old.routing_id)and organization_id=coalesce(new.organization_id,old.organization_id);
  if route_status is distinct from 'DRAFT'then raise exception 'Routing operations may only change on draft revisions';end if;
  if tg_op<>'DELETE'then select active into operation_active from operations where id=new.operation_id and organization_id=new.organization_id;if operation_active is distinct from true then raise exception 'Only active canonical operations may be added';end if;end if;
  return case when tg_op='DELETE'then old else new end;
end$function$
;

-- public.protect_routing_revision()
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

-- public.rebuild_production_events(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.rebuild_production_events(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare affected integer;
begin
  delete from production_events where organization_id=p_organization_id and source='ORACLE_AUDIT';
  insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)
  select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone 'Australia/Brisbane',(a.event_at at time zone 'Australia/Brisbane')::date,
    case when r.cross_midnight and (a.event_at at time zone 'Australia/Brisbane')::time<r.end_time then (a.event_at at time zone 'Australia/Brisbane')::date-1 else (a.event_at at time zone 'Australia/Brisbane')::date end,
    extract(hour from a.event_at at time zone 'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,m.quantity,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then 'OUT_OF_SHIFT' else 'COMPLETE' end,'ERP_KPI_V2'
  from source_audit_events a
  cross join lateral (
    select * from (values
      ('DTG'::text,'DTG_PRINT'::text,coalesce(a.production_units,0),'prints'::text,upper(coalesce(a.from_zone,''))='DTGS' and upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_IN',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_zone,''))='DTGS' and upper(coalesce(a.to_zone,''))='PWL1'),
      ('DTG','DTG_PUTWALL_OUT',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_zone,''))='PWL1' and upper(coalesce(a.to_zone,''))<>'PWL1'),
      ('UP','UP_IN',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.to_location,'')) like '%UNDERPRINT%'),
      ('UP','UP_OUT',coalesce(a.source_weight,a.source_qty,a.production_units,0),'garments',upper(coalesce(a.from_location,'')) like '%UNDERPRINT%' and upper(coalesce(a.to_location,'')) not like '%UNDERPRINT%')
    ) v(area,metric,quantity,unit,accepted) where accepted and quantity>0
  ) m
  left join lateral (select s.* from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone 'Australia/Brisbane')::date and (s.effective_to is null or s.effective_to>=(a.event_at at time zone 'Australia/Brisbane')::date) and s.weekday=extract(isodow from case when s.cross_midnight and (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time then (a.event_at at time zone 'Australia/Brisbane')::date-1 else (a.event_at at time zone 'Australia/Brisbane')::date end) and (case when s.cross_midnight then (a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time or (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time else (a.event_at at time zone 'Australia/Brisbane')::time>=s.start_time and (a.event_at at time zone 'Australia/Brisbane')::time<s.end_time end) order by s.effective_from desc limit 1) r on true
  where a.organization_id=p_organization_id;
  get diagnostics affected=row_count;
  return affected;
end$function$
;

-- public.recalculate_manufacturing_order_actual()
CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_actual()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin update production_orders set actual_quantity=(select coalesce(sum(actual_quantity),0)from manufacturing_order_lines where manufacturing_order_id=new.manufacturing_order_id),updated_at=now()where id=new.manufacturing_order_id;return new;end$function$
;

-- public.recalculate_manufacturing_order_quantity()
CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_quantity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare mo uuid:=coalesce(new.manufacturing_order_id,old.manufacturing_order_id);q numeric;begin q:=canonical_mo_planned_quantity(mo);update production_orders set planned_quantity=q,updated_at=now()where id=mo;update production_order_operations set planned_quantity=q,updated_at=now()where q>0 and production_order_id=mo and status in('PENDING','READY');return coalesce(new,old);end$function$
;

-- public.reconcile_planned_mo_quantity_cache(p_org uuid, p_apply boolean)
CREATE OR REPLACE FUNCTION public.reconcile_planned_mo_quantity_cache(p_org uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;q numeric;begin select count(*),coalesce(sum(canonical_mo_planned_quantity(id)-planned_quantity),0)into n,q from production_orders where organization_id=p_org and production_status='PLANNED'and planned_quantity is distinct from canonical_mo_planned_quantity(id);if p_apply then update production_orders set planned_quantity=canonical_mo_planned_quantity(id),updated_at=now()where organization_id=p_org and production_status='PLANNED'and planned_quantity is distinct from canonical_mo_planned_quantity(id);update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()from production_orders po where po.planned_quantity>0 and po.organization_id=p_org and po.production_status='PLANNED'and op.production_order_id=po.id and op.status in('PENDING','READY')and op.planned_quantity is distinct from po.planned_quantity;end if;return jsonb_build_object('apply',p_apply,'mismatchedMOs',n,'quantityDifference',q);end$function$
;

-- public.reconcile_release_reactivations(p_organization_id uuid, p_snapshot_run_id uuid, p_apply boolean)
CREATE OR REPLACE FUNCTION public.reconcile_release_reactivations(p_organization_id uuid, p_snapshot_run_id uuid DEFAULT NULL::uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_snapshot uuid;v_at timestamptz;r record;detected integer:=0;restored integer:=0;qty numeric:=0;events integer:=0;exceptions integer:=0;mos integer:=0;
begin
 select id,completed_at into v_snapshot,v_at from oracle_line_ingestion_runs
 where id=coalesce(p_snapshot_run_id,(select id from oracle_line_ingestion_runs x where x.organization_id=p_organization_id and x.status='COMPLETED' and x.snapshot_status='COMPLETE' order by x.completed_at desc,x.id desc limit 1))
  and organization_id=p_organization_id and status='COMPLETED' and snapshot_status='COMPLETE';
 if v_snapshot is null then raise exception 'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;
 create temp table if not exists e68_mos(id uuid primary key)on commit drop;truncate e68_mos;
 for r in select * from v_release_reactivation_candidates where organization_id=p_organization_id and reactivation_snapshot_run_id=v_snapshot loop
  detected:=detected+1;
  if r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then
   if p_apply then
    update production_demand_lines set status='GROUPED',updated_at=now() where id=r.production_demand_line_id and status='CANCELLED';
    if found then restored:=restored+1;qty:=qty+r.mapped_quantity;insert into e68_mos values(r.manufacturing_order_id)on conflict do nothing;end if;
   end if;
  else exceptions:=exceptions+1;end if;
  if p_apply then
   insert into production_demand_release_events(id,organization_id,production_demand_line_id,manufacturing_order_line_id,manufacturing_order_id,event_type,action,original_mapping_at,original_snapshot_run_id,original_released,original_raw_release_value,event_snapshot_run_id,event_at,previous_release_value,current_release_value,mapped_quantity,executed_quantity,mo_status,created_at)
   values(gen_random_uuid(),r.organization_id,r.production_demand_line_id,r.manufacturing_order_line_id,r.manufacturing_order_id,
    case when r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then 'RELEASE_REACTIVATED' else 'RE_RELEASED_REQUIRES_RECONCILIATION' end,
    r.recommended_action,r.original_mapping_at,r.original_snapshot_run_id,true,'Y',v_snapshot,v_at,'N','Y',r.mapped_quantity,coalesce(r.executed_quantity,0),r.mo_status,now())
   on conflict(production_demand_line_id,event_type,event_snapshot_run_id)do nothing;
   if found then events:=events+1;end if;
  end if;
 end loop;
 if p_apply then
  update production_orders po set planned_quantity=canonical_mo_planned_quantity(po.id),updated_at=now()
   from e68_mos m where po.id=m.id;
  update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()
   from production_orders po join e68_mos m on m.id=po.id
   where op.production_order_id=po.id and op.status in('PENDING','READY');
  select count(*)into mos from e68_mos;
 end if;
 return jsonb_build_object('snapshotRunId',v_snapshot,'apply',p_apply,'linesDetected',detected,'linesReactivated',restored,'quantityRestored',qty,'mosRecalculated',mos,'controlledExceptions',exceptions,'eventsCreated',events);
end$function$
;

-- public.reconcile_release_revocations(p_organization_id uuid, p_snapshot_run_id uuid, p_apply boolean)
CREATE OR REPLACE FUNCTION public.reconcile_release_revocations(p_organization_id uuid, p_snapshot_run_id uuid DEFAULT NULL::uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_snapshot uuid;v_at timestamptz;r record;n integer:=0;q numeric:=0;m integer:=0;e integer:=0;begin select id,completed_at into v_snapshot,v_at from oracle_line_ingestion_runs where id=coalesce(p_snapshot_run_id,(select id from oracle_line_ingestion_runs x where x.organization_id=p_organization_id and x.status='COMPLETED'and x.snapshot_status='COMPLETE'order by x.completed_at desc,x.id desc limit 1))and organization_id=p_organization_id and status='COMPLETED'and snapshot_status='COMPLETE';if v_snapshot is null then raise exception'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;create temp table if not exists e65_mos(id uuid primary key)on commit drop;truncate e65_mos;for r in select*from v_release_revocation_candidates where organization_id=p_organization_id and revocation_snapshot_run_id=v_snapshot loop if p_apply then insert into production_demand_release_events values(default,r.organization_id,r.production_demand_line_id,r.manufacturing_order_line_id,r.manufacturing_order_id,'RELEASE_REVOKED_AFTER_MAPPING',r.recommended_action,r.original_mapping_at,r.original_snapshot_run_id,r.original_released,r.original_raw_release_value,v_snapshot,v_at,case when r.original_released then'Y'else'N'end,'N',r.mapped_quantity,coalesce(r.executed_quantity,0),r.mo_status,default)on conflict(production_demand_line_id,event_type,event_snapshot_run_id)do nothing;if found then e:=e+1;end if;end if;if r.recommended_action='WITHDRAWN_FROM_PLANNED_DEMAND'and r.demand_status<>'CANCELLED'then n:=n+1;q:=q+r.mapped_quantity;if p_apply then update production_demand_lines set status='CANCELLED',updated_at=now()where id=r.production_demand_line_id and status<>'CANCELLED';insert into e65_mos values(r.manufacturing_order_id)on conflict do nothing;end if;end if;end loop;if p_apply then update production_orders po set planned_quantity=x.qty,production_status=case when x.qty=0 then'CANCELLED'else po.production_status end,updated_at=now()from(select t.id,coalesce(sum(ml.planned_quantity)filter(where d.status<>'CANCELLED'),0)::numeric qty from e65_mos t join manufacturing_order_lines ml on ml.manufacturing_order_id=t.id join production_demand_lines d on d.id=ml.production_demand_line_id group by t.id)x where po.id=x.id;update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()from production_orders po join e65_mos t on t.id=po.id where po.planned_quantity>0 and op.production_order_id=po.id and op.status in('PENDING','READY');select count(*)into m from e65_mos;end if;return jsonb_build_object('snapshotRunId',v_snapshot,'apply',p_apply,'linesDetected',n,'quantityDetected',q,'linesRevoked',case when p_apply then n else 0 end,'quantityWithdrawn',case when p_apply then q else 0 end,'mosRecalculated',m,'eventsCreated',e);end$function$
;

-- public.refresh_kpis(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.refresh_kpis(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer:=0;added integer:=0;src timestamptz;begin select completed_at into src from sync_batches where organization_id=p_organization_id and status='completed'order by completed_at desc limit 1;
insert into kpi_results(organization_id,kpi_definition_id,period_start,period_end,production_date,numerator,value,status,data_quality_status,source_refresh_at)select p_organization_id,d.id,date_trunc('day',now()),now(),current_date,x.value,x.value,'NO_TARGET',case when src is null then'NO_DATA'when src<now()-interval'24 hours'then'STALE_DATA'else'VALID'end,src from kpi_definitions d join lateral(values('TOTAL_BACKLOG',(select coalesce(sum(remaining_units),0)from v_production_planning where organization_id=p_organization_id)),('BACKLOG_ORDERS',(select count(distinct order_no)from v_production_planning where organization_id=p_organization_id)),('WIP',(select coalesce(sum(remaining_units),0)from v_production_planning where organization_id=p_organization_id)),('AGED_ORDERS',(select count(distinct order_no)from v_production_planning where organization_id=p_organization_id and age_days>=7)),('CURRENT_STOCK',(select coalesce(sum(production_units),0)from v_current_stock where organization_id=p_organization_id)),('UP_BACKLOG',(select coalesce(sum(remaining_units),0)from v_production_planning where organization_id=p_organization_id and line='UP')))x(code,value)on x.code=d.code where d.organization_id=p_organization_id and d.is_active;get diagnostics n=row_count;
insert into kpi_results(organization_id,kpi_definition_id,period_start,period_end,production_date,production_area_id,numerator,value,status,data_quality_status,source_refresh_at) select p_organization_id,d.id,date_trunc('day',now()),now(),current_date,a.id,sum(p.remaining_units),sum(p.remaining_units),'NO_TARGET',case when src is null then'NO_DATA'when src<now()-interval'24 hours'then'STALE_DATA'else'VALID'end,src from v_production_planning p join production_areas a on a.organization_id=p.organization_id and a.code=p.line join kpi_definitions d on d.organization_id=p.organization_id and d.code='WORKBANK_BY_DEPARTMENT' where p.organization_id=p_organization_id group by d.id,a.id;get diagnostics added=row_count;n=n+added;insert into kpi_results(organization_id,kpi_definition_id,period_start,period_end,production_date,production_area_id,numerator,denominator,value,status,data_quality_status,source_refresh_at)select p_organization_id,d.id,date_trunc('day',now()),now(),current_date,a.id,case when d.code='CAPACITY_LOAD'then l.demand_units else case when d.code='WORKBANK_BY_DEPARTMENT'then l.demand_units else l.daily_capacity end end,case when d.code='CAPACITY_LOAD'then l.daily_capacity end,case d.code when'AVAILABLE_CAPACITY'then l.daily_capacity when'CAPACITY_LOAD'then l.load_percent when'CAPACITY_GAP'then l.capacity_gap when'WORKBANK_BY_DEPARTMENT'then l.demand_units end,'NO_TARGET',case when src is null then'NO_DATA'when src<now()-interval'24 hours'then'STALE_DATA'else'VALID'end,src from v_capacity_load l join production_areas a on a.organization_id=l.organization_id and a.code=l.area_code join kpi_definitions d on d.organization_id=l.organization_id and d.code in('AVAILABLE_CAPACITY','CAPACITY_LOAD','CAPACITY_GAP')where l.organization_id=p_organization_id;get diagnostics added=row_count;n=n+added;return n;end$function$
;

-- public.release_reactivation_action(p_status text, p_executed numeric, p_eligible boolean)
CREATE OR REPLACE FUNCTION public.release_reactivation_action(p_status text, p_executed numeric, p_eligible boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
select case
 when p_eligible is not true then 'RELEASE_REACTIVATION_BLOCKED'
 when p_status='COMPLETED' then 'RELEASE_REACTIVATED_AFTER_COMPLETION'
 when p_status='IN_PROGRESS' or coalesce(p_executed,0)>0 then 'RELEASE_REACTIVATED_AFTER_PRODUCTION_START'
 when p_status='PLANNED' then 'RESTORED_TO_PLANNED_DEMAND'
 when p_status='CANCELLED' then 'RELEASE_REACTIVATED_MO_CANCELLED'
 else 'INCREMENTAL_RECONCILIATION_REQUIRED'
end$function$
;

-- public.release_revocation_action(p_status text, p_executed numeric, p_valid boolean)
CREATE OR REPLACE FUNCTION public.release_revocation_action(p_status text, p_executed numeric, p_valid boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$select case when p_valid is not true then case when p_valid is false then'INVALID_AT_CREATION'else'CANNOT_PROVE'end when p_status='COMPLETED'then'RELEASE_REVOKED_AFTER_COMPLETION'when p_status='IN_PROGRESS'or coalesce(p_executed,0)>0 then'RELEASE_REVOKED_AFTER_PRODUCTION_START'when p_status in('PLANNED','PENDING','READY','RELEASED')then'WITHDRAWN_FROM_PLANNED_DEMAND'when p_status='CANCELLED'then'CANCELLED_MO_REVIEW_REQUIRED'else'CANNOT_PROVE'end$function$
;

-- public.resolve_canonical_process_context(p_organization_id uuid, p_order_no text, p_source_product_code text)
CREATE OR REPLACE FUNCTION public.resolve_canonical_process_context(p_organization_id uuid, p_order_no text, p_source_product_code text)
 RETURNS TABLE(process_code text, confidence text, resolution_rule text, conflict_count integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with line_evidence as(
 select distinct case when upper(trim(w.product_group))in('DTG_1','DTG_2')then'DTG'when upper(trim(w.product_group))='UNDERPRINT'then'UNDERPRINT'end process
 from v_current_workbank w where w.organization_id=p_organization_id and w.order_no=p_order_no and upper(trim(w.product_code))=upper(trim(p_source_product_code))
),line_roll as(select count(process)processes,min(process)process from line_evidence where process is not null),
task_evidence as(select distinct process_code process from v_source_task_resolution where organization_id=p_organization_id and source_dataset='WORKBANK'and order_no=p_order_no and process_code is not null),
task_roll as(select count(*)processes,min(process)process from task_evidence)
select case when l.processes=1 then l.process when l.processes>1 then null when t.processes=1 then t.process else null end,
 case when l.processes=1 then'SOURCE_CONFIRMED'when l.processes>1 then'AMBIGUOUS'when t.processes=1 then'SOURCE_CONFIRMED'when t.processes>1 then'AMBIGUOUS'else'UNRESOLVED'end,
 case when l.processes=1 then'WORKBANK_PRODUCT_GROUP_EXACT'when l.processes>1 then'WORKBANK_PRODUCT_GROUP_CONFLICT'when t.processes=1 then'WORKBANK_TASK_CONTEXT'when t.processes>1 then'WORKBANK_TASK_CONFLICT'else'NO_DETERMINISTIC_PROCESS_EVIDENCE'end,
 greatest(l.processes-1,t.processes-1,0)::integer from line_roll l cross join task_roll t$function$
;

-- public.resolve_product_process_routing(p_organization_id uuid, p_product_id uuid, p_process_code text, p_order_line_override uuid)
CREATE OR REPLACE FUNCTION public.resolve_product_process_routing(p_organization_id uuid, p_product_id uuid, p_process_code text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce((select a.routing_id from product_routing_assignments a join routings r on r.id=a.routing_id and r.organization_id=a.organization_id where a.organization_id=p_organization_id and a.product_id=p_product_id and a.process_code=p_process_code and a.approved and r.active and r.status='ACTIVE'and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date)limit 1),(select r.id from routings r where r.id=p_order_line_override and r.organization_id=p_organization_id and r.active and r.status='ACTIVE'limit 1),(select p.default_routing_id from products p join routings r on r.id=p.default_routing_id and r.organization_id=p.organization_id where p.id=p_product_id and p.organization_id=p_organization_id and r.active and r.status='ACTIVE'and(select count(distinct a.routing_id)from product_routing_assignments a where a.organization_id=p_organization_id and a.product_id=p_product_id and a.approved)=1))$function$
;

-- public.resolve_product_routing_from_source_task(p_organization_id uuid, p_product_id uuid, p_source_dataset text, p_source_task text, p_queue text, p_from_zone text, p_to_zone text, p_from_location text, p_to_location text, p_order_line_override uuid)
CREATE OR REPLACE FUNCTION public.resolve_product_routing_from_source_task(p_organization_id uuid, p_product_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select resolve_product_process_routing(p_organization_id,p_product_id,r.process_code,p_order_line_override)from resolve_source_task_context(p_organization_id,p_source_dataset,p_source_task,p_queue,p_from_zone,p_to_zone,p_from_location,p_to_location)r where r.process_code is not null limit 1$function$
;

-- public.resolve_production_date(p_event_at timestamp with time zone, p_starts_at time without time zone, p_ends_at time without time zone, p_timezone text)
CREATE OR REPLACE FUNCTION public.resolve_production_date(p_event_at timestamp with time zone, p_starts_at time without time zone, p_ends_at time without time zone, p_timezone text DEFAULT 'Australia/Brisbane'::text)
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
AS $function$select case when p_ends_at<=p_starts_at and(p_event_at at time zone p_timezone)::time<p_ends_at then(p_event_at at time zone p_timezone)::date-1 else(p_event_at at time zone p_timezone)::date end$function$
;

-- public.resolve_production_order_actual_state(p_organization_id uuid, p_production_order_id uuid)
CREATE OR REPLACE FUNCTION public.resolve_production_order_actual_state(p_organization_id uuid, p_production_order_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(orders_resolved integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare poid uuid;r record;o integer:=0;e integer:=0;x integer:=0;begin
with ambiguous as(select ev.source_dataset,ev.source_record_key,ev.operation_id from v_source_operation_evidence ev join production_orders po on po.organization_id=ev.organization_id and coalesce(po.source_order_no,po.order_no)=ev.order_no join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where ev.organization_id=p_organization_id and(p_production_order_id is null or po.id=p_production_order_id)group by ev.source_dataset,ev.source_record_key,ev.operation_id having count(distinct po.id)>1),ins as(insert into production_routing_exceptions(organization_id,production_order_id,production_order_operation_id,exception_type,description,source_dataset,source_record_key)select distinct po.organization_id,po.id,op.id,'AMBIGUOUS_SOURCE_EVIDENCE','Evidence matches multiple MOs in the same SO; execution was not changed.',ev.source_dataset,ev.source_record_key from ambiguous a join v_source_operation_evidence ev using(source_dataset,source_record_key,operation_id)join production_orders po on po.organization_id=ev.organization_id and coalesce(po.source_order_no,po.order_no)=ev.order_no join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where not exists(select 1 from production_routing_exceptions z where z.production_order_id=po.id and z.production_order_operation_id=op.id and z.exception_type='AMBIGUOUS_SOURCE_EVIDENCE'and z.source_dataset=ev.source_dataset and z.source_record_key=ev.source_record_key)returning 1)select count(*)into x from ins;
for poid in select po.id from production_orders po where po.organization_id=p_organization_id and(p_production_order_id is null or po.id=p_production_order_id)and not exists(select 1 from v_source_operation_evidence ev join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where ev.organization_id=po.organization_id and ev.order_no=coalesce(po.source_order_no,po.order_no)and exists(select 1 from production_orders other join production_order_operations oop on oop.production_order_id=other.id and oop.source_operation_id=ev.operation_id where other.organization_id=po.organization_id and other.id<>po.id and coalesce(other.source_order_no,other.order_no)=ev.order_no))loop select * into r from resolve_production_order_actual_state_unambiguous(p_organization_id,poid);o:=o+coalesce(r.orders_resolved,0);e:=e+coalesce(r.evidence_added,0);x:=x+coalesce(r.exceptions_added,0);end loop;return query select o,e,x;end$function$
;

-- public.resolve_production_order_actual_state_unambiguous(p_organization_id uuid, p_production_order_id uuid)
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

-- public.resolve_source_operational_context(p_organization_id uuid, p_queue text, p_to_location text, p_existing_process text)
CREATE OR REPLACE FUNCTION public.resolve_source_operational_context(p_organization_id uuid, p_queue text, p_to_location text, p_existing_process text DEFAULT NULL::text)
 RETURNS TABLE(source_operational_code text, manufacturing_process text, operational_stage text, release_status text, eligibility_status text, blocker_reason text, mo_scope text, confidence text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
with q as(
 select * from source_operational_code_mappings where organization_id=p_organization_id and source_dataset='WORKBANK'and source_field='queue'and active and source_operational_code=upper(trim(coalesce(p_queue,'')))limit 1
),l as(
 select * from source_operational_code_mappings where organization_id=p_organization_id and source_dataset='WORKBANK'and source_field='to_location'and active and source_operational_code=upper(trim(coalesce(p_to_location,'')))limit 1
)
select coalesce(l.source_operational_code,q.source_operational_code),coalesce(q.manufacturing_process,p_existing_process),coalesce(l.operational_stage,q.operational_stage),q.release_status,q.eligibility_status,q.blocker_reason,coalesce(q.mo_scope,l.mo_scope),coalesce(q.confidence,l.confidence)from q full join l on true
$function$
;

-- public.resolve_source_task_context(p_organization_id uuid, p_source_dataset text, p_source_task text, p_queue text, p_from_zone text, p_to_zone text, p_from_location text, p_to_location text)
CREATE OR REPLACE FUNCTION public.resolve_source_task_context(p_organization_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text)
 RETURNS TABLE(mapping_id uuid, production_process_id uuid, process_code text, operation_id uuid, operation_code text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select m.id,m.production_process_id,p.code,m.operation_id,o.code from source_task_mappings m join production_processes p on p.id=m.production_process_id and p.organization_id=m.organization_id left join operations o on o.id=m.operation_id and o.organization_id=m.organization_id where m.organization_id=p_organization_id and m.source_system='ORACLE_WMS'and m.source_dataset=upper(p_source_dataset)and m.active and source_value_matches(p_source_task,m.match_type,m.source_task)and(m.context_field is null or source_value_matches(case m.context_field when'queue'then p_queue when'from_zone'then p_from_zone when'to_zone'then p_to_zone when'from_location'then p_from_location when'to_location'then p_to_location end,m.context_match_type,m.context_value))order by(case when m.context_field is not null then 0 else 1 end),m.priority,m.id limit 1$function$
;

-- public.run_e56_mo_pilot(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.run_e56_mo_pilot(p_organization_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare rid uuid;runid uuid;g record;moid uuid;created_count integer:=0;mapping_count integer:=0;source_count integer:=0;released_count integer:=0;represented numeric(14,3):=0;affected integer:=0;begin select id into rid from oracle_line_ingestion_runs where organization_id=p_organization_id and status='COMPLETED'and snapshot_status='COMPLETE'order by completed_at desc limit 1;if rid is null then raise exception'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;insert into e56_mo_pilot_runs(organization_id,snapshot_run_id)values(p_organization_id,rid)returning id into runid;select count(*)into source_count from v_authoritative_release_lines l join e56_mo_pilot_orders p on p.organization_id=l.organization_id and p.source_order_no=l.source_order_no where l.organization_id=p_organization_id;select count(*)into released_count from v_released_demand_resolution r join e56_mo_pilot_orders p on p.organization_id=r.organization_id and p.source_order_no=r.source_order_no where r.organization_id=p_organization_id;
insert into e56_mo_pilot_exceptions(organization_id,source_order_no,source_line_id,routing_id,exception_code,quantity,detail)select r.organization_id,r.source_order_no,r.source_line_id,r.resolved_routing_id,r.eligibility_status,r.source_quantity,coalesce(r.blocker,'Released demand blocked')from v_released_demand_resolution r join e56_mo_pilot_orders p on p.organization_id=r.organization_id and p.source_order_no=r.source_order_no where r.organization_id=p_organization_id and r.eligibility_status<>'ELIGIBLE'on conflict do nothing;
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,source_product_code,source_description,quantity,due_date,source_priority,status,resolution_status,production_process_code)select r.organization_id,'ORACLE_WMS',r.source_order_no,'E56:'||r.source_line_id,r.product_id,r.resolved_routing_id,r.resolved_routing_id,l.source_product_code,l.source_description,r.source_quantity,o.date_due,o.source_priority,'READY','RESOLVED',r.resolved_process from v_released_demand_resolution r join e56_mo_pilot_orders p on p.organization_id=r.organization_id and p.source_order_no=r.source_order_no join v_released_production_demand l on l.organization_id=r.organization_id and l.source_order_no=r.source_order_no and l.source_line_id=r.source_line_id left join v_current_orders o on o.organization_id=r.organization_id and o.order_no=r.source_order_no where r.organization_id=p_organization_id and r.eligibility_status='ELIGIBLE'on conflict(organization_id,source_system,source_order_no,source_order_line_id)do update set product_id=excluded.product_id,routing_id=excluded.routing_id,routing_revision_id=excluded.routing_revision_id,quantity=excluded.quantity,due_date=excluded.due_date,source_priority=excluded.source_priority,status=case when production_demand_lines.status='GROUPED'then'GROUPED'else'READY'end,resolution_status='RESOLVED',updated_at=now();
for g in select d.source_order_no,d.routing_revision_id,sum(d.quantity)::numeric(14,3)qty,min(d.due_date)::date due_date,min(d.source_priority)priority,r.code routing_code from production_demand_lines d join routings r on r.id=d.routing_revision_id join e56_mo_pilot_orders p on p.organization_id=d.organization_id and p.source_order_no=d.source_order_no where d.organization_id=p_organization_id and d.source_order_line_id like'E56:%'group by d.source_order_no,d.routing_revision_id,r.code loop select id into moid from production_orders where organization_id=p_organization_id and source_order_no=g.source_order_no and source_routing_id=g.routing_revision_id and split_number=1 limit 1;if moid is not null and exists(select 1 from production_orders where id=moid and production_status not in('PLANNED','PENDING','READY'))then insert into e56_mo_pilot_exceptions(organization_id,source_order_no,routing_id,exception_code,quantity,detail)values(p_organization_id,g.source_order_no,g.routing_revision_id,'MO_ALREADY_IN_PROGRESS',g.qty,'Existing MO execution history was not changed')on conflict(organization_id,source_order_no,(coalesce(source_line_id,'')),(coalesce(routing_id,'00000000-0000-0000-0000-000000000000'::uuid)),exception_code)do update set quantity=excluded.quantity,detail=excluded.detail;continue;end if;if moid is null then insert into production_orders(organization_id,order_no,mo_number,source_system,source_order_no,source_routing_id,planned_quantity,planned_date,planner_priority,split_number)values(p_organization_id,'MO-E56-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code,'MO-E56-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code,'ORACLE_WMS',g.source_order_no,g.routing_revision_id,g.qty,g.due_date,g.priority,1)returning id into moid;created_count:=created_count+1;else update production_orders set planned_quantity=g.qty,planned_date=g.due_date,planner_priority=g.priority,updated_at=now()where id=moid;end if;insert into manufacturing_order_lines(organization_id,manufacturing_order_id,production_demand_line_id,source_order_no,source_order_line_id,product_id,routing_revision_id,planned_quantity,sequence)select d.organization_id,moid,d.id,d.source_order_no,d.source_order_line_id,d.product_id,d.routing_revision_id,d.quantity,row_number()over(order by d.source_order_line_id)::integer from production_demand_lines d where d.organization_id=p_organization_id and d.source_order_no=g.source_order_no and d.routing_revision_id=g.routing_revision_id and d.source_order_line_id like'E56:%'on conflict(production_demand_line_id)do nothing;get diagnostics affected=row_count;mapping_count:=mapping_count+affected;update production_demand_lines set status='GROUPED',updated_at=now()where organization_id=p_organization_id and source_order_no=g.source_order_no and routing_revision_id=g.routing_revision_id and source_order_line_id like'E56:%';end loop;
select coalesce(sum(ml.planned_quantity),0)into represented from manufacturing_order_lines ml join production_demand_lines d on d.id=ml.production_demand_line_id where d.organization_id=p_organization_id and d.source_order_line_id like'E56:%'and exists(select 1 from e56_mo_pilot_orders p where p.organization_id=d.organization_id and p.source_order_no=d.source_order_no);update e56_mo_pilot_orders set status=case when control_type='UNRELEASED_NEGATIVE'or exists(select 1 from production_orders po where po.organization_id=e56_mo_pilot_orders.organization_id and po.source_order_no=e56_mo_pilot_orders.source_order_no and po.mo_number like'MO-E56-%')then'PROCESSED'else'BLOCKED'end where organization_id=p_organization_id;update e56_mo_pilot_runs set completed_at=now(),source_lines=source_count,released_lines=released_count,mos_created=created_count,mappings_created=mapping_count,represented_quantity=represented,status='COMPLETED'where id=runid;return jsonb_build_object('runId',runid,'sourceLines',source_count,'releasedLines',released_count,'mosCreated',created_count,'mappingsCreated',mapping_count,'representedQuantity',represented,'unreleasedSourceLinesUsed',0,'unreleasedQuantityUsed',0);end$function$
;

-- public.run_e6_backfill_batch(p_run_id uuid, p_batch_no integer)
CREATE OR REPLACE FUNCTION public.run_e6_backfill_batch(p_run_id uuid, p_batch_no integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_org uuid;
  v_status text;
  v_latest_ingestion_run uuid;
  g record;
  v_mo uuid;
  v_created integer := 0;
  v_mappings integer := 0;
  v_affected integer;
begin
  select organization_id, status
    into v_org, v_status
  from e6_backfill_runs
  where id = p_run_id
  for update;

  if v_org is null then raise exception 'E6_RUN_NOT_FOUND'; end if;
  if v_status = 'COMPLETED' then raise exception 'E6_RUN_ALREADY_COMPLETED'; end if;
  if not exists (
    select 1 from e6_backfill_batches
    where run_id = p_run_id and batch_no = p_batch_no and status in ('PENDING', 'FAILED')
  ) then raise exception 'E6_BATCH_NOT_RUNNABLE'; end if;

  select snapshot_run_id into v_latest_ingestion_run from e6_backfill_runs where id=p_run_id;
  if v_latest_ingestion_run is null or not exists(select 1 from oracle_line_ingestion_runs where id=v_latest_ingestion_run and organization_id=v_org and snapshot_status='COMPLETE' and status='COMPLETED') then raise exception 'E6_PINNED_SNAPSHOT_INVALID'; end if;

  if exists(select 1 from e6_scope_classifications where run_id=p_run_id and(snapshot_run_id is distinct from v_latest_ingestion_run or prepared_released is not true or prepared_raw_release_value is distinct from 'Y')) then raise exception 'E6_PREPARED_SCOPE_RELEASE_MISMATCH'; end if;
  if exists(select 1 from e6_backfill_runs where id=p_run_id and(prepared_scope_rows is distinct from(select count(*)from e6_scope_classifications where run_id=p_run_id)or prepared_scope_quantity is distinct from(select coalesce(sum(quantity),0)from e6_scope_classifications where run_id=p_run_id)or prepared_scope_fingerprint is distinct from e6_scope_fingerprint(p_run_id)))then raise exception 'E6_PREPARED_SCOPE_FINGERPRINT_MISMATCH';end if;
  update e6_backfill_runs set status = 'RUNNING', error = null where id = p_run_id;
  update e6_backfill_batches
    set status = 'RUNNING', started_at = now(), completed_at = null, error = null
  where run_id = p_run_id and batch_no = p_batch_no;

  create temporary table e64_batch_scope on commit drop as
  select c.*, s.source_description, o.date_due, o.source_priority, r.code as routing_code
  from e6_scope_classifications c
  join e6_backfill_batch_orders b
    on b.run_id = c.run_id
   and b.source_order_no = c.source_order_no
   and b.batch_no = p_batch_no
  join routings r on r.id = c.routing_id
  join oracle_line_ingestion_staging s
    on s.ingestion_run_id = v_latest_ingestion_run
   and s.source_order_no = c.source_order_no
   and s.source_line_id = c.source_line_id
   and s.released = true and s.raw_release_value = 'Y'
  left join v_current_orders o
    on o.organization_id = c.organization_id
   and o.order_no = c.source_order_no
  where c.run_id = p_run_id
    and c.scope_classification = 'MO_REQUIRED_SUPPORTED';

  create index on e64_batch_scope (organization_id, source_order_no, source_line_id);
  create index on e64_batch_scope (source_order_no, routing_id);

  if not exists (
    select 1
    from e64_batch_scope c
    where not exists (
      select 1
      from production_demand_lines d
      join manufacturing_order_lines ml on ml.production_demand_line_id = d.id
      where d.organization_id = c.organization_id
        and d.source_system = 'ORACLE_WMS'
        and d.source_order_no = c.source_order_no
        and d.source_order_line_id in ('E56:' || c.source_line_id, 'E6:' || c.source_line_id)
    )
  ) then
    update e6_backfill_batches
      set status = 'COMPLETED', completed_at = now(), mos_created = 0, mappings_created = 0
    where run_id = p_run_id and batch_no = p_batch_no;
    return jsonb_build_object('runId', p_run_id, 'batchNo', p_batch_no, 'mosCreated', 0,
      'mappingsCreated', 0, 'alreadyRepresented', true);
  end if;

  alter table manufacturing_order_lines disable trigger recalculate_manufacturing_order_quantity_change;

  insert into production_demand_lines (
    organization_id, source_system, source_order_no, source_order_line_id, product_id,
    routing_id, routing_revision_id, source_product_code, source_description, quantity,
    due_date, source_priority, status, resolution_status, production_process_code
  )
  select c.organization_id, 'ORACLE_WMS', c.source_order_no, 'E6:' || c.source_line_id,
    c.product_id, c.routing_id, c.routing_id, c.source_product_code, c.source_description,
    c.quantity, c.date_due, c.source_priority, 'READY', 'RESOLVED', c.process_code
  from e64_batch_scope c
  left join production_demand_lines d56
    on d56.organization_id = c.organization_id and d56.source_system = 'ORACLE_WMS'
   and d56.source_order_no = c.source_order_no and d56.source_order_line_id = 'E56:' || c.source_line_id
  left join production_demand_lines d6
    on d6.organization_id = c.organization_id and d6.source_system = 'ORACLE_WMS'
   and d6.source_order_no = c.source_order_no and d6.source_order_line_id = 'E6:' || c.source_line_id
  where d56.id is null and d6.id is null
  on conflict (organization_id, source_system, source_order_no, source_order_line_id) do nothing;

  for g in
    select source_order_no, routing_id, sum(quantity)::numeric(14,3) qty,
      min(date_due)::date due_date, min(source_priority) priority, min(routing_code) routing_code
    from e64_batch_scope
    group by source_order_no, routing_id
  loop
    v_mo := null;
    select id into v_mo
    from production_orders
    where organization_id = v_org and source_system = 'ORACLE_WMS'
      and source_order_no = g.source_order_no and source_routing_id = g.routing_id and split_number = 1
    limit 1 for update;

    if v_mo is not null and exists (
      select 1 from production_orders where id = v_mo and not e56_mo_status_is_reconcilable(production_status)
    ) then raise exception 'IN_PROGRESS_MO_REACHED_EXECUTION:%/%', g.source_order_no, g.routing_id; end if;

    if v_mo is null then
      insert into production_orders (
        organization_id, order_no, mo_number, source_system, source_order_no, source_routing_id,
        planned_quantity, planned_date, planner_priority, split_number
      ) values (
        v_org, 'MO-E6-' || regexp_replace(g.source_order_no, '[^A-Za-z0-9_-]', '', 'g') || '-' || g.routing_code,
        'MO-E6-' || regexp_replace(g.source_order_no, '[^A-Za-z0-9_-]', '', 'g') || '-' || g.routing_code,
        'ORACLE_WMS', g.source_order_no, g.routing_id, g.qty, g.due_date, g.priority, 1
      ) returning id into v_mo;
      v_created := v_created + 1;
    else
      update production_orders
      set planned_quantity = g.qty, planned_date = g.due_date, planner_priority = g.priority, updated_at = now()
      where id = v_mo and (planned_quantity is distinct from g.qty or planned_date is distinct from g.due_date
        or planner_priority is distinct from g.priority);
    end if;

    insert into manufacturing_order_lines (
      organization_id, manufacturing_order_id, production_demand_line_id, source_order_no,
      source_order_line_id, product_id, routing_revision_id, planned_quantity, sequence
    )
    select c.organization_id, v_mo, coalesce(d56.id, d6.id), c.source_order_no,
      coalesce(d56.source_order_line_id, d6.source_order_line_id), c.product_id, c.routing_id,
      c.quantity, row_number() over (order by c.source_line_id)::integer
    from e64_batch_scope c
    left join production_demand_lines d56
      on d56.organization_id = c.organization_id and d56.source_system = 'ORACLE_WMS'
     and d56.source_order_no = c.source_order_no and d56.source_order_line_id = 'E56:' || c.source_line_id
    left join production_demand_lines d6
      on d6.organization_id = c.organization_id and d6.source_system = 'ORACLE_WMS'
     and d6.source_order_no = c.source_order_no and d6.source_order_line_id = 'E6:' || c.source_line_id
    left join manufacturing_order_lines existing
      on existing.production_demand_line_id = coalesce(d56.id, d6.id)
    where c.source_order_no = g.source_order_no and c.routing_id = g.routing_id
      and coalesce(d56.id, d6.id) is not null and existing.id is null
    on conflict (production_demand_line_id) do nothing;

    get diagnostics v_affected = row_count;
    v_mappings := v_mappings + v_affected;

    update production_demand_lines d
    set status = 'GROUPED', updated_at = now()
    from manufacturing_order_lines ml
    where ml.production_demand_line_id = d.id and ml.manufacturing_order_id = v_mo
      and d.status is distinct from 'GROUPED';
  end loop;

  alter table manufacturing_order_lines enable trigger recalculate_manufacturing_order_quantity_change;
  update e6_backfill_batches
    set status = 'COMPLETED', completed_at = now(), mos_created = v_created, mappings_created = v_mappings
  where run_id = p_run_id and batch_no = p_batch_no;
  update e6_backfill_runs
    set mos_created = mos_created + v_created, mappings_created = mappings_created + v_mappings
  where id = p_run_id;

  return jsonb_build_object('runId', p_run_id, 'batchNo', p_batch_no,
    'mosCreated', v_created, 'mappingsCreated', v_mappings);
exception when others then
  begin alter table manufacturing_order_lines enable trigger recalculate_manufacturing_order_quantity_change; exception when others then null; end;
  update e6_backfill_batches set status = 'FAILED', completed_at = now(), error = sqlerrm
  where run_id = p_run_id and batch_no = p_batch_no;
  update e6_backfill_runs set status = 'FAILED', error = sqlerrm where id = p_run_id;
  raise;
end
$function$
;

-- public.run_production_reconciliation(p_organization_id uuid, p_quantity_tolerance numeric)
CREATE OR REPLACE FUNCTION public.run_production_reconciliation(p_organization_id uuid, p_quantity_tolerance numeric DEFAULT 1)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_run_id uuid; v_batch_id uuid;
begin
  if p_quantity_tolerance < 0 then raise exception 'Quantity tolerance cannot be negative'; end if;
  select id into v_batch_id from v_latest_completed_batch where organization_id=p_organization_id;
  insert into production_reconciliation_runs(organization_id,sync_batch_id,quantity_tolerance)
  values(p_organization_id,v_batch_id,p_quantity_tolerance) returning id into v_run_id;

  insert into production_reconciliation_items(
    organization_id,reconciliation_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,
    quantity_result,overall_result,detail)
  with legacy as (
    select organization_id,order_no,'DTG'::text legacy_area,'DTG_PRINT'::text expected_operation_code,remaining_units legacy_remaining_quantity
    from v_dtg_operational_orders where organization_id=p_organization_id
    union all
    select organization_id,order_no,'UP','UNDERPRINT',remaining_units
    from v_up_operational_orders where organization_id=p_organization_id
  ), canonical as (
    select x.organization_id,coalesce(x.source_order_no,x.order_no) order_no,x.current_operation_code,
      case when poo.planned_quantity is null then null
        else greatest(poo.planned_quantity-coalesce(poo.actual_quantity,0),0) end canonical_remaining_quantity,
      x.production_order_id,x.production_status
    from v_production_order_execution x
    left join production_order_operations poo on poo.id=x.current_operation_id
    where x.organization_id=p_organization_id and x.production_status not in ('CANCELLED','COMPLETED','UNROUTED')
  ), compared as (
    select coalesce(l.organization_id,c.organization_id) organization_id,coalesce(l.order_no,c.order_no) order_no,
      l.legacy_area,l.expected_operation_code,c.current_operation_code canonical_operation_code,
      l.legacy_remaining_quantity,c.canonical_remaining_quantity,
      case when l.legacy_remaining_quantity is not null and c.canonical_remaining_quantity is not null
        then c.canonical_remaining_quantity-l.legacy_remaining_quantity end quantity_variance,
      case when c.order_no is null then 'MISSING_CANONICAL' when l.order_no is null then 'MISSING_LEGACY' else 'BOTH' end presence_result,
      case when c.order_no is null or l.order_no is null then 'NOT_COMPARABLE'
        when c.current_operation_code=l.expected_operation_code then 'MATCH' else 'MISMATCH' end operation_result,
      case when l.legacy_remaining_quantity is null or c.canonical_remaining_quantity is null then 'NOT_COMPARABLE'
        when abs(c.canonical_remaining_quantity-l.legacy_remaining_quantity)<=p_quantity_tolerance then 'MATCH' else 'MISMATCH' end quantity_result,
      c.production_order_id,c.production_status
    from legacy l full join canonical c on c.organization_id=l.organization_id and c.order_no=l.order_no
  )
  select organization_id,v_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,quantity_result,
    case when presence_result='MISSING_CANONICAL' then 'MISSING_CANONICAL'
      when presence_result='MISSING_LEGACY' then 'MISSING_LEGACY'
      when operation_result='MISMATCH' or quantity_result='MISMATCH' then 'MISMATCH' else 'MATCH' end,
    jsonb_build_object('production_order_id',production_order_id,'production_status',production_status,
      'quantity_semantics','legacy remaining versus canonical planned minus actual')
  from compared;

  update production_reconciliation_runs r set
    status='COMPLETED',completed_at=now(),
    total_orders=s.total_orders,matched_orders=s.matched_orders,mismatched_orders=s.mismatched_orders,
    missing_canonical_orders=s.missing_canonical_orders,missing_legacy_orders=s.missing_legacy_orders,
    comparable_quantity_orders=s.comparable_quantity_orders,quantity_matched_orders=s.quantity_matched_orders,
    match_rate=case when s.total_orders=0 then null else round(100.0*s.matched_orders/s.total_orders,4) end
  from (
    select count(*)::integer total_orders,count(*) filter(where overall_result='MATCH')::integer matched_orders,
      count(*) filter(where overall_result='MISMATCH')::integer mismatched_orders,
      count(*) filter(where overall_result='MISSING_CANONICAL')::integer missing_canonical_orders,
      count(*) filter(where overall_result='MISSING_LEGACY')::integer missing_legacy_orders,
      count(*) filter(where quantity_result<>'NOT_COMPARABLE')::integer comparable_quantity_orders,
      count(*) filter(where quantity_result='MATCH')::integer quantity_matched_orders
    from production_reconciliation_items where reconciliation_run_id=v_run_id
  ) s where r.id=v_run_id;
  return v_run_id;
exception when others then
  if v_run_id is not null then update production_reconciliation_runs set status='FAILED',completed_at=now(),error_message=left(sqlerrm,1000) where id=v_run_id; end if;
  raise;
end $function$
;

-- public.seed_source_operation_mappings(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.seed_source_operation_mappings(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare affected integer;
begin
  insert into source_operation_mappings(organization_id,source_dataset,source_field,match_type,match_value,operation_id,completion_semantics,priority)
  select p_organization_id, x.dataset, x.field_name, x.match_type, x.match_value, o.id, x.semantics, x.priority
  from (values
    ('WORKBANK','queue','EXACT','SP11','PICKING','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','SP11','PICKING','ENTERED_OPERATION',10),
    ('WORKBANK','queue','EXACT','PCOR','DTG_PRINT','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',10),
    ('AUDIT','task','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',20),
    ('AUDIT','to_zone','EXACT','PWL1','PUTWALL','ENTERED_OPERATION',10),
    ('AUDIT','from_zone','EXACT','PWL1','PUTWALL','COMPLETED_OPERATION',10),
    ('STOCK','source_zone','EXACT','PWL1','PUTWALL','CURRENT_LOCATION',10),
    ('AUDIT','to_location','EXACT','DTGMOVE','DISPATCH','MOVED_TO_OPERATION',10),
    ('STOCK','location','LIKE','%UNDERPRINT%','UNDERPRINT','CURRENT_LOCATION',10),
    ('WORKBANK','from_location','SUFFIX','UP','UNDERPRINT','CURRENT_LOCATION',20),
    ('AUDIT','to_location','EXACT','UPMOVE','DISPATCH','MOVED_TO_OPERATION',20)
  ) x(dataset,field_name,match_type,match_value,operation_code,semantics,priority)
  join operations o on o.organization_id=p_organization_id and o.code=x.operation_code
  on conflict do nothing;
  get diagnostics affected=row_count;
  return affected;
end $function$
;

-- public.select_e56_mo_pilot(p_organization_id uuid, p_limit integer)
CREATE OR REPLACE FUNCTION public.select_e56_mo_pilot(p_organization_id uuid, p_limit integer DEFAULT 24)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin delete from e56_mo_pilot_orders where organization_id=p_organization_id and status='SELECTED';with candidates as(select r.source_order_no,s.release_status,count(*)filter(where r.eligibility_status='ELIGIBLE')eligible_lines,count(distinct r.resolved_routing_id)filter(where r.eligibility_status='ELIGIBLE')routing_count,row_number()over(partition by s.release_status order by count(distinct r.resolved_routing_id)desc,count(*)desc,r.source_order_no)rn from v_released_demand_resolution r join v_sales_order_release_state s using(organization_id,source_order_no)where r.organization_id=p_organization_id group by r.source_order_no,s.release_status),positive as(select source_order_no,case when release_status='PARTIALLY_RELEASED'then'PARTIAL_RELEASE'else'RELEASED'end control_type,release_status||'; eligible lines='||eligible_lines||'; routings='||routing_count reason from candidates where eligible_lines>0 and rn<=8 order by routing_count desc,source_order_no limit greatest(p_limit-4,1)),negative as(select source_order_no,'UNRELEASED_NEGATIVE'control_type,'Fully unreleased negative control'reason from v_sales_order_release_state s where s.organization_id=p_organization_id and s.release_status='UNRELEASED'order by source_order_no limit 4),all_candidates as(select*from positive union all select*from negative)insert into e56_mo_pilot_orders(organization_id,source_order_no,control_type,selection_reason)select p_organization_id,source_order_no,control_type,reason from all_candidates on conflict(organization_id,source_order_no)do update set control_type=excluded.control_type,selection_reason=excluded.selection_reason,status='SELECTED',selected_at=now();get diagnostics n=row_count;return n;end$function$
;

-- public.select_phase_e51_pilot(p_organization_id uuid, p_limit integer)
CREATE OR REPLACE FUNCTION public.select_phase_e51_pilot(p_organization_id uuid, p_limit integer DEFAULT 24)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin with ranked as(select s.*,row_number()over(partition by current_stage order by process_count desc,coalesce(priority,999),due_date nulls last,units desc,source_order_no)stage_rank from v_active_order_process_summary s where organization_id=p_organization_id and exists(select 1 from v_active_source_product_lines l where l.organization_id=s.organization_id and l.source_order_no=s.source_order_no and l.process_code=s.process_code and l.source_sku is not null)),candidate as(select*,case when process_count>1 then'MULTI_ROUTING_SO'when current_stage='PWL1'then'DTG_PUTWALL'when current_stage='PCOR'then'DTG_PRINT_PARTIAL'when current_stage='SP11'then'DTG_PICKING'else'UNDERPRINT_ACTIVE'end reason from ranked where stage_rank<=6 order by process_count desc,coalesce(priority,999),due_date nulls last,source_order_no limit p_limit)insert into mo_backfill_pilot_orders(organization_id,source_order_no,selection_reason)select p_organization_id,source_order_no,string_agg(distinct reason,', 'order by reason)from candidate group by source_order_no on conflict(organization_id,source_order_no)do update set selection_reason=excluded.selection_reason;get diagnostics n=row_count;return n;end$function$
;

-- public.snapshot_e62_resolution(p_e6_run_id uuid)
CREATE OR REPLACE FUNCTION public.snapshot_e62_resolution(p_e6_run_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 delete from e62_resolution_audit where e6_run_id=p_e6_run_id;
 insert into e62_resolution_audit(organization_id,e6_run_id,source_order_no,source_line_id,source_product_code,product_id,routing_id,process_code,product_confidence,process_confidence,resolution_rule,resolution_status,quantity)
 select organization_id,run_id,source_order_no,source_line_id,source_product_code,product_id,
  case when product_id is not null and process_code is not null then resolve_product_process_routing(organization_id,product_id,process_code,null)end,
  process_code,product_confidence,process_confidence,resolution_rule,
  case when product_confidence='AMBIGUOUS'or process_confidence='AMBIGUOUS'then'AMBIGUOUS'when product_id is not null and process_code in('DTG','UNDERPRINT','SCREEN_PRINT')and resolve_product_process_routing(organization_id,product_id,process_code,null)is not null then'RESOLVED_SUPPORTED'else'UNRESOLVED'end,quantity
 from v_e62_resolution_dry_run where run_id=p_e6_run_id;
 get diagnostics n=row_count;return n;end$function$
;

-- public.snapshot_e63_process_resolution(p_run_id uuid)
CREATE OR REPLACE FUNCTION public.snapshot_e63_process_resolution(p_run_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 insert into e63_process_resolution_audit(run_id,organization_id,source_order_no,source_line_id,source_product_code,quantity,observed_codes,resolved_process,operational_stage,mo_scope,resolution_status,reason)
 select c.run_id,c.organization_id,c.source_order_no,c.source_line_id,c.source_product_code,c.quantity,h.codes,
 case when cardinality(h.processes)=1 then h.processes[1]end,
 case when cardinality(h.stages)=1 then h.stages[1]end,
 case when cardinality(h.scopes)=1 then h.scopes[1]end,
 case when cardinality(h.processes)>1 then'AMBIGUOUS'
      when cardinality(h.processes)=1 and cardinality(h.scopes)=1 then h.scopes[1]
      else'TRUE_PROCESS_UNRESOLVED'end,
 case when cardinality(h.processes)>1 then'CONFLICTING_OPERATIONAL_CODES'
      when cardinality(h.processes)=1 then'SOURCE_OPERATIONAL_CODE'
      when cardinality(h.codes)>0 then'UNMAPPED_OPERATIONAL_CODE'
      else'OPERATIONAL_CODE_NOT_CAPTURED'end
 from e6_scope_classifications c
 left join lateral(
  select array_agg(distinct upper(trim(w.queue)))filter(where nullif(trim(w.queue),'')is not null)codes,
   array_agg(distinct m.manufacturing_process)filter(where m.manufacturing_process is not null)processes,
   array_agg(distinct m.operational_stage)filter(where m.operational_stage is not null)stages,
   array_agg(distinct m.mo_scope)filter(where m.manufacturing_process is not null)scopes
  from source_workbank_items w left join source_operational_code_mappings m on m.organization_id=w.organization_id and m.source_dataset='WORKBANK'and m.source_field='queue'and m.source_operational_code=upper(trim(coalesce(w.queue,'')))and m.active
  where w.organization_id=c.organization_id and w.order_no=c.source_order_no and w.product_code=c.source_product_code
 )h on true
 where c.run_id=p_run_id and c.scope_classification='CONTROLLED_EXCEPTION'
 on conflict(run_id,source_order_no,source_line_id)do nothing;
 get diagnostics n=row_count;return n;
end$function$
;

-- public.snapshot_e64_process_resolution(p_e63_run uuid, p_ingestion_run uuid)
CREATE OR REPLACE FUNCTION public.snapshot_e64_process_resolution(p_e63_run uuid, p_ingestion_run uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 insert into e64_process_resolution_audit(source_e63_run_id,ingestion_run_id,organization_id,source_order_no,source_line_id,source_product_code,quantity,current_operational_code,current_operational_codes,process_origin_code,process_origin_codes,manufacturing_process,operational_stage,mo_scope,provenance,resolution_status,reason,source_released)
 select p_e63_run,p_ingestion_run,u.organization_id,u.source_order_no,u.source_line_id,u.source_product_code,u.quantity,s.source_operational_code,s.source_operational_codes,s.process_origin_code,s.process_origin_codes,
 case when s.operational_code_conflict or s.process_origin_conflict then null when cm.manufacturing_process is not null then cm.manufacturing_process else hm.manufacturing_process end,
 case when cm.manufacturing_process is not null then cm.operational_stage else hm.operational_stage end,
 case when cm.manufacturing_process is not null then cm.mo_scope else hm.mo_scope end,
 case when cm.manufacturing_process is not null then'CURRENT_OPERATIONAL_CODE'when hm.manufacturing_process is not null then'AUTHORITATIVE_OPERATIONAL_HISTORY'end,
 case when s.source_order_no is null then'CONTROLLED_EXCEPTION'
      when s.operational_code_conflict then'AMBIGUOUS_CURRENT_OPERATIONAL_CODE'
      when s.process_origin_conflict then'AMBIGUOUS_PROCESS_HISTORY'
      when coalesce(cm.mo_scope,hm.mo_scope)='CURRENT_SUPPORTED_PROCESS'then'CURRENT_SUPPORTED_PROCESS'
      when coalesce(cm.mo_scope,hm.mo_scope)='PROCESS_NOT_YET_SUPPORTED'then'PROCESS_NOT_YET_SUPPORTED'
      when coalesce(cm.mo_scope,hm.mo_scope)='NO_MO_REQUIRED'then'NO_MO_REQUIRED'
      else'TRUE_PROCESS_UNRESOLVED'end,
 case when s.source_order_no is null then'NOT_IN_NEW_ACTIVE_SNAPSHOT'
      when s.operational_code_conflict then'CONFLICTING_CURRENT_OPERATIONAL_CODES'
      when s.process_origin_conflict then'CONFLICTING_AUTHORITATIVE_PROCESS_HISTORY'
      when cm.manufacturing_process is not null then'CONFIRMED_CURRENT_CODE'
      when hm.manufacturing_process is not null then'CONFIRMED_UNIQUE_ORACLE_HISTORY'
      else'NO_PROCESS_IDENTIFYING_CODE'end,s.released
 from e63_process_resolution_audit u
 left join oracle_line_ingestion_staging s on s.ingestion_run_id=p_ingestion_run and s.source_order_no=u.source_order_no and s.source_line_id=u.source_line_id
 left join source_operational_code_mappings cm on cm.organization_id=u.organization_id and cm.source_dataset='WORKBANK'and cm.source_field='queue'and cm.source_operational_code=s.source_operational_code and cm.active
 left join source_operational_code_mappings hm on hm.organization_id=u.organization_id and hm.source_dataset='WORKBANK'and hm.source_field='queue'and hm.source_operational_code=s.process_origin_code and hm.active
 where u.run_id=p_e63_run and u.resolution_status='TRUE_PROCESS_UNRESOLVED'
 on conflict(source_e63_run_id,ingestion_run_id,source_order_no,source_line_id)do nothing;
 get diagnostics n=row_count;return n;
end$function$
;

-- public.source_value_matches(p_actual text, p_match_type text, p_expected text)
CREATE OR REPLACE FUNCTION public.source_value_matches(p_actual text, p_match_type text, p_expected text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  select case p_match_type
    when 'EXACT' then upper(coalesce(p_actual,'')) = upper(p_expected)
    when 'PREFIX' then upper(coalesce(p_actual,'')) like upper(p_expected) || '%'
    when 'SUFFIX' then upper(coalesce(p_actual,'')) like '%' || upper(p_expected)
    when 'LIKE' then upper(coalesce(p_actual,'')) like upper(p_expected)
    else false
  end
$function$
;

-- public.stage_workbank_demand_lines(p_organization_id uuid)
CREATE OR REPLACE FUNCTION public.stage_workbank_demand_lines(p_organization_id uuid)
 RETURNS TABLE(staged integer, exceptions integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare s integer:=0;x integer:=0;begin
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,source_product_code,source_description,quantity,due_date,source_priority,status,resolution_status)
select w.organization_id,'ORACLE_WMS',w.order_no,'WORKBANK:'||w.source_row_id,p.id,p.default_routing_id,p.default_routing_id,w.product_code,w.product_description,w.production_units,w.source_due_at,w.source_priority,case when p.id is not null and r.id is not null then'READY'else'EXCEPTION'end,case when p.id is null then'PRODUCT_UNMAPPED'when r.id is null then'ROUTING_UNMAPPED'else'RESOLVED'end
from v_current_workbank w left join product_source_mappings m on m.organization_id=w.organization_id and m.source_system='ORACLE_WMS'and m.source_product_code=w.product_code and m.active left join products p on p.id=m.product_id and p.organization_id=w.organization_id and p.active left join routings r on r.id=p.default_routing_id and r.organization_id=w.organization_id and r.status='ACTIVE'and r.active
where w.organization_id=p_organization_id and nullif(w.source_row_id,'')is not null and w.production_units>0
on conflict(organization_id,source_system,source_order_no,source_order_line_id)do update set source_product_code=excluded.source_product_code,source_description=excluded.source_description,due_date=excluded.due_date,source_priority=excluded.source_priority,updated_at=now()where production_demand_lines.status in('READY','EXCEPTION');get diagnostics s=row_count;
insert into production_demand_exceptions(organization_id,production_demand_line_id,exception_type,description)select d.organization_id,d.id,d.resolution_status,'Workbank line requires Product and Routing setup before MO creation.'from production_demand_lines d where d.organization_id=p_organization_id and d.status='EXCEPTION'on conflict do nothing;get diagnostics x=row_count;return query select s,x;end$function$
;

-- public.time_dist(time without time zone, time without time zone)
CREATE OR REPLACE FUNCTION public.time_dist(time without time zone, time without time zone)
 RETURNS interval
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$time_dist$function$
;

-- public.transition_daily_plan(p_plan_id uuid, p_action text, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.transition_daily_plan(p_plan_id uuid, p_action text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare stat text;items integer;begin select status into stat from production_plans where id=p_plan_id for update;select count(*)into items from production_plan_items where production_plan_id=p_plan_id;if p_action='publish'then if stat<>'draft'or items=0 then raise exception 'Only non-empty drafts can be published';end if;update production_plans set status='published',published_by=p_actor_id,published_at=now(),updated_at=now()where id=p_plan_id;elsif p_action='close'then if stat<>'published'then raise exception 'Only published plans can be closed';end if;update production_plans set status='closed',closed_by=p_actor_id,closed_at=now(),updated_at=now()where id=p_plan_id;else raise exception 'Invalid action';end if;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select p_plan_id,p_action,p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=p_plan_id;end$function$
;

-- public.ts_dist(timestamp without time zone, timestamp without time zone)
CREATE OR REPLACE FUNCTION public.ts_dist(timestamp without time zone, timestamp without time zone)
 RETURNS interval
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$ts_dist$function$
;

-- public.tstz_dist(timestamp with time zone, timestamp with time zone)
CREATE OR REPLACE FUNCTION public.tstz_dist(timestamp with time zone, timestamp with time zone)
 RETURNS interval
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$tstz_dist$function$
;

-- public.update_daily_plan_item(p_item_id uuid, p_sequence integer, p_responsible text, p_units numeric, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.update_daily_plan_item(p_item_id uuid, p_sequence integer, p_responsible text, p_units numeric, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pid uuid;stat text;begin select i.production_plan_id,p.status into pid,stat from production_plan_items i join production_plans p on p.id=i.production_plan_id where i.id=p_item_id for update;if stat<>'draft'then raise exception 'Only drafts can be edited';end if;update production_plan_items set sequence=p_sequence,responsible=nullif(trim(p_responsible),''),planned_units=p_units,updated_at=now()where id=p_item_id;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select pid,'item_updated',p_actor_id,p_actor_email,to_jsonb(i)from production_plan_items i where id=p_item_id;end$function$
;

-- public.update_manufacturing_order_line_quantity(p_organization_id uuid, p_source_system text, p_source_order_no text, p_source_order_line_id text, p_new_quantity numeric)
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

-- public.validate_product_default_routing()
CREATE OR REPLACE FUNCTION public.validate_product_default_routing()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if new.default_routing_id is not null and not exists(select 1 from routings r where r.id=new.default_routing_id and r.organization_id=new.organization_id and r.status='ACTIVE'and r.active and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date))then raise exception 'Product default routing must be active, effective and in the same organization';end if;return new;
end$function$
;

-- storage.allow_any_operation(expected_operations text[])
CREATE OR REPLACE FUNCTION storage.allow_any_operation(expected_operations text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT CASE
      WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
      ELSE raw_operation
    END AS current_operation
    FROM current_operation
  )
  SELECT EXISTS (
    SELECT 1
    FROM normalized n
    CROSS JOIN LATERAL unnest(expected_operations) AS expected_operation
    WHERE expected_operation IS NOT NULL
      AND expected_operation <> ''
      AND n.current_operation = CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END
  );
$function$
;

-- storage.allow_only_operation(expected_operation text)
CREATE OR REPLACE FUNCTION storage.allow_only_operation(expected_operation text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  WITH current_operation AS (
    SELECT storage.operation() AS raw_operation
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_operation LIKE 'storage.%' THEN substr(raw_operation, 9)
        ELSE raw_operation
      END AS current_operation,
      CASE
        WHEN expected_operation LIKE 'storage.%' THEN substr(expected_operation, 9)
        ELSE expected_operation
      END AS requested_operation
    FROM current_operation
  )
  SELECT CASE
    WHEN requested_operation IS NULL OR requested_operation = '' THEN FALSE
    ELSE COALESCE(current_operation = requested_operation, FALSE)
  END
  FROM normalized;
$function$
;

-- storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb)
CREATE OR REPLACE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$function$
;

-- storage.enforce_bucket_name_length()
CREATE OR REPLACE FUNCTION storage.enforce_bucket_name_length()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$function$
;

-- storage.extension(name text)
CREATE OR REPLACE FUNCTION storage.extension(name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Get the last path segment (the actual filename)
    SELECT _parts[array_length(_parts, 1)] INTO _filename;
    -- Extract extension: reverse, split on '.', then reverse again
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$function$
;

-- storage.filename(name text)
CREATE OR REPLACE FUNCTION storage.filename(name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    RETURN _parts[array_length(_parts, 1)];
END
$function$
;

-- storage.foldername(name text)
CREATE OR REPLACE FUNCTION storage.foldername(name text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$function$
;

-- storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text)
CREATE OR REPLACE FUNCTION storage.get_common_prefix(p_key text, p_prefix text, p_delimiter text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$function$
;

-- storage.get_size_by_bucket()
CREATE OR REPLACE FUNCTION storage.get_size_by_bucket()
 RETURNS TABLE(size bigint, bucket_id text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    return query
        select sum((metadata->>'size')::bigint)::bigint as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$function$
;

-- storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer, next_key_token text, next_upload_token text)
CREATE OR REPLACE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text)
 RETURNS TABLE(key text, id text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$function$
;

-- storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer, start_after text, next_token text, sort_order text)
CREATE OR REPLACE FUNCTION storage.list_objects_with_delimiter(_bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$function$
;

-- storage.operation()
CREATE OR REPLACE FUNCTION storage.operation()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$function$
;

-- storage.protect_delete()
CREATE OR REPLACE FUNCTION storage.protect_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$function$
;

-- storage.search(prefix text, bucketname text, limits integer, levels integer, offsets integer, search text, sortcolumn text, sortorder text)
CREATE OR REPLACE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text)
 RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_prefix_len INT;
    v_prefix_start INT;
    v_combined_levels INT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_prefix_len := length(coalesce(prefix, ''));
    v_prefix_start := coalesce(array_length(string_to_array(coalesce(prefix, ''), v_delimiter), 1), 1);
    v_combined_levels := coalesce(array_length(string_to_array(v_prefix, v_delimiter), 1), 1);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT array_to_string(path_tokens[$1:$2], '/') AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $3 || '%%'
                  AND bucket_id = $4
                  AND array_length(objects.path_tokens, 1) <> $2
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT array_to_string(path_tokens[$1:$2], '/') AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $3 || '%%'
               AND bucket_id = $4
               AND array_length(objects.path_tokens, 1) = $2
             ORDER BY %I %s)
            LIMIT $5 OFFSET $6
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING v_prefix_start, v_combined_levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := substring(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter) from v_prefix_len + 1);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := substring(v_current.name from v_prefix_len + 1);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$function$
;

-- storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text)
CREATE OR REPLACE FUNCTION storage.search_by_timestamp(p_prefix text, p_bucket_id text, p_limit integer, p_level integer, p_start_after text, p_sort_order text, p_sort_column text, p_sort_column_after text)
 RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
    v_sort_order text;
    v_sort_column text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    -- Defense-in-depth: this function is independently reachable and must
    -- not trust p_sort_order/p_sort_column to already be validated by a
    -- caller. Normalize to the same strict allow-list storage.search_v2
    -- uses before interpolating anything into dynamic SQL below.
    v_sort_order := lower(coalesce(p_sort_order, 'asc'));
    IF v_sort_order NOT IN ('asc', 'desc') THEN
        v_sort_order := 'asc';
    END IF;

    v_sort_column := lower(coalesce(p_sort_column, 'updated_at'));
    IF v_sort_column NOT IN ('updated_at', 'created_at') THEN
        v_sort_column := 'updated_at';
    END IF;

    IF v_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        v_sort_column,
        v_cursor_op,
        v_sort_column,
        v_sort_order,
        v_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$function$
;

-- storage.search_v2(prefix text, bucket_name text, limits integer, levels integer, start_after text, sort_order text, sort_column text, sort_column_after text)
CREATE OR REPLACE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text)
 RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$function$
;

-- storage.update_updated_at_column()
CREATE OR REPLACE FUNCTION storage.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$function$
;

