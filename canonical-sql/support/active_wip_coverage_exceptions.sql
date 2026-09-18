create table public."active_wip_coverage_exceptions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_order_no" text not null,
  "stage_code" text not null,
  "units" numeric default 0 not null,
  "primary_cause" text not null,
  "blocking_cause" text not null,
  "explanation" text not null,
  "status" text default 'OPEN'::text not null,
  "first_detected_at" timestamp with time zone default now() not null,
  "last_detected_at" timestamp with time zone default now() not null,
  "resolved_at" timestamp with time zone,
  constraint "active_wip_coverage_exception_organization_id_source_system_key" UNIQUE (organization_id, source_system, source_order_no, stage_code),
  constraint "active_wip_coverage_exceptions_blocking_cause_check" CHECK (blocking_cause = ANY (ARRAY['NONE'::text, 'PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'SOURCE_LINE_MISSING'::text, 'INVALID_QUANTITY'::text, 'SO_NOT_ELIGIBLE'::text, 'MO_GENERATION_BUG'::text, 'DUPLICATE_PREVENTION_CONFLICT'::text, 'SOURCE_MAPPING_PROBLEM'::text, 'SOURCE_ORDER_NOT_IMPORTED'::text, 'UNKNOWN'::text])),
  constraint "active_wip_coverage_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id),
  constraint "active_wip_coverage_exceptions_pkey" PRIMARY KEY (id),
  constraint "active_wip_coverage_exceptions_primary_cause_check" CHECK (primary_cause = ANY (ARRAY['PRE_EXISTING_WIP'::text, 'PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'SOURCE_LINE_MISSING'::text, 'INVALID_QUANTITY'::text, 'SO_NOT_ELIGIBLE'::text, 'MO_GENERATION_BUG'::text, 'DUPLICATE_PREVENTION_CONFLICT'::text, 'SOURCE_MAPPING_PROBLEM'::text, 'SOURCE_ORDER_NOT_IMPORTED'::text, 'UNKNOWN'::text])),
  constraint "active_wip_coverage_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'ACCEPTED'::text, 'RESOLVED'::text]))
);
alter table public."active_wip_coverage_exceptions" enable row level security;
create policy "active_wip_coverage_exceptions_read" on public."active_wip_coverage_exceptions" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_coverage_exceptions.organization_id) AND m.active))));

