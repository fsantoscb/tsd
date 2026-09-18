create table public."production_order_operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_order_id" uuid not null,
  "source_routing_operation_id" uuid,
  "source_operation_id" uuid,
  "sequence" integer not null,
  "operation_code_snapshot" text not null,
  "operation_name_snapshot" text not null,
  "work_center_code_snapshot" text,
  "work_center_name_snapshot" text,
  "required" boolean default true not null,
  "setup_minutes_snapshot" numeric,
  "run_rate_snapshot" numeric,
  "queue_minutes_snapshot" numeric,
  "instructions_snapshot" text,
  "status" text default 'PENDING'::text not null,
  "planned_quantity" numeric,
  "actual_quantity" numeric default 0 not null,
  "planned_date" date,
  "planned_shift_id" uuid,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "validation_provenance" text default 'NOT_OBSERVED'::text not null,
  "validation_note" text,
  constraint "production_order_operations_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "production_order_operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_order_operations_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_order_operations_organization_id_production_ord_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE,
  constraint "production_order_operations_pkey" PRIMARY KEY (id),
  constraint "production_order_operations_planned_quantity_check" CHECK (planned_quantity IS NULL OR planned_quantity > 0::numeric),
  constraint "production_order_operations_planned_shift_id_fkey" FOREIGN KEY (planned_shift_id) REFERENCES shift_templates(id),
  constraint "production_order_operations_production_order_id_sequence_key" UNIQUE (production_order_id, sequence),
  constraint "production_order_operations_sequence_check" CHECK (sequence > 0),
  constraint "production_order_operations_status_check" CHECK (status = ANY (ARRAY['PENDING'::text, 'READY'::text, 'IN_PROGRESS'::text, 'ON_HOLD'::text, 'COMPLETED'::text, 'SKIPPED'::text])),
  constraint "production_order_operations_validation_provenance_check" CHECK (validation_provenance = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'INFERRED'::text, 'NOT_OBSERVED'::text]))
);
CREATE INDEX production_order_operations_progress_idx ON public.production_order_operations USING btree (organization_id, production_order_id, sequence, status);
alter table public."production_order_operations" enable row level security;
create policy "production_order_operations_execute" on public."production_order_operations" as PERMISSIVE for UPDATE to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text)))));
create policy "production_order_operations_manage" on public."production_order_operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_order_operations_read" on public."production_order_operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active))));
CREATE TRIGGER production_order_operations_audit AFTER INSERT OR DELETE OR UPDATE ON production_order_operations FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER protect_production_operation_snapshot_change BEFORE DELETE OR UPDATE ON production_order_operations FOR EACH ROW EXECUTE FUNCTION protect_production_operation_snapshot();

