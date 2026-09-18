create table public."maintenance_audit_log" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "user_id" uuid,
  "entity_type" text not null,
  "entity_id" uuid,
  "action" text not null,
  "old_values" jsonb,
  "new_values" jsonb,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_audit_log_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "maintenance_audit_log_pkey" PRIMARY KEY (id)
);
CREATE INDEX maintenance_audit_entity_idx ON public.maintenance_audit_log USING btree (organization_id, entity_type, entity_id, created_at DESC);
alter table public."maintenance_audit_log" enable row level security;

