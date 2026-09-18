create table public."product_types" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "product_types_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "product_types_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "product_types_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "product_types_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "product_types_pkey" PRIMARY KEY (id)
);
alter table public."product_types" enable row level security;
create policy "product_types_manage" on public."product_types" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_types_read" on public."product_types" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active))));

