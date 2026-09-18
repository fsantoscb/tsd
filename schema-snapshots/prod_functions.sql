-- public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p production_plans%rowtype;n text;po production_orders%rowtype;units numeric;seq integer;added integer:=0;begin select*into p from production_plans where id=p_plan_id for update;if p.id is null then raise exception 'Plan not found';end if;if p.status<>'draft'then raise exception 'Only drafts can be edited';end if;select coalesce(max(sequence),0)into seq from production_plan_items where production_plan_id=p_plan_id;foreach n in array p_order_nos loop select*into po from production_orders where organization_id=p.organization_id and order_no=n and planning_status in('planned','ready','in_progress');if po.id is null then raise exception 'Order % is not planned',n;end if;select remaining_units into units from v_production_planning where organization_id=p.organization_id and order_no=n and line=(select code from production_areas where id=p.production_area_id)limit 1;if units is null or units<=0 then raise exception 'Order unavailable in area';end if;seq=seq+1;insert into production_plan_items(production_plan_id,production_order_id,order_no,sequence,planned_units,special_instruction)values(p_plan_id,po.id,n,seq,units,po.special_instruction)on conflict(production_plan_id,production_order_id)do nothing;if found then added=added+1;end if;end loop;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)values(p_plan_id,'items_added',p_actor_id,p_actor_email,jsonb_build_object('orders',p_order_nos,'added',added));return added;end$function$
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
update production_orders set planner_priority=case when p_changes?'planner_priority' then nullif(p_changes->>'planner_priority','')::integer else planner_priority end,planned_date=case when p_changes?'planned_date' then nullif(p_changes->>'planned_date','')::date else planned_date end,planned_shift_id=case when p_changes?'planned_shift_id' then nullif(p_changes->>'planned_shift_id','')::uuid else planned_shift_id end,planning_status=new_status,special_instruction=case when p_changes?'special_instruction' then nullif(trim(p_changes->>'special_instruction'),'') else special_instruction end,planner_note=case when p_changes?'planner_note' then nullif(trim(p_changes->>'planner_note'),'') else planner_note end,blocked_reason=case when new_status='blocked' then nullif(trim(p_changes->>'blocked_reason'),'') else null end,updated_at=now(),updated_by=p_actor_id where id=row_id returning to_jsonb(production_orders.*) into new_row;
insert into production_order_history(production_order_id,organization_id,order_no,changed_by,changed_by_email,before_state,after_state) values(row_id,p_organization_id,n,p_actor_id,p_actor_email,old_row,new_row); changed=changed+1;
end loop; return changed; end $function$
;

-- public.cash_dist(money, money)
CREATE OR REPLACE FUNCTION public.cash_dist(money, money)
 RETURNS money
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$cash_dist$function$
;

-- public.claim_sync_work(p_organization_id uuid, p_agent_id text, p_connector_version text, p_interval_seconds integer)
CREATE OR REPLACE FUNCTION public.claim_sync_work(p_organization_id uuid, p_agent_id text, p_connector_version text, p_interval_seconds integer DEFAULT 300)
 RETURNS TABLE(run_id uuid, request_id uuid, trigger_type text, should_execute boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_run uuid;v_request uuid;v_trigger text;v_last_auto timestamptz;begin perform pg_advisory_xact_lock(hashtextextended('sync-control:'||p_organization_id::text,0));update sync_runs set status='FAILED',completed_at=now(),duration_ms=extract(epoch from(now()-started_at))*1000,failure_reason='STALE_RUN_LEASE_EXPIRED'where organization_id=p_organization_id and status='RUNNING'and started_at<now()-interval'20 minutes';update sync_refresh_requests r set status='FAILED',completed_at=now(),failure_reason='STALE_RUN_LEASE_EXPIRED'where r.organization_id=p_organization_id and r.status='RUNNING'and not exists(select 1 from sync_runs s where s.id=r.sync_run_id and s.status='RUNNING');if exists(select 1 from sync_runs s where s.organization_id=p_organization_id and s.status='RUNNING')then insert into sync_runs(organization_id,trigger_type,status,requested_at,completed_at,agent_id,connector_version,failure_reason)values(p_organization_id,'AUTOMATIC','SKIPPED_ALREADY_RUNNING',now(),now(),p_agent_id,p_connector_version,'ACTIVE_RUN_EXISTS')returning id into v_run;return query select v_run,null::uuid,'AUTOMATIC'::text,false;return;end if;select r.id into v_request from sync_refresh_requests r where r.organization_id=p_organization_id and r.status='QUEUED'order by r.requested_at limit 1 for update skip locked;if v_request is not null then v_trigger:='MANUAL';else select max(s.requested_at)into v_last_auto from sync_runs s where s.organization_id=p_organization_id and s.trigger_type='AUTOMATIC'and s.status in('RUNNING','SUCCESS','FAILED');if v_last_auto is not null and v_last_auto>now()-make_interval(secs=>greatest(60,p_interval_seconds))then return;end if;v_trigger:='AUTOMATIC';end if;insert into sync_runs(organization_id,refresh_request_id,trigger_type,status,requested_at,started_at,agent_id,connector_version)values(p_organization_id,v_request,v_trigger,'RUNNING',now(),now(),p_agent_id,p_connector_version)returning id into v_run;if v_request is not null then update sync_refresh_requests set status='RUNNING',started_at=now(),sync_run_id=v_run where id=v_request;end if;return query select v_run,v_request,v_trigger,true;end$function$
;

-- public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)
CREATE OR REPLACE FUNCTION public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare result uuid;begin if not exists(select 1 from shift_templates where id=p_shift_id and organization_id=p_organization_id and active)then raise exception 'Invalid shift';end if;if not exists(select 1 from production_areas where id=p_area_id and organization_id=p_organization_id and active and code<>'UNMAPPED')then raise exception 'Invalid area';end if;insert into production_plans(organization_id,production_date,shift_template_id,production_area_id,created_by)values(p_organization_id,p_production_date,p_shift_id,p_area_id,p_actor_id)returning id into result;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select result,'created',p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=result;return result;end$function$
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
select w.order_no,max(w.customer_name),min(w.source_due_at),coalesce(sum(w.production_units)filter(where upper(trim(w.queue))='SP11'),0)::bigint,coalesce(sum(w.prints_per_garment)filter(where upper(trim(w.queue))='SP11'),0),count(*)filter(where upper(trim(w.from_zone))='DTGS'),coalesce(sum(w.prints_per_garment)filter(where upper(trim(w.from_zone))='DTGS'),0)
from source_workbank_items w join latest on latest.id=w.sync_batch_id where upper(trim(w.queue))='SP11' or upper(trim(w.from_zone))='DTGS' group by w.order_no
$function$
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

-- public.finish_sync_work(p_run_id uuid, p_status text, p_batch_id uuid, p_duration_ms bigint, p_orders integer, p_workbank integer, p_stock integer, p_audit integer, p_failure text)
CREATE OR REPLACE FUNCTION public.finish_sync_work(p_run_id uuid, p_status text, p_batch_id uuid, p_duration_ms bigint, p_orders integer, p_workbank integer, p_stock integer, p_audit integer, p_failure text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_request uuid;begin if p_status not in('SUCCESS','FAILED')then raise exception'INVALID_SYNC_STATUS';end if;update sync_runs set status=p_status,completed_at=now(),duration_ms=p_duration_ms,batch_id=p_batch_id,orders_count=coalesce(p_orders,0),workbank_count=coalesce(p_workbank,0),stock_count=coalesce(p_stock,0),audit_count=coalesce(p_audit,0),failure_reason=left(p_failure,1000)where id=p_run_id and status='RUNNING'returning refresh_request_id into v_request;if v_request is not null then update sync_refresh_requests set status=p_status,completed_at=now(),failure_reason=left(p_failure,1000)where id=v_request;end if;end$function$
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
AS $function$declare v_inserted bigint:=0;begin
 if jsonb_typeof(p_events)<>'array'or jsonb_array_length(p_events)>1000 then raise exception'INVALID_BACKFILL_PAYLOAD';end if;
 insert into public.source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,queue,task)
 select p_organization_id,event->>'sourceAuditId',coalesce(event->>'orderNo',''),event->>'username',event->>'fromZone',event->>'toZone',event->>'fromLocation',event->>'toLocation',event->>'product',event->>'fromPackId',event->>'toPackId',nullif(event->>'sourceQty','')::numeric,nullif(event->>'sourceWeight','')::numeric,coalesce(nullif(event->>'productionUnits','')::numeric,0),(event->>'eventAt')::timestamptz,event->>'rawHash',event->>'queue',event->>'task'from jsonb_array_elements(p_events)event on conflict do nothing;
 insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)
 select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone'Australia/Brisbane',(a.event_at at time zone'Australia/Brisbane')::date,case when r.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<r.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end,extract(hour from a.event_at at time zone'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,a.production_units,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then'OUT_OF_SHIFT'else'COMPLETE'end,'ERP_KPI_V1'
 from source_audit_events a cross join lateral(select*from(values('DTG'::text,'DTG_PRINT'::text,'prints'::text,upper(coalesce(a.queue,''))='PCOR'or upper(coalesce(a.task,''))='PCOR'),('DTG','DTG_PUTWALL_IN','garments',upper(coalesce(a.to_zone,''))='PWL1'),('DTG','DTG_PUTWALL_OUT','garments',upper(coalesce(a.from_zone,''))='PWL1'),('UP','UP_IN','garments',upper(coalesce(a.to_location,''))like'%UNDERPRINT%'),('UP','UP_OUT','garments',upper(coalesce(a.from_location,''))like'%UNDERPRINT%'and upper(coalesce(a.to_location,''))not like'%UNDERPRINT%'))v(area,metric,unit,accepted)where accepted)m
 left join lateral(select s.*from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone'Australia/Brisbane')::date and(s.effective_to is null or s.effective_to>=(a.event_at at time zone'Australia/Brisbane')::date)and s.weekday=extract(isodow from case when s.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end)and(case when s.cross_midnight then(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time or(a.event_at at time zone'Australia/Brisbane')::time<s.end_time else(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time end)order by s.effective_from desc limit 1)r on true
 where a.organization_id=p_organization_id and a.production_units>0 and a.raw_hash in(select event->>'rawHash'from jsonb_array_elements(p_events)event)on conflict do nothing;get diagnostics v_inserted=row_count;return v_inserted;end$function$
;

-- public.ingest_sync_batch(payload jsonb)
CREATE OR REPLACE FUNCTION public.ingest_sync_batch(payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET statement_timeout TO '120s'
AS $function$
declare batch_id uuid;audit_count integer;v_organization_id uuid:=(payload->>'organizationId')::uuid;
begin perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text,0));insert into sync_batches(organization_id,status,connector_version)values(v_organization_id,'running',payload->>'connectorVersion')returning id into batch_id;
 begin truncate table source_release_order_lines,source_orders,source_workbank_items,source_stock_items;
 insert into source_orders(organization_id,sync_batch_id,order_no,date_received,date_due,date_released,source_status,source_sub_status,customer_code,customer_name,ship_to_name,customer_state,city,delivery_desc,client_so_number,source_priority,site,route_id,cost_centre,stop_ship_flag,release_source_status,source_updated_at)
 select v_organization_id,batch_id,x."orderNo",x."dateReceived",x."dateDue",x."dateReleased",x."sourceStatus",x."sourceSubStatus",x."customerCode",x."customerName",x."shipToName",x."customerState",x.city,x."deliveryDesc",x."clientSoNumber",x."sourcePriority",x.site,x."routeId",x."costCentre",x."stopShipFlag",x."releaseSourceStatus",x."sourceUpdatedAt" from jsonb_to_recordset(payload->'orders')x("orderNo" text,"dateReceived" timestamptz,"dateDue" timestamptz,"dateReleased" timestamptz,"sourceStatus" text,"sourceSubStatus" text,"customerCode" text,"customerName" text,"shipToName" text,"customerState" text,city text,"deliveryDesc" text,"clientSoNumber" text,"sourcePriority" integer,site text,"routeId" text,"costCentre" text,"stopShipFlag" text,"releaseSourceStatus" text,"sourceUpdatedAt" timestamptz);
 insert into source_release_order_lines(organization_id,sync_batch_id,order_no,line_number,product,client,qty_lcd,orig_ref3,group_code,product_name,source_updated_at)select v_organization_id,batch_id,x."orderNo",x."lineNumber",x.product,x.client,x."qtyLcd",x."origRef3",x."groupCode",x."productName",x."sourceUpdatedAt" from jsonb_to_recordset(coalesce(payload->'releaseOrderLines','[]'::jsonb))x("orderNo" text,"lineNumber" text,product text,client text,"qtyLcd" numeric,"origRef3" text,"groupCode" text,"productName" text,"sourceUpdatedAt" timestamptz);
 insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,customer_code,customer_name,source_due_at,from_location,from_zone,to_location,from_pack_id,to_pack_id,source_priority,product_code,product_description,product_group,source_qty,source_weight,production_units,prints_per_garment,queue,task)select v_organization_id,batch_id,x.* from jsonb_to_recordset(payload->'workbank')x("sourceRowId" text,"orderNo" text,"customerCode" text,"customerName" text,"sourceDueAt" timestamptz,"fromLocation" text,"fromZone" text,"toLocation" text,"fromPackId" text,"toPackId" text,"sourcePriority" integer,"productCode" text,"productDescription" text,"productGroup" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"printsPerGarment" numeric,queue text,task text);
 insert into source_stock_items(organization_id,sync_batch_id,product,pack_id,location,source_zone,source_timestamp,source_qty,source_weight,production_units)select v_organization_id,batch_id,x.* from jsonb_to_recordset(payload->'stock')x(product text,"packId" text,location text,"sourceZone" text,"sourceTimestamp" timestamptz,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric);
 insert into source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash)select v_organization_id,x.* from jsonb_to_recordset(payload->'auditEvents')x("sourceAuditId" text,"orderNo" text,username text,"fromZone" text,"toZone" text,"fromLocation" text,"toLocation" text,product text,"fromPackId" text,"toPackId" text,"sourceQty" numeric,"sourceWeight" numeric,"productionUnits" numeric,"eventAt" timestamptz,"rawHash" text)on conflict do nothing;get diagnostics audit_count=row_count;
 update sync_batches set status='completed',completed_at=now(),orders_count=jsonb_array_length(payload->'orders'),release_line_count=jsonb_array_length(coalesce(payload->'releaseOrderLines','[]'::jsonb)),workbank_count=jsonb_array_length(payload->'workbank'),stock_count=jsonb_array_length(payload->'stock'),audit_new_count=audit_count where id=batch_id;
 delete from sync_batches b where b.organization_id=v_organization_id and b.id<>batch_id and b.id not in(select k.id from sync_batches k where k.organization_id=v_organization_id order by k.created_at desc limit 99);
 exception when others then update sync_batches set status='failed',error_message=left(sqlerrm,1000)where id=batch_id;raise;end;return batch_id;end $function$
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
AS $function$
declare row_data jsonb;org uuid;eid uuid;
begin
 row_data:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 org:=(row_data->>'organization_id')::uuid;
 eid:=nullif(row_data->>'id','')::uuid;
 insert into maintenance_audit_log(organization_id,user_id,entity_type,entity_id,action,old_values,new_values)
 values(org,auth.uid(),tg_table_name,eid,tg_op,
   case when tg_op in('UPDATE','DELETE')then to_jsonb(old)end,
   case when tg_op in('INSERT','UPDATE')then to_jsonb(new)end);
 return case when tg_op='DELETE'then old else new end;
end $function$
;

-- public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)
CREATE OR REPLACE FUNCTION public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p text;c uuid;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select prefix,category_id into p,c from maintenance_asset_prefixes where id=p_prefix_id and organization_id=p_organization_id and active for share;if p is null then raise exception'Invalid prefix';end if;insert into maintenance_asset_code_sequences values(p_organization_id,p,0,now())on conflict do nothing;update maintenance_asset_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and prefix=p returning last_number into n;if n>999 then raise exception'Sequence exhausted';end if;code:=p||'-'||lpad(n::text,3,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,category_id,prefix_id,location,manufacturer,model,serial_number,description,criticality,status,installation_date,purchase_date,purchase_cost,warranty_expiry,installed_at,created_by)values(p_organization_id,code,p_name,p_name,c,p_prefix_id,nullif(trim(p_location),''),nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,p_purchase_date,p_purchase_cost,p_warranty_expiry,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
;

-- public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)
CREATE OR REPLACE FUNCTION public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pc text;p text;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select asset_code into pc from maintenance_assets where id=p_parent_asset_id and organization_id=p_organization_id and active for share;select prefix into p from maintenance_component_prefixes where id=p_component_prefix_id and organization_id=p_organization_id and active for share;if pc is null or p is null then raise exception'Invalid parent or prefix';end if;insert into maintenance_component_code_sequences values(p_organization_id,p_parent_asset_id,p,0,now())on conflict do nothing;update maintenance_component_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and parent_asset_id=p_parent_asset_id and component_prefix=p returning last_number into n;if n>99 then raise exception'Sequence exhausted';end if;code:=pc||'-'||p||'-'||lpad(n::text,2,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,manufacturer,model,serial_number,description,criticality,status,installation_date,installed_at,created_by)values(p_organization_id,code,p_name,p_name,p_parent_asset_id,nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
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
AS $function$declare v_id uuid;q numeric;available numeric;begin if p_quantity<=0 then raise exception'Quantity must be positive';end if;if not exists(select 1 from maintenance_parts where id=p_part_id and organization_id=p_organization_id and active)or not exists(select 1 from maintenance_inventory_locations where id=p_location_id and organization_id=p_organization_id and active)then raise exception'Invalid inventory reference';end if;q:=case when p_type='issue'then-p_quantity else p_quantity end;if p_type='issue'then select coalesce(sum(quantity),0)into available from maintenance_inventory_transactions where part_id=p_part_id and location_id=p_location_id;if available<p_quantity then raise exception'Insufficient stock';end if;end if;insert into maintenance_inventory_transactions(organization_id,part_id,location_id,work_order_id,transaction_type,quantity,unit_cost_snapshot,notes,created_by,created_by_email)values(p_organization_id,p_part_id,p_location_id,p_work_order_id,p_type,q,p_unit_cost,p_notes,p_actor_id,p_actor_email)returning id into v_id;return v_id;end$function$
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

-- public.oid_dist(oid, oid)
CREATE OR REPLACE FUNCTION public.oid_dist(oid, oid)
 RETURNS oid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/btree_gist', $function$oid_dist$function$
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

-- public.resolve_production_date(p_event_at timestamp with time zone, p_starts_at time without time zone, p_ends_at time without time zone, p_timezone text)
CREATE OR REPLACE FUNCTION public.resolve_production_date(p_event_at timestamp with time zone, p_starts_at time without time zone, p_ends_at time without time zone, p_timezone text DEFAULT 'Australia/Brisbane'::text)
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
AS $function$select case when p_ends_at<=p_starts_at and(p_event_at at time zone p_timezone)::time<p_ends_at then(p_event_at at time zone p_timezone)::date-1 else(p_event_at at time zone p_timezone)::date end$function$
;

-- public.rls_auto_enable()
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
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

