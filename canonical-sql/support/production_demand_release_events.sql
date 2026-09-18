create table public."production_demand_release_events" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_demand_line_id" uuid not null,
  "manufacturing_order_line_id" uuid not null,
  "manufacturing_order_id" uuid not null,
  "event_type" text not null,
  "action" text not null,
  "original_mapping_at" timestamp with time zone not null,
  "original_snapshot_run_id" uuid,
  "original_released" boolean,
  "original_raw_release_value" text,
  "event_snapshot_run_id" uuid not null,
  "event_at" timestamp with time zone not null,
  "previous_release_value" text,
  "current_release_value" text not null,
  "mapped_quantity" numeric not null,
  "executed_quantity" numeric default 0 not null,
  "mo_status" text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_demand_release_eve_production_demand_line_id_eve_key" UNIQUE (production_demand_line_id, event_type, event_snapshot_run_id),
  constraint "production_demand_release_even_manufacturing_order_line_id_fkey" FOREIGN KEY (manufacturing_order_line_id) REFERENCES manufacturing_order_lines(id),
  constraint "production_demand_release_events_action_check" CHECK (action = ANY (ARRAY['WITHDRAWN_FROM_PLANNED_DEMAND'::text, 'RELEASE_REVOKED_AFTER_PRODUCTION_START'::text, 'RELEASE_REVOKED_AFTER_COMPLETION'::text, 'CANCELLED_MO_REVIEW_REQUIRED'::text, 'INVALID_AT_CREATION'::text, 'CANNOT_PROVE'::text, 'INCREMENTAL_RECONCILIATION_REQUIRED'::text, 'RESTORED_TO_PLANNED_DEMAND'::text, 'RELEASE_REACTIVATED_AFTER_PRODUCTION_START'::text, 'RELEASE_REACTIVATED_AFTER_COMPLETION'::text, 'RELEASE_REACTIVATED_MO_CANCELLED'::text, 'RELEASE_REACTIVATION_BLOCKED'::text])),
  constraint "production_demand_release_events_event_snapshot_run_id_fkey" FOREIGN KEY (event_snapshot_run_id) REFERENCES oracle_line_ingestion_runs(id),
  constraint "production_demand_release_events_event_type_check" CHECK (event_type = ANY (ARRAY['RELEASE_REVOKED_AFTER_MAPPING'::text, 'RE_RELEASED_REQUIRES_RECONCILIATION'::text, 'RELEASE_REACTIVATED'::text])),
  constraint "production_demand_release_events_manufacturing_order_id_fkey" FOREIGN KEY (manufacturing_order_id) REFERENCES production_orders(id),
  constraint "production_demand_release_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_demand_release_events_original_snapshot_run_id_fkey" FOREIGN KEY (original_snapshot_run_id) REFERENCES oracle_line_ingestion_runs(id),
  constraint "production_demand_release_events_pkey" PRIMARY KEY (id),
  constraint "production_demand_release_events_production_demand_line_id_fkey" FOREIGN KEY (production_demand_line_id) REFERENCES production_demand_lines(id)
);
alter table public."production_demand_release_events" enable row level security;
create policy "production_demand_release_events_read" on public."production_demand_release_events" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_release_events.organization_id) AND m.active))));

