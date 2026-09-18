create table public."production_order_history" (
  "id" uuid default gen_random_uuid() not null,
  "production_order_id" uuid not null,
  "organization_id" uuid not null,
  "order_no" text not null,
  "changed_by" uuid,
  "changed_by_email" text,
  "changed_at" timestamp with time zone default now() not null,
  "before_state" jsonb not null,
  "after_state" jsonb not null,
  constraint "production_order_history_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "production_order_history_pkey" PRIMARY KEY (id),
  constraint "production_order_history_production_order_id_fkey" FOREIGN KEY (production_order_id) REFERENCES production_orders(id)
);
CREATE INDEX production_order_history_order_idx ON public.production_order_history USING btree (organization_id, order_no, changed_at DESC);
alter table public."production_order_history" enable row level security;

