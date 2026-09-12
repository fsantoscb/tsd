alter table maintenance_preventive_plans add column if not exists requires_downtime boolean not null default false;
alter table maintenance_work_orders add column if not exists no_parts_used_confirmed boolean not null default false;
alter table maintenance_work_orders add column if not exists no_parts_used_confirmed_at timestamptz;
alter table maintenance_work_orders add column if not exists no_parts_used_confirmed_by uuid;
alter table maintenance_work_orders add column if not exists source_pm_work_order_id uuid references maintenance_work_orders(id);
alter table maintenance_work_orders add column if not exists request_flow text check(request_flow in('operator_fix','maintenance_required','maintenance_request'));
create index if not exists maintenance_wo_source_pm_idx on maintenance_work_orders(source_pm_work_order_id) where source_pm_work_order_id is not null;

create or replace function maintenance_operator_pm_action(p_organization_id uuid,p_work_order_id uuid,p_action text,p_checklist_id uuid,p_completed boolean,p_no_parts_used boolean,p_resolution text,p_actor_id uuid,p_actor_email text)returns void language plpgsql security definer set search_path=public as $$
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
end$$;
revoke all on function maintenance_operator_pm_action(uuid,uuid,text,uuid,boolean,boolean,text,uuid,text)from public,anon,authenticated;
grant execute on function maintenance_operator_pm_action(uuid,uuid,text,uuid,boolean,boolean,text,uuid,text)to service_role;
