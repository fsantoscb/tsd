create table public."production_resources" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_center_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "resource_type" text,
  "asset_id" uuid,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_resources_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id),
  constraint "production_resources_code_check" CHECK (code ~ '^[A-Z0-9_-]+$'::text),
  constraint "production_resources_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_resources_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_resources_organization_id_work_center_id_fkey" FOREIGN KEY (organization_id, work_center_id) REFERENCES work_centers(organization_id, id),
  constraint "production_resources_pkey" PRIMARY KEY (id)
);
CREATE INDEX production_resources_center_idx ON public.production_resources USING btree (organization_id, work_center_id);
alter table public."production_resources" enable row level security;
create policy "production_resources_manage" on public."production_resources" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_resources_read" on public."production_resources" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active))));
CREATE TRIGGER production_resource_asset_organization BEFORE INSERT OR UPDATE OF asset_id, organization_id ON production_resources FOR EACH ROW EXECUTE FUNCTION enforce_production_resource_asset_organization();

