create table public."product_source_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_product_code" text not null,
  "product_id" uuid not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "mapping_method" text default 'LEGACY'::text not null,
  "confidence" text default 'UNRESOLVED'::text not null,
  "confirmed_at" timestamp with time zone,
  "confirmed_by" uuid,
  "notes" text,
  "source_ingestion_run_id" uuid,
  constraint "product_source_mappings_confidence_check" CHECK (confidence = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text, 'MANUAL_CONFIRMED'::text, 'AMBIGUOUS'::text, 'UNRESOLVED'::text])),
  constraint "product_source_mappings_mapping_method_check" CHECK (mapping_method = ANY (ARRAY['LEGACY'::text, 'SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text, 'MANUAL_CONFIRMED'::text])),
  constraint "product_source_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "product_source_mappings_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id),
  constraint "product_source_mappings_organization_id_source_system_sourc_key" UNIQUE (organization_id, source_system, source_product_code),
  constraint "product_source_mappings_pkey" PRIMARY KEY (id),
  constraint "product_source_mappings_source_ingestion_run_id_fkey" FOREIGN KEY (source_ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id)
);
alter table public."product_source_mappings" enable row level security;
create policy "product_source_mappings_manage" on public."product_source_mappings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_source_mappings_read" on public."product_source_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active))));

