create table public."oracle_line_ingestion_runs" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid,
  "agent_id" text not null,
  "batch_size" integer not null,
  "status" text default 'RUNNING'::text not null,
  "snapshot_status" text default 'PARTIAL'::text not null,
  "last_order_no" text,
  "last_line_number" integer,
  "batches_completed" integer default 0 not null,
  "rows_processed" integer default 0 not null,
  "started_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone,
  "error" text,
  constraint "oracle_line_ingestion_runs_batch_size_check" CHECK (batch_size >= 250 AND batch_size <= 2000),
  constraint "oracle_line_ingestion_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "oracle_line_ingestion_runs_pkey" PRIMARY KEY (id),
  constraint "oracle_line_ingestion_runs_snapshot_status_check" CHECK (snapshot_status = ANY (ARRAY['PARTIAL'::text, 'COMPLETE'::text])),
  constraint "oracle_line_ingestion_runs_status_check" CHECK (status = ANY (ARRAY['RUNNING'::text, 'COMPLETED'::text, 'FAILED'::text, 'CANCELLED'::text])),
  constraint "oracle_line_ingestion_runs_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)
);
CREATE INDEX oracle_line_ingestion_runs_latest_complete_idx ON public.oracle_line_ingestion_runs USING btree (organization_id, completed_at DESC) WHERE ((snapshot_status = 'COMPLETE'::text) AND (status = 'COMPLETED'::text));
alter table public."oracle_line_ingestion_runs" enable row level security;
create policy "oracle_line_runs_read" on public."oracle_line_ingestion_runs" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = oracle_line_ingestion_runs.organization_id) AND m.active))));

