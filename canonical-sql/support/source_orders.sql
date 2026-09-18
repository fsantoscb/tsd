create table public."source_orders" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid not null,
  "order_no" text not null,
  "date_received" timestamp with time zone,
  "date_due" timestamp with time zone,
  "date_released" timestamp with time zone,
  "source_status" text,
  "source_sub_status" text,
  "customer_code" text,
  "customer_name" text,
  "ship_to_name" text,
  "customer_state" text,
  "city" text,
  "delivery_desc" text,
  "client_so_number" text,
  "source_priority" integer,
  "source_updated_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "site" text,
  "source_route_id" text,
  "cost_centre" text,
  "stop_ship_flag" text,
  "release_source_status" text,
  constraint "source_orders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "source_orders_pkey" PRIMARY KEY (id),
  constraint "source_orders_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id),
  constraint "source_orders_sync_batch_id_order_no_key" UNIQUE (sync_batch_id, order_no)
);
CREATE INDEX source_orders_current_lookup_idx ON public.source_orders USING btree (organization_id, sync_batch_id, order_no);
CREATE INDEX source_orders_order_no_idx ON public.source_orders USING btree (order_no);
CREATE INDEX source_orders_site_idx ON public.source_orders USING btree (site);
alter table public."source_orders" enable row level security;
CREATE TRIGGER source_orders_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_orders FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization();

