create table public."product_routing_assignments" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "product_id" uuid not null,
  "process_code" text not null,
  "routing_id" uuid not null,
  "assignment_source" text default 'MANUAL'::text not null,
  "approved" boolean default false not null,
  "approved_by" uuid,
  "approved_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "product_routing_assignments_assignment_source_check" CHECK (assignment_source = ANY (ARRAY['DETERMINISTIC_SOURCE'::text, 'MANUAL'::text, 'IMPORT'::text])),
  constraint "product_routing_assignments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "product_routing_assignments_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id),
  constraint "product_routing_assignments_organization_id_product_id_proc_key" UNIQUE (organization_id, product_id, process_code),
  constraint "product_routing_assignments_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id),
  constraint "product_routing_assignments_pkey" PRIMARY KEY (id),
  constraint "product_routing_assignments_process_code_check" CHECK (process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))
);
alter table public."product_routing_assignments" enable row level security;
create policy "product_routing_assignments_manage" on public."product_routing_assignments" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_routing_assignments_read" on public."product_routing_assignments" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active))));

