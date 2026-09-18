create table public."production_process_stages" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_process_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "sequence" integer not null,
  "source_type" text not null,
  "capacity_area_code" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_process_stages_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_process_stages_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_process_stages_pkey" PRIMARY KEY (id),
  constraint "production_process_stages_production_process_id_fkey" FOREIGN KEY (production_process_id) REFERENCES production_processes(id),
  constraint "production_process_stages_source_type_check" CHECK (source_type = ANY (ARRAY['oracle_workbank'::text, 'oracle_stock'::text, 'oracle_location'::text, 'oracle_audit'::text, 'manual'::text]))
);
CREATE INDEX process_stage_org_idx ON public.production_process_stages USING btree (organization_id, production_process_id, sequence);
alter table public."production_process_stages" enable row level security;

