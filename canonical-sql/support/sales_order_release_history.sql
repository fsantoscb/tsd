create table public."sales_order_release_history" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_order_no" text not null,
  "previous_release_status" text,
  "new_release_status" text not null,
  "eligibility_snapshot" text not null,
  "blockers_snapshot" jsonb default '[]'::jsonb not null,
  "source_status_snapshot" jsonb default '{}'::jsonb not null,
  "changed_at" timestamp with time zone default now() not null,
  "source_sync_batch_id" uuid,
  "actor" text default 'SOURCE_SYSTEM'::text not null,
  constraint "sales_order_release_history_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "sales_order_release_history_organization_id_source_order_no_key" UNIQUE (organization_id, source_order_no, new_release_status, source_sync_batch_id),
  constraint "sales_order_release_history_pkey" PRIMARY KEY (id),
  constraint "sales_order_release_history_source_sync_batch_id_fkey" FOREIGN KEY (source_sync_batch_id) REFERENCES sync_batches(id)
);
alter table public."sales_order_release_history" enable row level security;
create policy "sales_order_release_history_read" on public."sales_order_release_history" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = sales_order_release_history.organization_id) AND m.active))));

