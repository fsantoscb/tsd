create table public."production_order_operation_evidence" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_order_id" uuid not null,
  "production_order_operation_id" uuid not null,
  "source_mapping_id" uuid not null,
  "source_dataset" text not null,
  "source_record_key" text not null,
  "source_audit_event_id" uuid,
  "semantics" text not null,
  "observed_at" timestamp with time zone not null,
  "quantity" numeric,
  "source_value" text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_order_operation_e_organization_id_production_o_fkey1" FOREIGN KEY (organization_id, production_order_operation_id) REFERENCES production_order_operations(organization_id, id) ON DELETE CASCADE,
  constraint "production_order_operation_ev_organization_id_production_o_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE,
  constraint "production_order_operation_ev_production_order_operation_id_key" UNIQUE (production_order_operation_id, source_dataset, source_record_key, source_mapping_id),
  constraint "production_order_operation_evidence_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_order_operation_evidence_pkey" PRIMARY KEY (id),
  constraint "production_order_operation_evidence_source_audit_event_id_fkey" FOREIGN KEY (source_audit_event_id) REFERENCES source_audit_events(id),
  constraint "production_order_operation_evidence_source_mapping_id_fkey" FOREIGN KEY (source_mapping_id) REFERENCES source_operation_mappings(id)
);
CREATE INDEX production_order_operation_evidence_order_idx ON public.production_order_operation_evidence USING btree (organization_id, production_order_id, observed_at);
alter table public."production_order_operation_evidence" enable row level security;
create policy "production_order_operation_evidence_read" on public."production_order_operation_evidence" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operation_evidence.organization_id) AND m.active))));

