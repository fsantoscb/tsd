create table public."production_routing_exceptions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_order_id" uuid not null,
  "production_order_operation_id" uuid,
  "exception_type" text not null,
  "description" text not null,
  "source_dataset" text,
  "source_record_key" text,
  "detected_at" timestamp with time zone default now() not null,
  "resolved_at" timestamp with time zone,
  "status" text default 'OPEN'::text not null,
  "resolved_by" uuid,
  "resolution_note" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_routing_exception_organization_id_production_o_fkey1" FOREIGN KEY (organization_id, production_order_operation_id) REFERENCES production_order_operations(organization_id, id) ON DELETE CASCADE,
  constraint "production_routing_exceptions_check" CHECK ((status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text])) AND resolved_at IS NULL OR (status = ANY (ARRAY['RESOLVED'::text, 'DISMISSED'::text])) AND resolved_at IS NOT NULL),
  constraint "production_routing_exceptions_exception_type_check" CHECK (exception_type = ANY (ARRAY['SKIPPED_OPERATION'::text, 'OUT_OF_SEQUENCE'::text, 'UNKNOWN_SOURCE_STAGE'::text, 'UNEXPECTED_OPERATION'::text, 'ROUTING_MISMATCH'::text, 'SOURCE_QUANTITY_CHANGE'::text, 'SOURCE_ORDER_CANCELLED'::text, 'AMBIGUOUS_SOURCE_EVIDENCE'::text])),
  constraint "production_routing_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_routing_exceptions_organization_id_production_o_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE,
  constraint "production_routing_exceptions_pkey" PRIMARY KEY (id),
  constraint "production_routing_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text, 'RESOLVED'::text, 'DISMISSED'::text]))
);
alter table public."production_routing_exceptions" enable row level security;
create policy "production_routing_exceptions_manage" on public."production_routing_exceptions" as PERMISSIVE for UPDATE to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_routing_exceptions_read" on public."production_routing_exceptions" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active))));
CREATE TRIGGER production_routing_exceptions_audit AFTER INSERT OR DELETE OR UPDATE ON production_routing_exceptions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();

