create table public."source_task_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_task" text not null,
  "production_process_id" uuid not null,
  "operation_id" uuid,
  "match_type" text default 'EXACT'::text not null,
  "context_field" text,
  "context_match_type" text,
  "context_value" text,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_task_mappings_check" CHECK (context_field IS NULL AND context_match_type IS NULL AND context_value IS NULL OR context_field IS NOT NULL AND context_match_type IS NOT NULL AND context_value IS NOT NULL),
  constraint "source_task_mappings_context_field_check" CHECK (context_field IS NULL OR (context_field = ANY (ARRAY['queue'::text, 'from_zone'::text, 'to_zone'::text, 'from_location'::text, 'to_location'::text]))),
  constraint "source_task_mappings_context_match_type_check" CHECK (context_match_type IS NULL OR (context_match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text]))),
  constraint "source_task_mappings_match_type_check" CHECK (match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text])),
  constraint "source_task_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "source_task_mappings_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id),
  constraint "source_task_mappings_organization_id_production_process_id_fkey" FOREIGN KEY (organization_id, production_process_id) REFERENCES production_processes(organization_id, id),
  constraint "source_task_mappings_pkey" PRIMARY KEY (id),
  constraint "source_task_mappings_priority_check" CHECK (priority >= 0),
  constraint "source_task_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['WORKBANK'::text, 'AUDIT'::text]))
);
CREATE UNIQUE INDEX source_task_mappings_identity ON public.source_task_mappings USING btree (organization_id, source_system, source_dataset, source_task, match_type, COALESCE(context_field, ''::text), COALESCE(context_match_type, ''::text), COALESCE(context_value, ''::text));
alter table public."source_task_mappings" enable row level security;
create policy "source_task_mappings_manage" on public."source_task_mappings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "source_task_mappings_read" on public."source_task_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active))));

