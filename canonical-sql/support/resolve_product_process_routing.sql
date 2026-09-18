CREATE OR REPLACE FUNCTION public.resolve_product_process_routing(p_organization_id uuid, p_product_id uuid, p_process_code text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce((select a.routing_id from product_routing_assignments a join routings r on r.id=a.routing_id and r.organization_id=a.organization_id where a.organization_id=p_organization_id and a.product_id=p_product_id and a.process_code=p_process_code and a.approved and r.active and r.status='ACTIVE'and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date)limit 1),(select r.id from routings r where r.id=p_order_line_override and r.organization_id=p_organization_id and r.active and r.status='ACTIVE'limit 1),(select p.default_routing_id from products p join routings r on r.id=p.default_routing_id and r.organization_id=p.organization_id where p.id=p_product_id and p.organization_id=p_organization_id and r.active and r.status='ACTIVE'and(select count(distinct a.routing_id)from product_routing_assignments a where a.organization_id=p_organization_id and a.product_id=p_product_id and a.approved)=1))$function$
;

