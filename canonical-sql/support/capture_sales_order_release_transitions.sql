CREATE OR REPLACE FUNCTION public.capture_sales_order_release_transitions(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin insert into sales_order_release_history(organization_id,source_order_no,previous_release_status,new_release_status,eligibility_snapshot,blockers_snapshot,source_status_snapshot,source_sync_batch_id)select q.organization_id,q.source_order_no,h.new_release_status,q.release_status,q.release_eligibility,to_jsonb(q.release_blockers),jsonb_build_object('status',q.source_status,'date_released',q.date_released),q.sync_batch_id from v_release_queue q left join lateral(select new_release_status from sales_order_release_history x where x.organization_id=q.organization_id and x.source_order_no=q.source_order_no order by changed_at desc limit 1)h on true where q.organization_id=p_organization_id and h.new_release_status is distinct from q.release_status on conflict do nothing;get diagnostics n=row_count;return n;end$function$
;

