create table public."source_operational_code_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_field" text not null,
  "source_operational_code" text not null,
  "manufacturing_process" text,
  "operational_stage" text,
  "release_status" text,
  "eligibility_status" text,
  "blocker_reason" text,
  "mo_scope" text not null,
  "confidence" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_operational_code_mappi_organization_id_source_system_key" UNIQUE (organization_id, source_system, source_dataset, source_field, source_operational_code),
  constraint "source_operational_code_mappings_confidence_check" CHECK (confidence = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text])),
  constraint "source_operational_code_mappings_mo_scope_check" CHECK (mo_scope = ANY (ARRAY['CURRENT_SUPPORTED_PROCESS'::text, 'PROCESS_NOT_YET_SUPPORTED'::text, 'NO_MO_REQUIRED'::text, 'NOT_APPLICABLE'::text])),
  constraint "source_operational_code_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "source_operational_code_mappings_pkey" PRIMARY KEY (id),
  constraint "source_operational_code_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['WORKBANK'::text, 'AUDIT'::text])),
  constraint "source_operational_code_mappings_source_field_check" CHECK (source_field = ANY (ARRAY['queue'::text, 'from_location'::text, 'to_location'::text]))
);
alter table public."source_operational_code_mappings" enable row level security;
create policy "source_operational_codes_read" on public."source_operational_code_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.organization_id = source_operational_code_mappings.organization_id) AND (m.user_id = auth.uid()) AND m.active))));

