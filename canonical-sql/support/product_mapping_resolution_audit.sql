create table public."product_mapping_resolution_audit" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_product_code" text not null,
  "product_id" uuid,
  "action" text not null,
  "confidence" text not null,
  "rule" text not null,
  "source_ingestion_run_id" uuid,
  "created_at" timestamp with time zone default now() not null,
  constraint "product_mapping_resolution_audit_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "product_mapping_resolution_audit_pkey" PRIMARY KEY (id),
  constraint "product_mapping_resolution_audit_source_ingestion_run_id_fkey" FOREIGN KEY (source_ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id)
);
alter table public."product_mapping_resolution_audit" enable row level security;
create policy "product_mapping_resolution_audit_read" on public."product_mapping_resolution_audit" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_mapping_resolution_audit.organization_id) AND m.active))));

