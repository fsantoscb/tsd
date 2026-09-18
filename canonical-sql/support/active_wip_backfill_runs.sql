create table public."active_wip_backfill_runs" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "started_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone,
  "staged_lines" integer default 0 not null,
  "created_mos" integer default 0 not null,
  "evidence_added" integer default 0 not null,
  "exceptions_added" integer default 0 not null,
  "status" text default 'RUNNING'::text not null,
  constraint "active_wip_backfill_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "active_wip_backfill_runs_pkey" PRIMARY KEY (id),
  constraint "active_wip_backfill_runs_status_check" CHECK (status = ANY (ARRAY['RUNNING'::text, 'COMPLETED'::text, 'FAILED'::text]))
);
alter table public."active_wip_backfill_runs" enable row level security;
create policy "active_wip_backfill_runs_read" on public."active_wip_backfill_runs" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_backfill_runs.organization_id) AND m.active))));

