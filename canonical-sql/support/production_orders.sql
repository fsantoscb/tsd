create table public."production_orders" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "order_no" text not null,
  "planner_priority" integer,
  "planned_date" date,
  "planned_shift_id" uuid,
  "planning_status" text default 'unplanned'::text not null,
  "special_instruction" text,
  "planner_note" text,
  "blocked_reason" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "updated_by" uuid,
  "product_id" uuid,
  "source_order_no" text,
  "source_routing_id" uuid,
  "routing_code_snapshot" text,
  "routing_name_snapshot" text,
  "routing_revision_snapshot" integer,
  "production_status" text default 'UNROUTED'::text not null,
  "planned_quantity" numeric,
  "actual_quantity" numeric default 0 not null,
  "mo_number" text,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "split_number" integer default 1 not null,
  constraint "production_orders_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "production_orders_check" CHECK (planning_status = 'blocked'::text OR blocked_reason IS NULL),
  constraint "production_orders_check1" CHECK (planning_status <> 'blocked'::text OR NULLIF(TRIM(BOTH FROM blocked_reason), ''::text) IS NOT NULL),
  constraint "production_orders_mo_identity_check" CHECK (source_routing_id IS NULL OR NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL),
  constraint "production_orders_mo_number_key" UNIQUE (organization_id, mo_number),
  constraint "production_orders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_orders_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_orders_pkey" PRIMARY KEY (id),
  constraint "production_orders_planned_quantity_check" CHECK (planned_quantity IS NULL OR planned_quantity >= 0::numeric),
  constraint "production_orders_planned_shift_id_fkey" FOREIGN KEY (planned_shift_id) REFERENCES shift_templates(id),
  constraint "production_orders_planner_priority_check" CHECK (planner_priority >= 0 AND planner_priority <= 999),
  constraint "production_orders_planning_status_check" CHECK (planning_status = ANY (ARRAY['unplanned'::text, 'planned'::text, 'ready'::text, 'in_progress'::text, 'blocked'::text, 'waiting'::text, 'completed'::text, 'cancelled'::text])),
  constraint "production_orders_product_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id),
  constraint "production_orders_snapshot_complete_check" CHECK (source_routing_id IS NULL AND routing_code_snapshot IS NULL AND routing_name_snapshot IS NULL AND routing_revision_snapshot IS NULL AND production_status = 'UNROUTED'::text OR source_routing_id IS NOT NULL AND routing_code_snapshot IS NOT NULL AND routing_name_snapshot IS NOT NULL AND routing_revision_snapshot IS NOT NULL AND production_status <> 'UNROUTED'::text),
  constraint "production_orders_so_routing_split_key" UNIQUE (organization_id, source_system, source_order_no, source_routing_id, split_number),
  constraint "production_orders_split_number_check" CHECK (split_number > 0),
  constraint "production_orders_status_check" CHECK (production_status = ANY (ARRAY['UNROUTED'::text, 'PLANNED'::text, 'RELEASED'::text, 'IN_PROGRESS'::text, 'ON_HOLD'::text, 'COMPLETED'::text, 'CANCELLED'::text]))
);
CREATE INDEX production_orders_execution_idx ON public.production_orders USING btree (organization_id, production_status, planned_date, planner_priority);
alter table public."production_orders" enable row level security;
create policy "production_orders_execution_manage" on public."production_orders" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_orders_execution_read" on public."production_orders" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active))));
CREATE TRIGGER copy_production_order_operations_change AFTER INSERT OR UPDATE OF product_id, source_routing_id ON production_orders FOR EACH ROW EXECUTE FUNCTION copy_production_order_operations();
CREATE TRIGGER prepare_production_order_snapshot_change BEFORE INSERT OR UPDATE OF product_id, source_routing_id ON production_orders FOR EACH ROW EXECUTE FUNCTION prepare_production_order_snapshot();
CREATE TRIGGER production_orders_execution_audit AFTER INSERT OR DELETE OR UPDATE ON production_orders FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

