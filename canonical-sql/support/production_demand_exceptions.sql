create table public."production_demand_exceptions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_demand_line_id" uuid not null,
  "exception_type" text not null,
  "description" text not null,
  "status" text default 'OPEN'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "resolved_at" timestamp with time zone,
  constraint "production_demand_exceptions_exception_type_check" CHECK (exception_type = ANY (ARRAY['PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'ROUTING_INACTIVE'::text, 'INVALID_QUANTITY'::text])),
  constraint "production_demand_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_demand_exceptions_organization_id_production_de_fkey" FOREIGN KEY (organization_id, production_demand_line_id) REFERENCES production_demand_lines(organization_id, id) ON DELETE CASCADE,
  constraint "production_demand_exceptions_pkey" PRIMARY KEY (id),
  constraint "production_demand_exceptions_production_demand_line_id_exce_key" UNIQUE (production_demand_line_id, exception_type, status),
  constraint "production_demand_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'RESOLVED'::text, 'DISMISSED'::text]))
);
alter table public."production_demand_exceptions" enable row level security;
create policy "production_demand_exceptions_manage" on public."production_demand_exceptions" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_demand_exceptions_read" on public."production_demand_exceptions" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active))));
CREATE TRIGGER production_demand_exceptions_audit AFTER INSERT OR DELETE OR UPDATE ON production_demand_exceptions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

