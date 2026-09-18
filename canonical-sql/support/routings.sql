create table public."routings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "revision" integer default 1 not null,
  "status" text default 'DRAFT'::text not null,
  "effective_from" date,
  "effective_to" date,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "routings_check" CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
  constraint "routings_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "routings_organization_id_code_revision_key" UNIQUE (organization_id, code, revision),
  constraint "routings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "routings_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "routings_pkey" PRIMARY KEY (id),
  constraint "routings_revision_check" CHECK (revision > 0),
  constraint "routings_status_check" CHECK (status = ANY (ARRAY['DRAFT'::text, 'ACTIVE'::text, 'INACTIVE'::text]))
);
alter table public."routings" enable row level security;
create policy "routings_manage" on public."routings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "routings_read" on public."routings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active))));
CREATE TRIGGER protect_routing_revision_change BEFORE DELETE OR UPDATE ON routings FOR EACH ROW EXECUTE FUNCTION protect_routing_revision();
CREATE TRIGGER routing_master_audit_change AFTER INSERT OR DELETE OR UPDATE ON routings FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

