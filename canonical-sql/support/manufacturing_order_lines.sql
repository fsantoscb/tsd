create table public."manufacturing_order_lines" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "manufacturing_order_id" uuid not null,
  "production_demand_line_id" uuid,
  "source_order_no" text not null,
  "source_order_line_id" text not null,
  "product_id" uuid,
  "routing_revision_id" uuid not null,
  "planned_quantity" numeric not null,
  "actual_quantity" numeric default 0 not null,
  "sequence" integer,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "manufacturing_order_lines_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "manufacturing_order_lines_manufacturing_order_id_source_ord_key" UNIQUE (manufacturing_order_id, source_order_line_id),
  constraint "manufacturing_order_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "manufacturing_order_lines_organization_id_manufacturing_or_fkey" FOREIGN KEY (organization_id, manufacturing_order_id) REFERENCES production_orders(organization_id, id) ON DELETE RESTRICT,
  constraint "manufacturing_order_lines_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id),
  constraint "manufacturing_order_lines_organization_id_production_deman_fkey" FOREIGN KEY (organization_id, production_demand_line_id) REFERENCES production_demand_lines(organization_id, id),
  constraint "manufacturing_order_lines_organization_id_routing_revision_fkey" FOREIGN KEY (organization_id, routing_revision_id) REFERENCES routings(organization_id, id),
  constraint "manufacturing_order_lines_pkey" PRIMARY KEY (id),
  constraint "manufacturing_order_lines_planned_quantity_check" CHECK (planned_quantity > 0::numeric),
  constraint "manufacturing_order_lines_production_demand_line_id_key" UNIQUE (production_demand_line_id)
);
alter table public."manufacturing_order_lines" enable row level security;
create policy "manufacturing_order_lines_manage" on public."manufacturing_order_lines" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "manufacturing_order_lines_read" on public."manufacturing_order_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active))));
CREATE TRIGGER enforce_manufacturing_order_line_boundary_change BEFORE INSERT OR UPDATE ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION enforce_manufacturing_order_line_boundary();
CREATE TRIGGER manufacturing_order_lines_audit AFTER INSERT OR DELETE OR UPDATE ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER recalculate_manufacturing_order_actual_change AFTER UPDATE OF actual_quantity ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION recalculate_manufacturing_order_actual();
CREATE TRIGGER recalculate_manufacturing_order_quantity_change AFTER INSERT OR DELETE OR UPDATE OF planned_quantity ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION recalculate_manufacturing_order_quantity();

