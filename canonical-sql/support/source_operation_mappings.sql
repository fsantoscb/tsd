create table public."source_operation_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_field" text not null,
  "match_type" text not null,
  "match_value" text not null,
  "operation_id" uuid not null,
  "completion_semantics" text not null,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_operation_mappings_completion_semantics_check" CHECK (completion_semantics = ANY (ARRAY['CURRENT_LOCATION'::text, 'ENTERED_OPERATION'::text, 'COMPLETED_OPERATION'::text, 'MOVED_FROM_OPERATION'::text, 'MOVED_TO_OPERATION'::text])),
  constraint "source_operation_mappings_match_type_check" CHECK (match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text])),
  constraint "source_operation_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "source_operation_mappings_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id),
  constraint "source_operation_mappings_organization_id_source_system_sou_key" UNIQUE (organization_id, source_system, source_dataset, source_field, match_type, match_value, completion_semantics),
  constraint "source_operation_mappings_pkey" PRIMARY KEY (id),
  constraint "source_operation_mappings_priority_check" CHECK (priority >= 0),
  constraint "source_operation_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['AUDIT'::text, 'WORKBANK'::text, 'STOCK'::text]))
);
CREATE INDEX source_operation_mappings_lookup_idx ON public.source_operation_mappings USING btree (organization_id, source_dataset, source_field, priority) WHERE active;
alter table public."source_operation_mappings" enable row level security;
create policy "source_operation_mappings_manage" on public."source_operation_mappings" as PERMISSIVE for ALL to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "source_operation_mappings_read" on public."source_operation_mappings" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active))));
CREATE TRIGGER source_operation_mappings_audit AFTER INSERT OR DELETE OR UPDATE ON source_operation_mappings FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

