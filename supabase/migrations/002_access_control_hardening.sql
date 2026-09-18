begin;

alter table public.maintenance_members drop constraint if exists maintenance_members_role_check;
alter table public.maintenance_members add constraint maintenance_members_role_check
  check (role = any (array['admin','manager','maintenance','supervisor','operator','viewer']::text[]));

create or replace function public.has_org_role(p_organization_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.maintenance_members m
    where m.user_id = auth.uid()
      and m.organization_id = p_organization_id
      and m.active
      and m.role = any (p_roles)
  );
$$;

revoke all on function public.has_org_role(uuid,text[]) from public, anon;
grant execute on function public.has_org_role(uuid,text[]) to authenticated, service_role;

-- Policies accidentally declared for public are membership-protected, but their
-- role target must still be authenticated to eliminate unintended exposure.
alter policy production_order_operation_evidence_read on public.production_order_operation_evidence to authenticated;
alter policy production_reconciliation_items_read on public.production_reconciliation_items to authenticated;
alter policy production_reconciliation_runs_read on public.production_reconciliation_runs to authenticated;
alter policy production_routing_exceptions_manage on public.production_routing_exceptions to authenticated;
alter policy production_routing_exceptions_read on public.production_routing_exceptions to authenticated;
alter policy source_operation_mappings_manage on public.source_operation_mappings to authenticated;
alter policy source_operation_mappings_read on public.source_operation_mappings to authenticated;

-- Derived canonical demand is service-owned, never directly maintained by users.
drop policy if exists manufacturing_order_lines_manage on public.manufacturing_order_lines;
drop policy if exists production_demand_lines_manage on public.production_demand_lines;

-- Execution operations are available to operational roles; structural edits are
-- reserved for management and administration.
alter policy production_order_operations_execute on public.production_order_operations
  using (public.has_org_role(organization_id,array['operator','supervisor','manager','admin']))
  with check (public.has_org_role(organization_id,array['operator','supervisor','manager','admin']));
alter policy production_order_operations_manage on public.production_order_operations
  using (public.has_org_role(organization_id,array['manager','admin']))
  with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy production_orders_execution_manage on public.production_orders
  using (public.has_org_role(organization_id,array['supervisor','manager','admin']))
  with check (public.has_org_role(organization_id,array['supervisor','manager','admin']));
alter policy production_demand_exceptions_manage on public.production_demand_exceptions
  using (public.has_org_role(organization_id,array['supervisor','manager','admin']))
  with check (public.has_org_role(organization_id,array['supervisor','manager','admin']));
alter policy production_routing_exceptions_manage on public.production_routing_exceptions
  using (public.has_org_role(organization_id,array['supervisor','manager','admin']))
  with check (public.has_org_role(organization_id,array['supervisor','manager','admin']));

-- Canonical configuration is manager/admin only.
alter policy operations_manage on public.operations using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy product_families_manage on public.product_families using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy product_routing_assignments_manage on public.product_routing_assignments using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy product_source_mappings_manage on public.product_source_mappings using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy product_types_manage on public.product_types using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy production_resources_manage on public.production_resources using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy products_manage on public.products using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy routing_operations_manage on public.routing_operations using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy routings_manage on public.routings using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy source_operation_mappings_manage on public.source_operation_mappings using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy source_task_mappings_manage on public.source_task_mappings using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));
alter policy work_centers_manage on public.work_centers using (public.has_org_role(organization_id,array['manager','admin'])) with check (public.has_org_role(organization_id,array['manager','admin']));

-- Imported authority, immutable history, and synchronization state are service-only for writes.
revoke insert, update, delete on public.source_orders, public.source_release_order_lines,
  public.source_order_release_lines, public.source_workbank_items, public.source_stock_items,
  public.source_audit_events, public.sync_batches, public.sync_runs,
  public.sync_agent_heartbeat, public.production_demand_lines,
  public.production_demand_release_events, public.manufacturing_order_lines,
  public.production_order_operation_evidence, public.production_order_history,
  public.sales_order_release_history, public.product_mapping_resolution_audit
from authenticated;

-- Anonymous users have no direct operational schema privileges.
revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from anon;

commit;
