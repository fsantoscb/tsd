create table public."operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "operation_type" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "operations_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "operations_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "operations_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "operations_pkey" PRIMARY KEY (id)
);
alter table public."operations" enable row level security;
create policy "operations_manage" on public."operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "operations_read" on public."operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active))));
CREATE TRIGGER protect_active_operation_deactivation_change BEFORE UPDATE OF active ON operations FOR EACH ROW EXECUTE FUNCTION protect_active_operation_deactivation();

