create table public."routing_operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "routing_id" uuid not null,
  "sequence" integer not null,
  "operation_id" uuid not null,
  "work_center_id" uuid,
  "required" boolean default true not null,
  "setup_minutes" numeric,
  "run_rate" numeric,
  "queue_minutes" numeric,
  "capacity_profile_id" uuid,
  "instructions" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "routing_operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "routing_operations_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id),
  constraint "routing_operations_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id) ON DELETE CASCADE,
  constraint "routing_operations_organization_id_work_center_id_fkey" FOREIGN KEY (organization_id, work_center_id) REFERENCES work_centers(organization_id, id),
  constraint "routing_operations_pkey" PRIMARY KEY (id),
  constraint "routing_operations_queue_minutes_check" CHECK (queue_minutes IS NULL OR queue_minutes >= 0::numeric),
  constraint "routing_operations_routing_id_sequence_key" UNIQUE (routing_id, sequence),
  constraint "routing_operations_run_rate_check" CHECK (run_rate IS NULL OR run_rate > 0::numeric),
  constraint "routing_operations_sequence_check" CHECK (sequence > 0),
  constraint "routing_operations_setup_minutes_check" CHECK (setup_minutes IS NULL OR setup_minutes >= 0::numeric)
);
CREATE INDEX routing_operations_routing_idx ON public.routing_operations USING btree (organization_id, routing_id, sequence);
alter table public."routing_operations" enable row level security;
create policy "routing_operations_manage" on public."routing_operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "routing_operations_read" on public."routing_operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active))));
CREATE TRIGGER protect_routing_operation_change BEFORE INSERT OR DELETE OR UPDATE ON routing_operations FOR EACH ROW EXECUTE FUNCTION protect_routing_operation_change();
CREATE TRIGGER routing_operations_audit_change AFTER INSERT OR DELETE OR UPDATE ON routing_operations FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

