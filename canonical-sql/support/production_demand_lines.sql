create table public."production_demand_lines" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_order_no" text not null,
  "source_order_line_id" text not null,
  "product_id" uuid,
  "routing_id" uuid,
  "routing_revision_id" uuid,
  "source_product_code" text,
  "source_description" text,
  "quantity" numeric not null,
  "due_date" timestamp with time zone,
  "source_priority" integer,
  "planner_priority" integer,
  "status" text default 'READY'::text not null,
  "resolution_status" text default 'RESOLVED'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "production_process_code" text,
  "routing_override_id" uuid,
  constraint "production_demand_lines_check" CHECK (resolution_status = 'RESOLVED'::text AND product_id IS NOT NULL AND routing_revision_id IS NOT NULL OR resolution_status <> 'RESOLVED'::text),
  constraint "production_demand_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_demand_lines_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_demand_lines_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id),
  constraint "production_demand_lines_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id),
  constraint "production_demand_lines_organization_id_routing_revision_i_fkey" FOREIGN KEY (organization_id, routing_revision_id) REFERENCES routings(organization_id, id),
  constraint "production_demand_lines_organization_id_source_system_sourc_key" UNIQUE (organization_id, source_system, source_order_no, source_order_line_id),
  constraint "production_demand_lines_pkey" PRIMARY KEY (id),
  constraint "production_demand_lines_production_process_code_check" CHECK (production_process_code IS NULL OR (production_process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))),
  constraint "production_demand_lines_quantity_check" CHECK (quantity > 0::numeric),
  constraint "production_demand_lines_resolution_status_check" CHECK (resolution_status = ANY (ARRAY['RESOLVED'::text, 'PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'ROUTING_INACTIVE'::text, 'INVALID_QUANTITY'::text])),
  constraint "production_demand_lines_routing_identity_check" CHECK (resolution_status <> 'RESOLVED'::text OR routing_id IS NOT NULL AND routing_id = routing_revision_id),
  constraint "production_demand_lines_routing_override_fkey" FOREIGN KEY (organization_id, routing_override_id) REFERENCES routings(organization_id, id),
  constraint "production_demand_lines_source_order_line_id_check" CHECK (NULLIF(TRIM(BOTH FROM source_order_line_id), ''::text) IS NOT NULL),
  constraint "production_demand_lines_source_order_no_check" CHECK (NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL),
  constraint "production_demand_lines_status_check" CHECK (status = ANY (ARRAY['READY'::text, 'GROUPED'::text, 'CANCELLED'::text, 'EXCEPTION'::text]))
);
alter table public."production_demand_lines" enable row level security;
create policy "production_demand_lines_manage" on public."production_demand_lines" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_demand_lines_read" on public."production_demand_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active))));
CREATE TRIGGER production_demand_lines_audit AFTER INSERT OR DELETE OR UPDATE ON production_demand_lines FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

