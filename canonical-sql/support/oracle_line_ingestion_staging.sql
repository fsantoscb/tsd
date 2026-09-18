create table public."oracle_line_ingestion_staging" (
  "organization_id" uuid not null,
  "ingestion_run_id" uuid not null,
  "source_order_no" text not null,
  "source_line_id" text not null,
  "source_product_code" text,
  "source_description" text,
  "production_units" numeric not null,
  "released" boolean,
  "raw_release_value" text,
  "source_line_status" text,
  "quantity_processed" numeric,
  "source_weight" numeric,
  "stock_reserved_flag" text,
  "source_updated_at" timestamp with time zone,
  "source_routing" text,
  "source_operational_code" text,
  "source_operational_codes" text,
  "operational_code_conflict" boolean default false not null,
  "process_origin_code" text,
  "process_origin_codes" text,
  "process_origin_conflict" boolean default false not null,
  "process_origin_at" timestamp with time zone,
  constraint "oracle_line_ingestion_staging_ingestion_run_id_fkey" FOREIGN KEY (ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id) ON DELETE CASCADE,
  constraint "oracle_line_ingestion_staging_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "oracle_line_ingestion_staging_pkey" PRIMARY KEY (ingestion_run_id, source_order_no, source_line_id)
);
alter table public."oracle_line_ingestion_staging" enable row level security;

