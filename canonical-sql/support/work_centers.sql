create table public."work_centers" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "work_centers_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "work_centers_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "work_centers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "work_centers_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "work_centers_pkey" PRIMARY KEY (id)
);
alter table public."work_centers" enable row level security;
create policy "work_centers_manage" on public."work_centers" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "work_centers_read" on public."work_centers" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active))));

