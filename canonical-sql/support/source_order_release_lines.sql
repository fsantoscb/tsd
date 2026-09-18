create table public."source_order_release_lines" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_order_no" text not null,
  "source_line_id" text not null,
  "source_product_code" text,
  "source_description" text,
  "production_units" numeric default 0 not null,
  "released" boolean,
  "date_released" timestamp with time zone,
  "raw_release_value" text,
  "created_at" timestamp with time zone default now() not null,
  "source_line_status" text,
  "quantity_processed" numeric,
  "source_weight" numeric,
  "stock_reserved_flag" text,
  "source_updated_at" timestamp with time zone,
  "ingestion_run_id" uuid,
  "source_presence" text default 'ACTIVE'::text not null,
  "source_routing" text,
  "source_operational_code" text,
  "source_operational_codes" text,
  "operational_code_conflict" boolean default false not null,
  "process_origin_code" text,
  "process_origin_codes" text,
  "process_origin_conflict" boolean default false not null,
  "process_origin_at" timestamp with time zone,
  constraint "source_order_release_lines_ingestion_run_fkey" FOREIGN KEY (ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id),
  constraint "source_order_release_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "source_order_release_lines_organization_id_source_system_so_key" UNIQUE (organization_id, source_system, source_order_no, source_line_id),
  constraint "source_order_release_lines_pkey" PRIMARY KEY (id),
  constraint "source_order_release_lines_source_presence_check" CHECK (source_presence = ANY (ARRAY['ACTIVE'::text, 'NOT_SEEN_IN_LATEST_COMPLETE_SNAPSHOT'::text, 'SOURCE_INACTIVE'::text])),
  constraint "source_order_release_lines_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)
);
alter table public."source_order_release_lines" enable row level security;
create policy "source_order_release_lines_read" on public."source_order_release_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_order_release_lines.organization_id) AND m.active))));

