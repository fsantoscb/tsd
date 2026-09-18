-- TSD Production Control Canonical V2 definitive baseline.
-- Generated from the approved C1.3 direct manifest and C2.1A support graph.
-- Schema/config only: no Oracle, operational, or master data.
begin;
select set_config('check_function_bodies','off',true);
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create extension if not exists btree_gist;
create extension if not exists pgtap;

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
  constraint "active_wip_backfill_runs_pkey" PRIMARY KEY (id),
  constraint "active_wip_backfill_runs_status_check" CHECK (status = ANY (ARRAY['RUNNING'::text, 'COMPLETED'::text, 'FAILED'::text]))
);
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
  constraint "active_wip_coverage_exceptions_pkey" PRIMARY KEY (id),
  constraint "active_wip_coverage_exceptions_primary_cause_check" CHECK (primary_cause = ANY (ARRAY['PRE_EXISTING_WIP'::text, 'PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'SOURCE_LINE_MISSING'::text, 'INVALID_QUANTITY'::text, 'SO_NOT_ELIGIBLE'::text, 'MO_GENERATION_BUG'::text, 'DUPLICATE_PREVENTION_CONFLICT'::text, 'SOURCE_MAPPING_PROBLEM'::text, 'SOURCE_ORDER_NOT_IMPORTED'::text, 'UNKNOWN'::text])),
  constraint "active_wip_coverage_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'ACCEPTED'::text, 'RESOLVED'::text]))
);
create table public."capacity_legacy_overrides" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_area_id" uuid not null,
  "source_name" text not null,
  "daily_capacity" numeric not null,
  "work_days" numeric default 5 not null,
  "temporary" boolean default true not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "capacity_legacy_overrides_daily_capacity_check" CHECK (daily_capacity >= 0::numeric),
  constraint "capacity_legacy_overrides_organization_id_production_area_i_key" UNIQUE (organization_id, production_area_id, source_name),
  constraint "capacity_legacy_overrides_pkey" PRIMARY KEY (id),
  constraint "capacity_legacy_overrides_work_days_check" CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
);
create table public."capacity_profiles" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "production_area_id" uuid not null,
  "shift_template_id" uuid not null,
  "resource_count" numeric not null,
  "machine_count" numeric,
  "scheduled_hours" numeric not null,
  "hourly_rate" numeric not null,
  "efficiency" numeric not null,
  "work_days" numeric default 5 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "capacity_profiles_efficiency_check" CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric),
  constraint "capacity_profiles_hourly_rate_check" CHECK (hourly_rate >= 0::numeric),
  constraint "capacity_profiles_machine_count_check" CHECK (machine_count >= 0::numeric),
  constraint "capacity_profiles_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "capacity_profiles_pkey" PRIMARY KEY (id),
  constraint "capacity_profiles_resource_count_check" CHECK (resource_count >= 0::numeric),
  constraint "capacity_profiles_scheduled_hours_check" CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric),
  constraint "capacity_profiles_work_days_check" CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
);
create table public."capacity_scenario_lines" (
  "id" uuid default gen_random_uuid() not null,
  "capacity_scenario_id" uuid not null,
  "production_area_id" uuid not null,
  "shift_template_id" uuid not null,
  "resource_count" numeric not null,
  "machine_count" numeric,
  "scheduled_hours" numeric not null,
  "hourly_rate" numeric not null,
  "efficiency" numeric not null,
  "work_days" numeric default 5 not null,
  "calculated_capacity" numeric generated always as ((((resource_count * scheduled_hours) * hourly_rate) * efficiency)) stored,
  constraint "capacity_scenario_lines_efficiency_check" CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric),
  constraint "capacity_scenario_lines_hourly_rate_check" CHECK (hourly_rate >= 0::numeric),
  constraint "capacity_scenario_lines_machine_count_check" CHECK (machine_count >= 0::numeric),
  constraint "capacity_scenario_lines_pkey" PRIMARY KEY (id),
  constraint "capacity_scenario_lines_resource_count_check" CHECK (resource_count >= 0::numeric),
  constraint "capacity_scenario_lines_scheduled_hours_check" CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric),
  constraint "capacity_scenario_lines_work_days_check" CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
);
create table public."capacity_scenarios" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "notes" text,
  "created_by" uuid,
  "created_by_email" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "capacity_scenarios_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "capacity_scenarios_pkey" PRIMARY KEY (id)
);
create table public."deputy_import_batches" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "filename" text not null,
  "source_type" text not null,
  "source_timezone" text not null,
  "target_timezone" text default 'Australia/Brisbane'::text not null,
  "content_hash" text not null,
  "imported_at" timestamp with time zone default now() not null,
  "covered_from" date,
  "covered_to" date,
  "raw_rows" integer default 0 not null,
  "approved_rows" integer default 0 not null,
  "provisional_rows" integer default 0 not null,
  "quarantined_rows" integer default 0 not null,
  "status" text not null,
  "imported_by" uuid,
  "imported_by_email" text,
  "error_message" text,
  "segmented_rows" integer default 0 not null,
  constraint "deputy_import_batches_organization_id_content_hash_key" UNIQUE (organization_id, content_hash),
  constraint "deputy_import_batches_pkey" PRIMARY KEY (id),
  constraint "deputy_import_batches_source_type_check" CHECK (source_type = ANY (ARRAY['CSV'::text, 'XLSX'::text])),
  constraint "deputy_import_batches_status_check" CHECK (status = ANY (ARRAY['PROCESSING'::text, 'COMPLETED'::text, 'FAILED'::text]))
);
create table public."deputy_raw_timesheets" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "import_batch_id" uuid not null,
  "source_row_key" text not null,
  "source_timesheet_id" text,
  "employee_id" text,
  "person_key" text,
  "display_name" text,
  "timesheet_date" date,
  "raw_area" text,
  "normalized_area" text,
  "start_at" timestamp with time zone,
  "end_at" timestamp with time zone,
  "total_hours" numeric,
  "meal_break_hours" numeric,
  "approval_status" text not null,
  "row_status" text not null,
  "quarantine_reasons" text[] default '{}'::text[] not null,
  "raw_data" jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "deputy_raw_timesheets_approval_status_check" CHECK (approval_status = ANY (ARRAY['APPROVED'::text, 'PROVISIONAL'::text, 'INCOMPLETE'::text])),
  constraint "deputy_raw_timesheets_import_batch_id_source_row_key_key" UNIQUE (import_batch_id, source_row_key),
  constraint "deputy_raw_timesheets_pkey" PRIMARY KEY (id),
  constraint "deputy_raw_timesheets_row_status_check" CHECK (row_status = ANY (ARRAY['ACCEPTED'::text, 'QUARANTINED'::text]))
);
create table public."kpi_definitions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "category" text default 'OPERATIONS'::text not null,
  "unit" text default 'UNITS'::text not null,
  "direction" text default 'LOWER_IS_BETTER'::text not null,
  "frequency" text default 'REALTIME'::text not null,
  "data_source" text,
  "data_readiness_status" text not null,
  "is_active" boolean default false not null,
  "dashboard_priority" integer,
  "owner_role" text default 'manager'::text not null,
  "supports_area_dimension" boolean default false not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "kpi_definitions_data_readiness_status_check" CHECK (data_readiness_status = ANY (ARRAY['ACTIVE'::text, 'WAITING_FOR_DATA'::text, 'DISABLED'::text])),
  constraint "kpi_definitions_direction_check" CHECK (direction = ANY (ARRAY['HIGHER_IS_BETTER'::text, 'LOWER_IS_BETTER'::text, 'TARGET_RANGE'::text])),
  constraint "kpi_definitions_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "kpi_definitions_pkey" PRIMARY KEY (id)
);
create table public."kpi_rate_rules" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "process" text not null,
  "rate_per_hour" numeric not null,
  "unit" text not null,
  "capacity_mode" text not null,
  "calculation_version" text not null,
  "effective_from" date not null,
  "effective_to" date,
  "active" boolean default true not null,
  constraint "kpi_rate_rules_check" CHECK (effective_to IS NULL OR effective_to >= effective_from),
  constraint "kpi_rate_rules_organization_id_process_effective_from_key" UNIQUE (organization_id, process, effective_from),
  constraint "kpi_rate_rules_pkey" PRIMARY KEY (id),
  constraint "kpi_rate_rules_process_check" CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text])),
  constraint "kpi_rate_rules_rate_per_hour_check" CHECK (rate_per_hour > 0::numeric)
);
create table public."kpi_results" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "kpi_definition_id" uuid not null,
  "period_start" timestamp with time zone not null,
  "period_end" timestamp with time zone not null,
  "production_date" date not null,
  "production_area_id" uuid,
  "shift_id" uuid,
  "machine_id" text,
  "operator_id" text,
  "order_no" text,
  "product_code" text,
  "numerator" numeric,
  "denominator" numeric,
  "value" numeric,
  "target_value" numeric,
  "status" text not null,
  "data_quality_status" text not null,
  "source_refresh_at" timestamp with time zone,
  "calculated_at" timestamp with time zone default now() not null,
  constraint "kpi_results_data_quality_status_check" CHECK (data_quality_status = ANY (ARRAY['NO_DATA'::text, 'PARTIAL_DATA'::text, 'STALE_DATA'::text, 'VALID'::text])),
  constraint "kpi_results_pkey" PRIMARY KEY (id),
  constraint "kpi_results_status_check" CHECK (status = ANY (ARRAY['GOOD'::text, 'WARNING'::text, 'CRITICAL'::text, 'NO_TARGET'::text, 'NO_DATA'::text]))
);
create table public."kpi_targets" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "kpi_definition_id" uuid not null,
  "production_area_id" uuid,
  "shift_id" uuid,
  "effective_from" date not null,
  "effective_to" date,
  "target_value" numeric not null,
  "warning_value" numeric,
  "critical_value" numeric,
  "created_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "kpi_targets_check" CHECK (effective_to IS NULL OR effective_to >= effective_from),
  constraint "kpi_targets_pkey" PRIMARY KEY (id)
);
create table public."labour_segments" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "import_batch_id" uuid not null,
  "source_timesheet_row_id" uuid not null,
  "person_key" text not null,
  "area_code" text not null,
  "segment_start" timestamp with time zone not null,
  "segment_end" timestamp with time zone not null,
  "calendar_date" date not null,
  "operational_date" date not null,
  "hour_bucket" smallint not null,
  "shift_code" text not null,
  "paid_hours" numeric not null,
  "regular_hours" numeric not null,
  "overtime_hours" numeric not null,
  "paid_break_hours" numeric not null,
  "productive_hours" numeric not null,
  "approval_status" text not null,
  "allocation_method" text default 'PRO_RATA_ELAPSED'::text not null,
  "week_start" date not null,
  "calculation_version" text default 'V29_DAILY8_WEEKLY38_WEEKEND_OT_PAID_BREAK20'::text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "labour_segments_hour_bucket_check" CHECK (hour_bucket >= 0 AND hour_bucket <= 23),
  constraint "labour_segments_pkey" PRIMARY KEY (id),
  constraint "labour_segments_source_timesheet_row_id_segment_start_key" UNIQUE (source_timesheet_row_id, segment_start)
);
create table public."maintenance_asset_categories" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_asset_categories_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "maintenance_asset_categories_pkey" PRIMARY KEY (id)
);
create table public."maintenance_asset_code_sequences" (
  "organization_id" uuid not null,
  "prefix" character varying not null,
  "last_number" integer default 0 not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_asset_code_sequences_last_number_check" CHECK (last_number >= 0),
  constraint "maintenance_asset_code_sequences_pkey" PRIMARY KEY (organization_id, prefix)
);
create table public."maintenance_asset_installations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "movement_id" text,
  "movable_asset_id" uuid not null,
  "host_asset_id" uuid not null,
  "host_system_asset_id" uuid,
  "position" text,
  "channel" text,
  "installed_at" timestamp with time zone not null,
  "removed_at" timestamp with time zone,
  "movement_reason" text,
  "installed_by" text,
  "notes" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_asset_installations_check" CHECK (movable_asset_id <> host_asset_id),
  constraint "maintenance_asset_installations_check1" CHECK (removed_at IS NULL OR installed_at < removed_at),
  constraint "maintenance_asset_installations_movable_asset_id_tstzrange_excl" EXCLUDE USING gist (movable_asset_id WITH =, tstzrange(installed_at, COALESCE(removed_at, 'infinity'::timestamp with time zone), '[)'::text) WITH &&),
  constraint "maintenance_asset_installations_organization_id_movement_id_key" UNIQUE (organization_id, movement_id),
  constraint "maintenance_asset_installations_pkey" PRIMARY KEY (id)
);
create table public."maintenance_asset_prefixes" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "category_id" uuid not null,
  "prefix" character varying not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_asset_prefixes_organization_id_prefix_key" UNIQUE (organization_id, prefix),
  constraint "maintenance_asset_prefixes_pkey" PRIMARY KEY (id),
  constraint "maintenance_asset_prefixes_prefix_check" CHECK (prefix::text ~ '^[A-Z]{2,5}$'::text)
);
create table public."maintenance_assets" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "asset_code" text not null,
  "name" text not null,
  "location" text,
  "criticality" text default 'medium'::text not null,
  "status" text default 'operational'::text not null,
  "active" boolean default true not null,
  "created_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "public_qr_token" uuid default gen_random_uuid() not null,
  "asset_name" text,
  "category_id" uuid,
  "prefix_id" uuid,
  "parent_asset_id" uuid,
  "manufacturer" text,
  "model" text,
  "serial_number" text,
  "description" text,
  "installation_date" date,
  "purchase_date" date,
  "purchase_cost" numeric,
  "warranty_expiry" date,
  "installed_at" timestamp with time zone,
  "removed_at" timestamp with time zone,
  "installed_work_order_id" uuid,
  "removed_work_order_id" uuid,
  "asset_kind" text default 'FIXED'::text not null,
  "asset_type" text,
  "asset_category" text,
  "commission_date" date,
  "retire_date" date,
  "notes" text,
  "asset_level" text default 'EQUIPMENT'::text not null,
  "operational_role" text default 'SUPPORT'::text not null,
  "counts_in_availability" boolean default false not null,
  "capacity_resource" boolean default false not null,
  constraint "maintenance_assets_asset_kind_check" CHECK (asset_kind = ANY (ARRAY['FIXED'::text, 'MOVABLE'::text])),
  constraint "maintenance_assets_asset_level_check" CHECK (asset_level = ANY (ARRAY['SYSTEM'::text, 'EQUIPMENT'::text, 'SUBSYSTEM'::text, 'COMPONENT'::text])),
  constraint "maintenance_assets_criticality_check" CHECK (criticality = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  constraint "maintenance_assets_operational_role_check" CHECK (operational_role = ANY (ARRAY['PRODUCTION'::text, 'UTILITY'::text, 'SUPPORT'::text, 'MOVABLE'::text])),
  constraint "maintenance_assets_organization_id_asset_code_key" UNIQUE (organization_id, asset_code),
  constraint "maintenance_assets_pkey" PRIMARY KEY (id),
  constraint "maintenance_assets_status_check" CHECK (status = ANY (ARRAY['operational'::text, 'down'::text, 'maintenance'::text, 'standby'::text, 'retired'::text, 'scrapped'::text]))
);
create table public."maintenance_attachments" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_id" uuid not null,
  "file_name" text not null,
  "storage_path" text not null,
  "mime_type" text,
  "file_size" bigint,
  "uploaded_by" uuid,
  "uploaded_by_email" text,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_attachments_file_size_check" CHECK (file_size >= 0),
  constraint "maintenance_attachments_pkey" PRIMARY KEY (id)
);
create table public."maintenance_audit_log" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "user_id" uuid,
  "entity_type" text not null,
  "entity_id" uuid,
  "action" text not null,
  "old_values" jsonb,
  "new_values" jsonb,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_audit_log_pkey" PRIMARY KEY (id)
);
create table public."maintenance_component_code_sequences" (
  "organization_id" uuid not null,
  "parent_asset_id" uuid not null,
  "component_prefix" character varying not null,
  "last_number" integer default 0 not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_component_code_sequences_last_number_check" CHECK (last_number >= 0),
  constraint "maintenance_component_code_sequences_pkey" PRIMARY KEY (organization_id, parent_asset_id, component_prefix)
);
create table public."maintenance_component_prefixes" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "prefix" character varying not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_component_prefixes_organization_id_prefix_key" UNIQUE (organization_id, prefix),
  constraint "maintenance_component_prefixes_pkey" PRIMARY KEY (id),
  constraint "maintenance_component_prefixes_prefix_check" CHECK (prefix::text ~ '^[A-Z]{2,4}$'::text)
);
create table public."maintenance_downtime_events" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "asset_id" uuid not null,
  "work_order_id" uuid,
  "started_at" timestamp with time zone default now() not null,
  "ended_at" timestamp with time zone,
  "reason" text,
  "started_by" uuid,
  "ended_by" uuid,
  "event_code" text,
  "event_date" date,
  "host_asset_id" uuid,
  "host_system_asset_id" uuid,
  "affected_asset_id" uuid,
  "downtime_minutes" numeric,
  "event_type" text,
  "maintenance_class" text,
  "failure_category" text,
  "failure_mode" text,
  "root_cause" text,
  "action_taken" text,
  "spare_parts_text" text,
  "description" text,
  "counts_as_failure" boolean default false not null,
  "counts_as_downtime" boolean default true not null,
  "event_status" text,
  "source_system" text,
  "source_key" text,
  "source_row" integer,
  "original_duration_minutes" numeric,
  "clock_duration_minutes" numeric,
  "correction_factor" numeric,
  "data_quality_status" text,
  "correction_confidence" text,
  "correction_method" text,
  "correction_note" text,
  "raw_reason" text,
  "historical_asset_reference" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_downtime_events_pkey" PRIMARY KEY (id)
);
create table public."maintenance_import_batches" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "file_name" text not null,
  "file_hash" text not null,
  "source_system" text not null,
  "status" text not null,
  "uploaded_by" uuid,
  "started_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone,
  "total_rows" integer default 0 not null,
  "valid_rows" integer default 0 not null,
  "warning_rows" integer default 0 not null,
  "error_rows" integer default 0 not null,
  "inserted_rows" integer default 0 not null,
  "updated_rows" integer default 0 not null,
  "skipped_rows" integer default 0 not null,
  "import_report" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_import_batches_organization_id_file_hash_key" UNIQUE (organization_id, file_hash),
  constraint "maintenance_import_batches_pkey" PRIMARY KEY (id),
  constraint "maintenance_import_batches_status_check" CHECK (status = ANY (ARRAY['VALIDATING'::text, 'READY'::text, 'IMPORTING'::text, 'COMPLETED'::text, 'FAILED'::text, 'ROLLED_BACK'::text]))
);
create table public."maintenance_import_staging" (
  "id" uuid default gen_random_uuid() not null,
  "batch_id" uuid not null,
  "organization_id" uuid not null,
  "source_row" integer,
  "row_status" text not null,
  "source_key" text,
  "host_asset_code" text,
  "affected_asset_code" text,
  "historical_asset_reference" text,
  "errors" text[] default '{}'::text[] not null,
  "warnings" text[] default '{}'::text[] not null,
  "payload" jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_import_staging_pkey" PRIMARY KEY (id),
  constraint "maintenance_import_staging_row_status_check" CHECK (row_status = ANY (ARRAY['VALID'::text, 'WARNING'::text, 'ERROR'::text, 'DUPLICATE'::text, 'UNRESOLVED_PH'::text]))
);
create table public."maintenance_inventory_locations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "code" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_inventory_locations_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "maintenance_inventory_locations_pkey" PRIMARY KEY (id)
);
create table public."maintenance_inventory_transactions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "part_id" uuid not null,
  "location_id" uuid not null,
  "work_order_id" uuid,
  "transaction_type" text not null,
  "quantity" numeric not null,
  "unit_cost_snapshot" numeric default 0 not null,
  "notes" text,
  "created_by" uuid,
  "created_by_email" text,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_inventory_transactions_check" CHECK ((transaction_type = ANY (ARRAY['receipt'::text, 'return'::text])) AND quantity > 0::numeric OR transaction_type = 'issue'::text AND quantity < 0::numeric OR transaction_type = 'adjustment'::text),
  constraint "maintenance_inventory_transactions_pkey" PRIMARY KEY (id),
  constraint "maintenance_inventory_transactions_quantity_check" CHECK (quantity <> 0::numeric),
  constraint "maintenance_inventory_transactions_transaction_type_check" CHECK (transaction_type = ANY (ARRAY['receipt'::text, 'issue'::text, 'return'::text, 'adjustment'::text]))
);
create table public."maintenance_members" (
  "user_id" uuid not null,
  "organization_id" uuid not null,
  "role" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_members_pkey" PRIMARY KEY (user_id, organization_id),
  constraint "maintenance_members_role_check" CHECK (role = ANY (ARRAY['admin'::text, 'maintenance'::text, 'supervisor'::text, 'operator'::text, 'viewer'::text]))
);
create table public."maintenance_parts" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "part_number" text not null,
  "description" text not null,
  "manufacturer" text,
  "unit_cost" numeric default 0 not null,
  "reorder_point" numeric default 0 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "maintenance_parts_organization_id_part_number_key" UNIQUE (organization_id, part_number),
  constraint "maintenance_parts_pkey" PRIMARY KEY (id)
);
create table public."maintenance_preventive_plan_tasks" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "preventive_plan_id" uuid not null,
  "sequence" integer not null,
  "task" text not null,
  "instructions" text,
  "required" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_preventive_plan_tasks_pkey" PRIMARY KEY (id)
);
create table public."maintenance_preventive_plans" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "asset_id" uuid not null,
  "code" text,
  "name" text not null,
  "description" text,
  "priority" text default 'medium'::text not null,
  "trigger_type" text default 'calendar'::text not null,
  "frequency_value" integer,
  "frequency_unit" text,
  "next_due_at" timestamp with time zone,
  "lead_time_days" integer default 0 not null,
  "estimated_minutes" integer,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "requires_downtime" boolean default false not null,
  constraint "maintenance_preventive_plans_frequency_unit_check" CHECK (frequency_unit = ANY (ARRAY['day'::text, 'week'::text, 'month'::text, 'year'::text])),
  constraint "maintenance_preventive_plans_pkey" PRIMARY KEY (id),
  constraint "maintenance_preventive_plans_priority_check" CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  constraint "maintenance_preventive_plans_trigger_type_check" CHECK (trigger_type = ANY (ARRAY['calendar'::text, 'meter'::text]))
);
create table public."maintenance_work_order_checklist" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_id" uuid not null,
  "sequence" integer not null,
  "task" text not null,
  "instructions" text,
  "required" boolean default true not null,
  "completed" boolean default false not null,
  "completed_at" timestamp with time zone,
  "completed_by" uuid,
  constraint "maintenance_work_order_checklist_pkey" PRIMARY KEY (id),
  constraint "maintenance_work_order_checklist_work_order_id_sequence_key" UNIQUE (work_order_id, sequence)
);
create table public."maintenance_work_order_comments" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_id" uuid not null,
  "user_id" uuid,
  "author_email" text,
  "comment" text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_work_order_comments_pkey" PRIMARY KEY (id)
);
create table public."maintenance_work_order_history" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_id" uuid not null,
  "from_status" text,
  "to_status" text not null,
  "changed_by" uuid,
  "changed_by_email" text,
  "changed_at" timestamp with time zone default now() not null,
  constraint "maintenance_work_order_history_pkey" PRIMARY KEY (id)
);
create table public."maintenance_work_order_labor" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_id" uuid not null,
  "user_id" uuid,
  "technician_email" text,
  "minutes" integer not null,
  "hourly_rate_snapshot" numeric,
  "description" text,
  "created_at" timestamp with time zone default now() not null,
  constraint "maintenance_work_order_labor_minutes_check" CHECK (minutes > 0),
  constraint "maintenance_work_order_labor_pkey" PRIMARY KEY (id)
);
create table public."maintenance_work_orders" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_order_number" text not null,
  "asset_id" uuid not null,
  "status" text default 'open'::text not null,
  "priority" text default 'medium'::text not null,
  "title" text not null,
  "problem_description" text,
  "root_cause" text,
  "resolution" text,
  "requested_by" uuid,
  "requested_by_email" text,
  "requested_at" timestamp with time zone default now() not null,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "updated_at" timestamp with time zone default now() not null,
  "cancel_reason" text,
  "due_at" timestamp with time zone,
  "work_order_type" text default 'corrective'::text not null,
  "preventive_plan_id" uuid,
  "component_asset_id" uuid,
  "no_parts_used_confirmed" boolean default false not null,
  "no_parts_used_confirmed_at" timestamp with time zone,
  "no_parts_used_confirmed_by" uuid,
  "source_pm_work_order_id" uuid,
  "request_flow" text,
  "request_type" text,
  "maintenance_requested_at" timestamp with time zone,
  "counts_as_downtime" boolean default false not null,
  "operator_request_key" text,
  "downtime_started_at" timestamp with time zone,
  constraint "maintenance_work_orders_pkey" PRIMARY KEY (id),
  constraint "maintenance_work_orders_priority_check" CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  constraint "maintenance_work_orders_request_flow_check" CHECK (request_flow = ANY (ARRAY['operator_fix'::text, 'maintenance_required'::text, 'maintenance_request'::text])),
  constraint "maintenance_work_orders_status_check" CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'waiting_parts'::text, 'waiting_external'::text, 'completed'::text, 'cancelled'::text, 'OPEN_OPERATOR'::text, 'WAITING_MAINTENANCE'::text, 'REQUESTED'::text])),
  constraint "maintenance_work_orders_work_order_number_key" UNIQUE (work_order_number),
  constraint "maintenance_work_orders_work_order_type_check" CHECK (work_order_type = ANY (ARRAY['corrective'::text, 'preventive'::text, 'inspection'::text]))
);
create table public."manufacturing_order_lines" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "manufacturing_order_id" uuid not null,
  "production_demand_line_id" uuid,
  "source_order_no" text not null,
  "source_order_line_id" text not null,
  "product_id" uuid,
  "routing_revision_id" uuid not null,
  "planned_quantity" numeric not null,
  "actual_quantity" numeric default 0 not null,
  "sequence" integer,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "manufacturing_order_lines_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "manufacturing_order_lines_manufacturing_order_id_source_ord_key" UNIQUE (manufacturing_order_id, source_order_line_id),
  constraint "manufacturing_order_lines_pkey" PRIMARY KEY (id),
  constraint "manufacturing_order_lines_planned_quantity_check" CHECK (planned_quantity > 0::numeric),
  constraint "manufacturing_order_lines_production_demand_line_id_key" UNIQUE (production_demand_line_id)
);
create table public."operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "operation_type" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "operations_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "operations_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "operations_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "operations_pkey" PRIMARY KEY (id)
);
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
  constraint "oracle_line_ingestion_runs_pkey" PRIMARY KEY (id),
  constraint "oracle_line_ingestion_runs_snapshot_status_check" CHECK (snapshot_status = ANY (ARRAY['PARTIAL'::text, 'COMPLETE'::text])),
  constraint "oracle_line_ingestion_runs_status_check" CHECK (status = ANY (ARRAY['RUNNING'::text, 'COMPLETED'::text, 'FAILED'::text, 'CANCELLED'::text]))
);
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
  constraint "oracle_line_ingestion_staging_pkey" PRIMARY KEY (ingestion_run_id, source_order_no, source_line_id)
);
create table public."organizations" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "timezone" text default 'Australia/Brisbane'::text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "organizations_pkey" PRIMARY KEY (id)
);
create table public."product_families" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "product_families_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "product_families_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "product_families_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "product_families_pkey" PRIMARY KEY (id)
);
create table public."product_mapping_resolution_audit" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_product_code" text not null,
  "product_id" uuid,
  "action" text not null,
  "confidence" text not null,
  "rule" text not null,
  "source_ingestion_run_id" uuid,
  "created_at" timestamp with time zone default now() not null,
  constraint "product_mapping_resolution_audit_pkey" PRIMARY KEY (id)
);
create table public."product_routing_assignments" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "product_id" uuid not null,
  "process_code" text not null,
  "routing_id" uuid not null,
  "assignment_source" text default 'MANUAL'::text not null,
  "approved" boolean default false not null,
  "approved_by" uuid,
  "approved_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "product_routing_assignments_assignment_source_check" CHECK (assignment_source = ANY (ARRAY['DETERMINISTIC_SOURCE'::text, 'MANUAL'::text, 'IMPORT'::text])),
  constraint "product_routing_assignments_organization_id_product_id_proc_key" UNIQUE (organization_id, product_id, process_code),
  constraint "product_routing_assignments_pkey" PRIMARY KEY (id),
  constraint "product_routing_assignments_process_code_check" CHECK (process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))
);
create table public."product_source_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_product_code" text not null,
  "product_id" uuid not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "mapping_method" text default 'LEGACY'::text not null,
  "confidence" text default 'UNRESOLVED'::text not null,
  "confirmed_at" timestamp with time zone,
  "confirmed_by" uuid,
  "notes" text,
  "source_ingestion_run_id" uuid,
  constraint "product_source_mappings_confidence_check" CHECK (confidence = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text, 'MANUAL_CONFIRMED'::text, 'AMBIGUOUS'::text, 'UNRESOLVED'::text])),
  constraint "product_source_mappings_mapping_method_check" CHECK (mapping_method = ANY (ARRAY['LEGACY'::text, 'SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text, 'MANUAL_CONFIRMED'::text])),
  constraint "product_source_mappings_organization_id_source_system_sourc_key" UNIQUE (organization_id, source_system, source_product_code),
  constraint "product_source_mappings_pkey" PRIMARY KEY (id)
);
create table public."product_types" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "product_types_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "product_types_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "product_types_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "product_types_pkey" PRIMARY KEY (id)
);
create table public."production_areas" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "sequence" integer default 0 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_areas_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_areas_pkey" PRIMARY KEY (id)
);
create table public."production_demand_exceptions" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_demand_line_id" uuid not null,
  "exception_type" text not null,
  "description" text not null,
  "status" text default 'OPEN'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "resolved_at" timestamp with time zone,
  constraint "production_demand_exceptions_exception_type_check" CHECK (exception_type = ANY (ARRAY['PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'ROUTING_INACTIVE'::text, 'INVALID_QUANTITY'::text])),
  constraint "production_demand_exceptions_pkey" PRIMARY KEY (id),
  constraint "production_demand_exceptions_production_demand_line_id_exce_key" UNIQUE (production_demand_line_id, exception_type, status),
  constraint "production_demand_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'RESOLVED'::text, 'DISMISSED'::text]))
);
create table public."production_demand_lines" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text not null,
  "source_order_no" text not null,
  "source_order_line_id" text not null,
  "product_id" uuid,
  "routing_id" uuid,
  "routing_revision_id" uuid,
  "source_product_code" text,
  "source_description" text,
  "quantity" numeric not null,
  "due_date" timestamp with time zone,
  "source_priority" integer,
  "planner_priority" integer,
  "status" text default 'READY'::text not null,
  "resolution_status" text default 'RESOLVED'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "production_process_code" text,
  "routing_override_id" uuid,
  constraint "production_demand_lines_check" CHECK (resolution_status = 'RESOLVED'::text AND product_id IS NOT NULL AND routing_revision_id IS NOT NULL OR resolution_status <> 'RESOLVED'::text),
  constraint "production_demand_lines_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_demand_lines_organization_id_source_system_sourc_key" UNIQUE (organization_id, source_system, source_order_no, source_order_line_id),
  constraint "production_demand_lines_pkey" PRIMARY KEY (id),
  constraint "production_demand_lines_production_process_code_check" CHECK (production_process_code IS NULL OR (production_process_code = ANY (ARRAY['DTG'::text, 'UNDERPRINT'::text, 'SCREEN_PRINT'::text]))),
  constraint "production_demand_lines_quantity_check" CHECK (quantity > 0::numeric),
  constraint "production_demand_lines_resolution_status_check" CHECK (resolution_status = ANY (ARRAY['RESOLVED'::text, 'PRODUCT_UNMAPPED'::text, 'ROUTING_UNMAPPED'::text, 'ROUTING_INACTIVE'::text, 'INVALID_QUANTITY'::text])),
  constraint "production_demand_lines_routing_identity_check" CHECK (resolution_status <> 'RESOLVED'::text OR routing_id IS NOT NULL AND routing_id = routing_revision_id),
  constraint "production_demand_lines_source_order_line_id_check" CHECK (NULLIF(TRIM(BOTH FROM source_order_line_id), ''::text) IS NOT NULL),
  constraint "production_demand_lines_source_order_no_check" CHECK (NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL),
  constraint "production_demand_lines_status_check" CHECK (status = ANY (ARRAY['READY'::text, 'GROUPED'::text, 'CANCELLED'::text, 'EXCEPTION'::text]))
);
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
  constraint "production_demand_release_events_action_check" CHECK (action = ANY (ARRAY['WITHDRAWN_FROM_PLANNED_DEMAND'::text, 'RELEASE_REVOKED_AFTER_PRODUCTION_START'::text, 'RELEASE_REVOKED_AFTER_COMPLETION'::text, 'CANCELLED_MO_REVIEW_REQUIRED'::text, 'INVALID_AT_CREATION'::text, 'CANNOT_PROVE'::text, 'INCREMENTAL_RECONCILIATION_REQUIRED'::text, 'RESTORED_TO_PLANNED_DEMAND'::text, 'RELEASE_REACTIVATED_AFTER_PRODUCTION_START'::text, 'RELEASE_REACTIVATED_AFTER_COMPLETION'::text, 'RELEASE_REACTIVATED_MO_CANCELLED'::text, 'RELEASE_REACTIVATION_BLOCKED'::text])),
  constraint "production_demand_release_events_event_type_check" CHECK (event_type = ANY (ARRAY['RELEASE_REVOKED_AFTER_MAPPING'::text, 'RE_RELEASED_REQUIRES_RECONCILIATION'::text, 'RELEASE_REACTIVATED'::text])),
  constraint "production_demand_release_events_pkey" PRIMARY KEY (id)
);
create table public."production_events" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "event_id" text not null,
  "event_ts_utc" timestamp with time zone not null,
  "event_ts_local" timestamp without time zone not null,
  "calendar_date" date not null,
  "operational_date" date not null,
  "hour_bucket" smallint not null,
  "shift_code" text not null,
  "area" text not null,
  "metric" text not null,
  "quantity" numeric not null,
  "unit" text not null,
  "source" text not null,
  "source_mode" text not null,
  "source_record_key" text not null,
  "quality_status" text not null,
  "import_batch_id" uuid,
  "calculation_version" text not null,
  "is_partial_period" boolean default false not null,
  "operational_shift_overtime" boolean default false not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_events_hour_bucket_check" CHECK (hour_bucket >= 0 AND hour_bucket <= 23),
  constraint "production_events_metric_check" CHECK (metric = ANY (ARRAY['DTG_PRINT'::text, 'DTG_PUTWALL_IN'::text, 'DTG_PUTWALL_OUT'::text, 'UP_IN'::text, 'UP_OUT'::text, 'SCREEN_PRINT'::text, 'SCREEN_MACHINE_HOURS'::text])),
  constraint "production_events_organization_id_source_source_record_key__key" UNIQUE (organization_id, source, source_record_key, metric),
  constraint "production_events_pkey" PRIMARY KEY (id),
  constraint "production_events_quality_status_check" CHECK (quality_status = ANY (ARRAY['COMPLETE'::text, 'PARTIAL'::text, 'PROVISIONAL'::text, 'MISSING_SOURCE'::text, 'NO_TARGET_HOURS'::text, 'OUT_OF_SHIFT'::text, 'REJECTED'::text])),
  constraint "production_events_shift_code_check" CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OUT_OF_SHIFT'::text]))
);
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
  constraint "production_order_history_pkey" PRIMARY KEY (id)
);
create table public."production_order_operation_evidence" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_order_id" uuid not null,
  "production_order_operation_id" uuid not null,
  "source_mapping_id" uuid not null,
  "source_dataset" text not null,
  "source_record_key" text not null,
  "source_audit_event_id" uuid,
  "semantics" text not null,
  "observed_at" timestamp with time zone not null,
  "quantity" numeric,
  "source_value" text not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_order_operation_ev_production_order_operation_id_key" UNIQUE (production_order_operation_id, source_dataset, source_record_key, source_mapping_id),
  constraint "production_order_operation_evidence_pkey" PRIMARY KEY (id)
);
create table public."production_order_operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_order_id" uuid not null,
  "source_routing_operation_id" uuid,
  "source_operation_id" uuid,
  "sequence" integer not null,
  "operation_code_snapshot" text not null,
  "operation_name_snapshot" text not null,
  "work_center_code_snapshot" text,
  "work_center_name_snapshot" text,
  "required" boolean default true not null,
  "setup_minutes_snapshot" numeric,
  "run_rate_snapshot" numeric,
  "queue_minutes_snapshot" numeric,
  "instructions_snapshot" text,
  "status" text default 'PENDING'::text not null,
  "planned_quantity" numeric,
  "actual_quantity" numeric default 0 not null,
  "planned_date" date,
  "planned_shift_id" uuid,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "validation_provenance" text default 'NOT_OBSERVED'::text not null,
  "validation_note" text,
  constraint "production_order_operations_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "production_order_operations_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_order_operations_pkey" PRIMARY KEY (id),
  constraint "production_order_operations_planned_quantity_check" CHECK (planned_quantity IS NULL OR planned_quantity > 0::numeric),
  constraint "production_order_operations_production_order_id_sequence_key" UNIQUE (production_order_id, sequence),
  constraint "production_order_operations_sequence_check" CHECK (sequence > 0),
  constraint "production_order_operations_status_check" CHECK (status = ANY (ARRAY['PENDING'::text, 'READY'::text, 'IN_PROGRESS'::text, 'ON_HOLD'::text, 'COMPLETED'::text, 'SKIPPED'::text])),
  constraint "production_order_operations_validation_provenance_check" CHECK (validation_provenance = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'INFERRED'::text, 'NOT_OBSERVED'::text]))
);
create table public."production_orders" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "order_no" text not null,
  "planner_priority" integer,
  "planned_date" date,
  "planned_shift_id" uuid,
  "planning_status" text default 'unplanned'::text not null,
  "special_instruction" text,
  "planner_note" text,
  "blocked_reason" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  "updated_by" uuid,
  "product_id" uuid,
  "source_order_no" text,
  "source_routing_id" uuid,
  "routing_code_snapshot" text,
  "routing_name_snapshot" text,
  "routing_revision_snapshot" integer,
  "production_status" text default 'UNROUTED'::text not null,
  "planned_quantity" numeric,
  "actual_quantity" numeric default 0 not null,
  "mo_number" text,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "split_number" integer default 1 not null,
  constraint "production_orders_actual_quantity_check" CHECK (actual_quantity >= 0::numeric),
  constraint "production_orders_check" CHECK (planning_status = 'blocked'::text OR blocked_reason IS NULL),
  constraint "production_orders_check1" CHECK (planning_status <> 'blocked'::text OR NULLIF(TRIM(BOTH FROM blocked_reason), ''::text) IS NOT NULL),
  constraint "production_orders_mo_identity_check" CHECK (source_routing_id IS NULL OR NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL),
  constraint "production_orders_mo_number_key" UNIQUE (organization_id, mo_number),
  constraint "production_orders_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_orders_pkey" PRIMARY KEY (id),
  constraint "production_orders_planned_quantity_check" CHECK (planned_quantity IS NULL OR planned_quantity >= 0::numeric),
  constraint "production_orders_planner_priority_check" CHECK (planner_priority >= 0 AND planner_priority <= 999),
  constraint "production_orders_planning_status_check" CHECK (planning_status = ANY (ARRAY['unplanned'::text, 'planned'::text, 'ready'::text, 'in_progress'::text, 'blocked'::text, 'waiting'::text, 'completed'::text, 'cancelled'::text])),
  constraint "production_orders_snapshot_complete_check" CHECK (source_routing_id IS NULL AND routing_code_snapshot IS NULL AND routing_name_snapshot IS NULL AND routing_revision_snapshot IS NULL AND production_status = 'UNROUTED'::text OR source_routing_id IS NOT NULL AND routing_code_snapshot IS NOT NULL AND routing_name_snapshot IS NOT NULL AND routing_revision_snapshot IS NOT NULL AND production_status <> 'UNROUTED'::text),
  constraint "production_orders_so_routing_split_key" UNIQUE (organization_id, source_system, source_order_no, source_routing_id, split_number),
  constraint "production_orders_split_number_check" CHECK (split_number > 0),
  constraint "production_orders_status_check" CHECK (production_status = ANY (ARRAY['UNROUTED'::text, 'PLANNED'::text, 'RELEASED'::text, 'IN_PROGRESS'::text, 'ON_HOLD'::text, 'COMPLETED'::text, 'CANCELLED'::text]))
);
create table public."production_plan_history" (
  "id" uuid default gen_random_uuid() not null,
  "production_plan_id" uuid not null,
  "action" text not null,
  "changed_by" uuid,
  "changed_by_email" text,
  "changed_at" timestamp with time zone default now() not null,
  "snapshot" jsonb not null,
  constraint "production_plan_history_pkey" PRIMARY KEY (id)
);
create table public."production_plan_items" (
  "id" uuid default gen_random_uuid() not null,
  "production_plan_id" uuid not null,
  "production_order_id" uuid not null,
  "order_no" text not null,
  "sequence" integer not null,
  "planned_units" numeric not null,
  "responsible" text,
  "special_instruction" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_plan_items_pkey" PRIMARY KEY (id),
  constraint "production_plan_items_planned_units_check" CHECK (planned_units > 0::numeric),
  constraint "production_plan_items_production_plan_id_production_order_i_key" UNIQUE (production_plan_id, production_order_id),
  constraint "production_plan_items_production_plan_id_sequence_key" UNIQUE (production_plan_id, sequence)
);
create table public."production_plans" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_date" date not null,
  "shift_template_id" uuid not null,
  "production_area_id" uuid not null,
  "status" text default 'draft'::text not null,
  "version" integer default 1 not null,
  "created_by" uuid,
  "published_by" uuid,
  "published_at" timestamp with time zone,
  "closed_by" uuid,
  "closed_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_plans_organization_id_production_date_shift_temp_key" UNIQUE (organization_id, production_date, shift_template_id, production_area_id),
  constraint "production_plans_pkey" PRIMARY KEY (id),
  constraint "production_plans_status_check" CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'closed'::text]))
);
create table public."production_process_stages" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_process_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "sequence" integer not null,
  "source_type" text not null,
  "capacity_area_code" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_process_stages_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_process_stages_pkey" PRIMARY KEY (id),
  constraint "production_process_stages_source_type_check" CHECK (source_type = ANY (ARRAY['oracle_workbank'::text, 'oracle_stock'::text, 'oracle_location'::text, 'oracle_audit'::text, 'manual'::text]))
);
create table public."production_processes" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "sequence" integer not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_processes_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_processes_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "production_processes_pkey" PRIMARY KEY (id)
);
create table public."production_reconciliation_items" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "reconciliation_run_id" uuid not null,
  "order_no" text not null,
  "legacy_area" text,
  "expected_operation_code" text,
  "canonical_operation_code" text,
  "legacy_remaining_quantity" numeric,
  "canonical_remaining_quantity" numeric,
  "quantity_variance" numeric,
  "presence_result" text not null,
  "operation_result" text not null,
  "quantity_result" text not null,
  "overall_result" text not null,
  "detail" jsonb default '{}'::jsonb not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_reconciliation_ite_reconciliation_run_id_order_n_key" UNIQUE (reconciliation_run_id, order_no, legacy_area),
  constraint "production_reconciliation_items_operation_result_check" CHECK (operation_result = ANY (ARRAY['MATCH'::text, 'MISMATCH'::text, 'NOT_COMPARABLE'::text])),
  constraint "production_reconciliation_items_overall_result_check" CHECK (overall_result = ANY (ARRAY['MATCH'::text, 'MISMATCH'::text, 'MISSING_CANONICAL'::text, 'MISSING_LEGACY'::text])),
  constraint "production_reconciliation_items_pkey" PRIMARY KEY (id),
  constraint "production_reconciliation_items_presence_result_check" CHECK (presence_result = ANY (ARRAY['BOTH'::text, 'MISSING_CANONICAL'::text, 'MISSING_LEGACY'::text])),
  constraint "production_reconciliation_items_quantity_result_check" CHECK (quantity_result = ANY (ARRAY['MATCH'::text, 'MISMATCH'::text, 'NOT_COMPARABLE'::text]))
);
create table public."production_reconciliation_runs" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid,
  "status" text default 'RUNNING'::text not null,
  "quantity_tolerance" numeric default 1 not null,
  "total_orders" integer default 0 not null,
  "matched_orders" integer default 0 not null,
  "mismatched_orders" integer default 0 not null,
  "missing_canonical_orders" integer default 0 not null,
  "missing_legacy_orders" integer default 0 not null,
  "comparable_quantity_orders" integer default 0 not null,
  "quantity_matched_orders" integer default 0 not null,
  "match_rate" numeric,
  "started_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone,
  "error_message" text,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_reconciliation_runs_pkey" PRIMARY KEY (id),
  constraint "production_reconciliation_runs_quantity_tolerance_check" CHECK (quantity_tolerance >= 0::numeric),
  constraint "production_reconciliation_runs_status_check" CHECK (status = ANY (ARRAY['RUNNING'::text, 'COMPLETED'::text, 'FAILED'::text]))
);
create table public."production_resources" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "work_center_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "resource_type" text,
  "asset_id" uuid,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_resources_code_check" CHECK (code ~ '^[A-Z0-9_-]+$'::text),
  constraint "production_resources_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "production_resources_pkey" PRIMARY KEY (id)
);
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
  constraint "production_routing_exceptions_check" CHECK ((status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text])) AND resolved_at IS NULL OR (status = ANY (ARRAY['RESOLVED'::text, 'DISMISSED'::text])) AND resolved_at IS NOT NULL),
  constraint "production_routing_exceptions_exception_type_check" CHECK (exception_type = ANY (ARRAY['SKIPPED_OPERATION'::text, 'OUT_OF_SEQUENCE'::text, 'UNKNOWN_SOURCE_STAGE'::text, 'UNEXPECTED_OPERATION'::text, 'ROUTING_MISMATCH'::text, 'SOURCE_QUANTITY_CHANGE'::text, 'SOURCE_ORDER_CANCELLED'::text, 'AMBIGUOUS_SOURCE_EVIDENCE'::text])),
  constraint "production_routing_exceptions_pkey" PRIMARY KEY (id),
  constraint "production_routing_exceptions_status_check" CHECK (status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text, 'RESOLVED'::text, 'DISMISSED'::text]))
);
create table public."production_stage_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_area_id" uuid not null,
  "source_field" text not null,
  "match_pattern" text not null,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "production_stage_mappings_organization_id_source_field_matc_key" UNIQUE (organization_id, source_field, match_pattern),
  constraint "production_stage_mappings_pkey" PRIMARY KEY (id),
  constraint "production_stage_mappings_source_field_check" CHECK (source_field = ANY (ARRAY['from_zone'::text, 'from_location'::text]))
);
create table public."production_stage_source_rules" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "production_stage_id" uuid not null,
  "source_dataset" text not null,
  "source_field" text not null,
  "match_type" text not null,
  "match_value" text not null,
  "priority" integer default 100 not null,
  "validation_status" text default 'VALIDATED'::text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "production_stage_source_rules_match_type_check" CHECK (match_type = ANY (ARRAY['exact'::text, 'contains'::text, 'starts_with'::text, 'ends_with'::text, 'regex'::text])),
  constraint "production_stage_source_rules_pkey" PRIMARY KEY (id),
  constraint "production_stage_source_rules_validation_status_check" CHECK (validation_status = ANY (ARRAY['VALIDATED'::text, 'REQUIRES_VALIDATION'::text]))
);
create table public."products" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sku" text not null,
  "description" text,
  "product_family_id" uuid,
  "product_type_id" uuid,
  "decoration_method" text,
  "default_routing_id" uuid,
  "source_system" text,
  "source_product_code" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "products_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "products_organization_id_sku_key" UNIQUE (organization_id, sku),
  constraint "products_pkey" PRIMARY KEY (id)
);
create table public."quantity_conversion_rules" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "product_group_pattern" text default '%'::text not null,
  "multiplier" numeric default 1 not null,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  constraint "quantity_conversion_rules_organization_id_product_group_pat_key" UNIQUE (organization_id, product_group_pattern),
  constraint "quantity_conversion_rules_pkey" PRIMARY KEY (id)
);
create table public."resource_capacity_rules" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "process" text not null,
  "resource_code" text not null,
  "shift_code" text,
  "max_resources" numeric not null,
  "condition_context" jsonb default '{}'::jsonb not null,
  "effective_from" date not null,
  "effective_to" date,
  "active" boolean default true not null,
  "calculation_version" text default 'ERP_KPI_V1'::text not null,
  constraint "resource_capacity_rules_check" CHECK (effective_to IS NULL OR effective_to >= effective_from),
  constraint "resource_capacity_rules_max_resources_check" CHECK (max_resources >= 0::numeric),
  constraint "resource_capacity_rules_organization_id_resource_code_shift_key" UNIQUE (organization_id, resource_code, shift_code, effective_from),
  constraint "resource_capacity_rules_pkey" PRIMARY KEY (id),
  constraint "resource_capacity_rules_process_check" CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text])),
  constraint "resource_capacity_rules_shift_code_check" CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text]))
);
create table public."routing_operations" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "routing_id" uuid not null,
  "sequence" integer not null,
  "operation_id" uuid not null,
  "work_center_id" uuid,
  "required" boolean default true not null,
  "setup_minutes" numeric,
  "run_rate" numeric,
  "queue_minutes" numeric,
  "capacity_profile_id" uuid,
  "instructions" text,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "routing_operations_pkey" PRIMARY KEY (id),
  constraint "routing_operations_queue_minutes_check" CHECK (queue_minutes IS NULL OR queue_minutes >= 0::numeric),
  constraint "routing_operations_routing_id_sequence_key" UNIQUE (routing_id, sequence),
  constraint "routing_operations_run_rate_check" CHECK (run_rate IS NULL OR run_rate > 0::numeric),
  constraint "routing_operations_sequence_check" CHECK (sequence > 0),
  constraint "routing_operations_setup_minutes_check" CHECK (setup_minutes IS NULL OR setup_minutes >= 0::numeric)
);
create table public."routings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "revision" integer default 1 not null,
  "status" text default 'DRAFT'::text not null,
  "effective_from" date,
  "effective_to" date,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "routings_check" CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from),
  constraint "routings_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "routings_organization_id_code_revision_key" UNIQUE (organization_id, code, revision),
  constraint "routings_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "routings_pkey" PRIMARY KEY (id),
  constraint "routings_revision_check" CHECK (revision > 0),
  constraint "routings_status_check" CHECK (status = ANY (ARRAY['DRAFT'::text, 'ACTIVE'::text, 'INACTIVE'::text]))
);
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
  constraint "sales_order_release_history_organization_id_source_order_no_key" UNIQUE (organization_id, source_order_no, new_release_status, source_sync_batch_id),
  constraint "sales_order_release_history_pkey" PRIMARY KEY (id)
);
create table public."screen_print_jobs" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "order_no" text,
  "job_name" text not null,
  "customer_name" text,
  "planned_quantity" numeric not null,
  "completed_quantity" numeric default 0 not null,
  "status" text default 'todo'::text not null,
  "planned_date" date,
  "shift_code" text,
  "line_name" text,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "priority" integer,
  "notes" text,
  "created_by" uuid,
  "updated_by" uuid,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "screen_print_jobs_check" CHECK (completed_quantity <= planned_quantity),
  constraint "screen_print_jobs_completed_quantity_check" CHECK (completed_quantity >= 0::numeric),
  constraint "screen_print_jobs_pkey" PRIMARY KEY (id),
  constraint "screen_print_jobs_planned_quantity_check" CHECK (planned_quantity >= 0::numeric),
  constraint "screen_print_jobs_status_check" CHECK (status = ANY (ARRAY['todo'::text, 'in_production'::text, 'completed'::text, 'cancelled'::text]))
);
create table public."shift_rules" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "weekday" smallint not null,
  "shift_code" text not null,
  "display_name" text not null,
  "start_time" time without time zone not null,
  "end_time" time without time zone not null,
  "cross_midnight" boolean default false not null,
  "tolerance_minutes" integer default 20 not null,
  "activation_confirmation_minutes" integer default 150 not null,
  "active" boolean default true not null,
  "effective_from" date not null,
  "effective_to" date,
  constraint "shift_rules_activation_confirmation_minutes_check" CHECK (activation_confirmation_minutes >= 0 AND activation_confirmation_minutes <= 720),
  constraint "shift_rules_check" CHECK (effective_to IS NULL OR effective_to >= effective_from),
  constraint "shift_rules_organization_id_weekday_shift_code_effective_fr_key" UNIQUE (organization_id, weekday, shift_code, effective_from),
  constraint "shift_rules_pkey" PRIMARY KEY (id),
  constraint "shift_rules_shift_code_check" CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text])),
  constraint "shift_rules_tolerance_minutes_check" CHECK (tolerance_minutes >= 0 AND tolerance_minutes <= 180),
  constraint "shift_rules_weekday_check" CHECK (weekday >= 1 AND weekday <= 7)
);
create table public."shift_templates" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "starts_at" time without time zone not null,
  "ends_at" time without time zone not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "day_group" text default 'all_days'::text not null,
  "crosses_midnight" boolean default false not null,
  "scheduled_hours" numeric not null,
  constraint "shift_scheduled_hours_positive" CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric),
  constraint "shift_templates_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "shift_templates_pkey" PRIMARY KEY (id)
);
create table public."source_audit_events" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_audit_id" text,
  "order_no" text not null,
  "username" text,
  "from_zone" text,
  "to_zone" text,
  "from_location" text,
  "to_location" text,
  "product" text,
  "from_pack_id" text,
  "to_pack_id" text,
  "source_qty" numeric,
  "source_weight" numeric,
  "production_units" numeric not null,
  "event_at" timestamp with time zone not null,
  "raw_hash" text not null,
  "imported_at" timestamp with time zone default now() not null,
  "queue" text,
  "task" text,
  constraint "source_audit_events_organization_id_raw_hash_key" UNIQUE (organization_id, raw_hash),
  constraint "source_audit_events_organization_id_source_audit_id_key" UNIQUE (organization_id, source_audit_id),
  constraint "source_audit_events_pkey" PRIMARY KEY (id)
);
create table public."source_operation_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_field" text not null,
  "match_type" text not null,
  "match_value" text not null,
  "operation_id" uuid not null,
  "completion_semantics" text not null,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_operation_mappings_completion_semantics_check" CHECK (completion_semantics = ANY (ARRAY['CURRENT_LOCATION'::text, 'ENTERED_OPERATION'::text, 'COMPLETED_OPERATION'::text, 'MOVED_FROM_OPERATION'::text, 'MOVED_TO_OPERATION'::text])),
  constraint "source_operation_mappings_match_type_check" CHECK (match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text])),
  constraint "source_operation_mappings_organization_id_source_system_sou_key" UNIQUE (organization_id, source_system, source_dataset, source_field, match_type, match_value, completion_semantics),
  constraint "source_operation_mappings_pkey" PRIMARY KEY (id),
  constraint "source_operation_mappings_priority_check" CHECK (priority >= 0),
  constraint "source_operation_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['AUDIT'::text, 'WORKBANK'::text, 'STOCK'::text]))
);
create table public."source_operational_code_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_field" text not null,
  "source_operational_code" text not null,
  "manufacturing_process" text,
  "operational_stage" text,
  "release_status" text,
  "eligibility_status" text,
  "blocker_reason" text,
  "mo_scope" text not null,
  "confidence" text not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_operational_code_mappi_organization_id_source_system_key" UNIQUE (organization_id, source_system, source_dataset, source_field, source_operational_code),
  constraint "source_operational_code_mappings_confidence_check" CHECK (confidence = ANY (ARRAY['SOURCE_CONFIRMED'::text, 'DETERMINISTIC'::text])),
  constraint "source_operational_code_mappings_mo_scope_check" CHECK (mo_scope = ANY (ARRAY['CURRENT_SUPPORTED_PROCESS'::text, 'PROCESS_NOT_YET_SUPPORTED'::text, 'NO_MO_REQUIRED'::text, 'NOT_APPLICABLE'::text])),
  constraint "source_operational_code_mappings_pkey" PRIMARY KEY (id),
  constraint "source_operational_code_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['WORKBANK'::text, 'AUDIT'::text])),
  constraint "source_operational_code_mappings_source_field_check" CHECK (source_field = ANY (ARRAY['queue'::text, 'from_location'::text, 'to_location'::text]))
);
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
  constraint "source_order_release_lines_organization_id_source_system_so_key" UNIQUE (organization_id, source_system, source_order_no, source_line_id),
  constraint "source_order_release_lines_pkey" PRIMARY KEY (id),
  constraint "source_order_release_lines_source_presence_check" CHECK (source_presence = ANY (ARRAY['ACTIVE'::text, 'NOT_SEEN_IN_LATEST_COMPLETE_SNAPSHOT'::text, 'SOURCE_INACTIVE'::text]))
);
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
  constraint "source_orders_pkey" PRIMARY KEY (id),
  constraint "source_orders_sync_batch_id_order_no_key" UNIQUE (sync_batch_id, order_no)
);
create table public."source_release_order_lines" (
  "id" bigint generated always as identity not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid not null,
  "order_no" text not null,
  "line_number" text not null,
  "product" text,
  "client" text,
  "qty_lcd" numeric default 0 not null,
  "orig_ref3" text,
  "group_code" text,
  "product_name" text,
  "source_updated_at" timestamp with time zone,
  "created_at" timestamp with time zone default now() not null,
  constraint "source_release_order_lines_pkey" PRIMARY KEY (id),
  constraint "source_release_order_lines_sync_batch_id_order_no_line_numb_key" UNIQUE (sync_batch_id, order_no, line_number)
);
create table public."source_stock_items" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid not null,
  "product" text not null,
  "pack_id" text not null,
  "location" text not null,
  "source_timestamp" timestamp with time zone,
  "source_qty" numeric,
  "source_weight" numeric,
  "production_units" numeric not null,
  "created_at" timestamp with time zone default now() not null,
  "source_zone" text,
  constraint "source_stock_items_pkey" PRIMARY KEY (id)
);
create table public."source_task_mappings" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "source_system" text default 'ORACLE_WMS'::text not null,
  "source_dataset" text not null,
  "source_task" text not null,
  "production_process_id" uuid not null,
  "operation_id" uuid,
  "match_type" text default 'EXACT'::text not null,
  "context_field" text,
  "context_match_type" text,
  "context_value" text,
  "priority" integer default 100 not null,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "source_task_mappings_check" CHECK (context_field IS NULL AND context_match_type IS NULL AND context_value IS NULL OR context_field IS NOT NULL AND context_match_type IS NOT NULL AND context_value IS NOT NULL),
  constraint "source_task_mappings_context_field_check" CHECK (context_field IS NULL OR (context_field = ANY (ARRAY['queue'::text, 'from_zone'::text, 'to_zone'::text, 'from_location'::text, 'to_location'::text]))),
  constraint "source_task_mappings_context_match_type_check" CHECK (context_match_type IS NULL OR (context_match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text]))),
  constraint "source_task_mappings_match_type_check" CHECK (match_type = ANY (ARRAY['EXACT'::text, 'PREFIX'::text, 'SUFFIX'::text, 'LIKE'::text])),
  constraint "source_task_mappings_pkey" PRIMARY KEY (id),
  constraint "source_task_mappings_priority_check" CHECK (priority >= 0),
  constraint "source_task_mappings_source_dataset_check" CHECK (source_dataset = ANY (ARRAY['WORKBANK'::text, 'AUDIT'::text]))
);
create table public."source_workbank_items" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "sync_batch_id" uuid not null,
  "source_row_id" text,
  "order_no" text not null,
  "customer_code" text,
  "customer_name" text,
  "source_due_at" timestamp with time zone,
  "from_location" text,
  "from_zone" text,
  "to_location" text,
  "from_pack_id" text,
  "to_pack_id" text,
  "source_priority" integer,
  "product_code" text,
  "product_description" text,
  "product_group" text,
  "source_qty" numeric,
  "source_weight" numeric,
  "production_units" numeric not null,
  "queue" text not null,
  "task" text,
  "created_at" timestamp with time zone default now() not null,
  "prints_per_garment" numeric,
  constraint "source_workbank_items_pkey" PRIMARY KEY (id)
);
create table public."staffing_layout_lines" (
  "id" uuid default gen_random_uuid() not null,
  "staffing_layout_id" uuid not null,
  "production_area_id" uuid not null,
  "shift_template_id" uuid not null,
  "day_of_week" smallint,
  "operator_count" numeric not null,
  "machine_count" numeric,
  "scheduled_hours" numeric not null,
  "hourly_rate" numeric,
  "efficiency" numeric,
  "created_at" timestamp with time zone default now() not null,
  constraint "staffing_layout_lines_day_of_week_check" CHECK (day_of_week >= 1 AND day_of_week <= 7),
  constraint "staffing_layout_lines_efficiency_check" CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric),
  constraint "staffing_layout_lines_hourly_rate_check" CHECK (hourly_rate >= 0::numeric),
  constraint "staffing_layout_lines_machine_count_check" CHECK (machine_count >= 0::numeric),
  constraint "staffing_layout_lines_operator_count_check" CHECK (operator_count >= 0::numeric),
  constraint "staffing_layout_lines_pkey" PRIMARY KEY (id),
  constraint "staffing_layout_lines_scheduled_hours_check" CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)
);
create table public."staffing_layouts" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "name" text not null,
  "effective_from" date default CURRENT_DATE not null,
  "effective_to" date,
  "active" boolean default false not null,
  "source" text default 'USER'::text not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "staffing_layouts_check" CHECK (effective_to IS NULL OR effective_to >= effective_from),
  constraint "staffing_layouts_organization_id_name_key" UNIQUE (organization_id, name),
  constraint "staffing_layouts_pkey" PRIMARY KEY (id)
);
create table public."sync_agent_heartbeat" (
  "organization_id" uuid not null,
  "agent_id" text not null,
  "last_seen_at" timestamp with time zone default now() not null,
  "version" text not null,
  "hostname" text,
  "status" text not null,
  "last_error" text,
  "last_sync_attempt_at" timestamp with time zone,
  "last_success_at" timestamp with time zone,
  "next_expected_sync_at" timestamp with time zone,
  "current_run_id" uuid,
  constraint "sync_agent_heartbeat_pkey" PRIMARY KEY (organization_id, agent_id)
);
create table public."sync_batches" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "started_at" timestamp with time zone default now() not null,
  "completed_at" timestamp with time zone,
  "status" text not null,
  "orders_count" integer default 0 not null,
  "workbank_count" integer default 0 not null,
  "stock_count" integer default 0 not null,
  "audit_new_count" integer default 0 not null,
  "error_message" text,
  "connector_version" text,
  "created_at" timestamp with time zone default now() not null,
  "release_line_count" integer default 0 not null,
  constraint "sync_batches_pkey" PRIMARY KEY (id),
  constraint "sync_batches_status_check" CHECK (status = ANY (ARRAY['running'::text, 'completed'::text, 'failed'::text]))
);
create table public."sync_refresh_requests" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "requested_by" uuid,
  "status" text default 'QUEUED'::text not null,
  "requested_at" timestamp with time zone default now() not null,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "sync_run_id" uuid,
  "failure_reason" text,
  constraint "sync_refresh_requests_pkey" PRIMARY KEY (id),
  constraint "sync_refresh_requests_status_check" CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text]))
);
create table public."sync_runs" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "refresh_request_id" uuid,
  "trigger_type" text not null,
  "status" text not null,
  "requested_at" timestamp with time zone default now() not null,
  "started_at" timestamp with time zone,
  "completed_at" timestamp with time zone,
  "duration_ms" bigint,
  "agent_id" text,
  "connector_version" text,
  "batch_id" uuid,
  "orders_count" integer default 0 not null,
  "workbank_count" integer default 0 not null,
  "stock_count" integer default 0 not null,
  "audit_count" integer default 0 not null,
  "failure_reason" text,
  "created_at" timestamp with time zone default now() not null,
  constraint "sync_runs_pkey" PRIMARY KEY (id),
  constraint "sync_runs_status_check" CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text])),
  constraint "sync_runs_trigger_type_check" CHECK (trigger_type = ANY (ARRAY['AUTOMATIC'::text, 'MANUAL'::text]))
);
create table public."work_centers" (
  "id" uuid default gen_random_uuid() not null,
  "organization_id" uuid not null,
  "code" text not null,
  "name" text not null,
  "description" text,
  "active" boolean default true not null,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null,
  constraint "work_centers_code_check" CHECK (code ~ '^[A-Z0-9_]+$'::text),
  constraint "work_centers_organization_id_code_key" UNIQUE (organization_id, code),
  constraint "work_centers_organization_id_id_key" UNIQUE (organization_id, id),
  constraint "work_centers_pkey" PRIMARY KEY (id)
);
alter table public."active_wip_backfill_runs" add constraint "active_wip_backfill_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."active_wip_coverage_exceptions" add constraint "active_wip_coverage_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."capacity_legacy_overrides" add constraint "capacity_legacy_overrides_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."capacity_legacy_overrides" add constraint "capacity_legacy_overrides_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."capacity_profiles" add constraint "capacity_profiles_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."capacity_profiles" add constraint "capacity_profiles_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."capacity_profiles" add constraint "capacity_profiles_shift_template_id_fkey" FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id);
alter table public."capacity_scenario_lines" add constraint "capacity_scenario_lines_capacity_scenario_id_fkey" FOREIGN KEY (capacity_scenario_id) REFERENCES capacity_scenarios(id) ON DELETE CASCADE;
alter table public."capacity_scenario_lines" add constraint "capacity_scenario_lines_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."capacity_scenario_lines" add constraint "capacity_scenario_lines_shift_template_id_fkey" FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id);
alter table public."capacity_scenarios" add constraint "capacity_scenarios_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."deputy_import_batches" add constraint "deputy_import_batches_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."deputy_raw_timesheets" add constraint "deputy_raw_timesheets_import_batch_id_fkey" FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id);
alter table public."deputy_raw_timesheets" add constraint "deputy_raw_timesheets_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."kpi_definitions" add constraint "kpi_definitions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."kpi_rate_rules" add constraint "kpi_rate_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."kpi_results" add constraint "kpi_results_kpi_definition_id_fkey" FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id);
alter table public."kpi_results" add constraint "kpi_results_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."kpi_results" add constraint "kpi_results_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."kpi_results" add constraint "kpi_results_shift_id_fkey" FOREIGN KEY (shift_id) REFERENCES shift_templates(id);
alter table public."kpi_targets" add constraint "kpi_targets_kpi_definition_id_fkey" FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id);
alter table public."kpi_targets" add constraint "kpi_targets_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."kpi_targets" add constraint "kpi_targets_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."kpi_targets" add constraint "kpi_targets_shift_id_fkey" FOREIGN KEY (shift_id) REFERENCES shift_templates(id);
alter table public."labour_segments" add constraint "labour_segments_import_batch_id_fkey" FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id);
alter table public."labour_segments" add constraint "labour_segments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."labour_segments" add constraint "labour_segments_source_timesheet_row_id_fkey" FOREIGN KEY (source_timesheet_row_id) REFERENCES deputy_raw_timesheets(id);
alter table public."maintenance_asset_categories" add constraint "maintenance_asset_categories_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_asset_code_sequences" add constraint "maintenance_asset_code_sequences_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_asset_installations" add constraint "maintenance_asset_installations_host_asset_id_fkey" FOREIGN KEY (host_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_asset_installations" add constraint "maintenance_asset_installations_host_system_asset_id_fkey" FOREIGN KEY (host_system_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_asset_installations" add constraint "maintenance_asset_installations_movable_asset_id_fkey" FOREIGN KEY (movable_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_asset_installations" add constraint "maintenance_asset_installations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_asset_prefixes" add constraint "maintenance_asset_prefixes_category_id_fkey" FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id);
alter table public."maintenance_asset_prefixes" add constraint "maintenance_asset_prefixes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_category_id_fkey" FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_installed_work_order_id_fkey" FOREIGN KEY (installed_work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_parent_asset_id_fkey" FOREIGN KEY (parent_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_prefix_id_fkey" FOREIGN KEY (prefix_id) REFERENCES maintenance_asset_prefixes(id);
alter table public."maintenance_assets" add constraint "maintenance_assets_removed_work_order_id_fkey" FOREIGN KEY (removed_work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_attachments" add constraint "maintenance_attachments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_attachments" add constraint "maintenance_attachments_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_audit_log" add constraint "maintenance_audit_log_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_component_code_sequences" add constraint "maintenance_component_code_sequences_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_component_code_sequences" add constraint "maintenance_component_code_sequences_parent_asset_id_fkey" FOREIGN KEY (parent_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_component_prefixes" add constraint "maintenance_component_prefixes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_affected_asset_id_fkey" FOREIGN KEY (affected_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_host_asset_id_fkey" FOREIGN KEY (host_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_host_system_asset_id_fkey" FOREIGN KEY (host_system_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_downtime_events" add constraint "maintenance_downtime_events_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_import_batches" add constraint "maintenance_import_batches_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_import_staging" add constraint "maintenance_import_staging_batch_id_fkey" FOREIGN KEY (batch_id) REFERENCES maintenance_import_batches(id) ON DELETE CASCADE;
alter table public."maintenance_import_staging" add constraint "maintenance_import_staging_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_inventory_locations" add constraint "maintenance_inventory_locations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_inventory_transactions" add constraint "maintenance_inventory_transactions_location_id_fkey" FOREIGN KEY (location_id) REFERENCES maintenance_inventory_locations(id);
alter table public."maintenance_inventory_transactions" add constraint "maintenance_inventory_transactions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_inventory_transactions" add constraint "maintenance_inventory_transactions_part_id_fkey" FOREIGN KEY (part_id) REFERENCES maintenance_parts(id);
alter table public."maintenance_inventory_transactions" add constraint "maintenance_inventory_transactions_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_members" add constraint "maintenance_members_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_members" add constraint "maintenance_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."maintenance_parts" add constraint "maintenance_parts_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_preventive_plan_tasks" add constraint "maintenance_preventive_plan_tasks_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_preventive_plan_tasks" add constraint "maintenance_preventive_plan_tasks_preventive_plan_id_fkey" FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id);
alter table public."maintenance_preventive_plans" add constraint "maintenance_preventive_plans_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_preventive_plans" add constraint "maintenance_preventive_plans_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_order_checklist" add constraint "maintenance_work_order_checklist_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_order_checklist" add constraint "maintenance_work_order_checklist_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_work_order_comments" add constraint "maintenance_work_order_comments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_order_comments" add constraint "maintenance_work_order_comments_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_work_order_history" add constraint "maintenance_work_order_history_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_order_history" add constraint "maintenance_work_order_history_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_work_order_labor" add constraint "maintenance_work_order_labor_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_order_labor" add constraint "maintenance_work_order_labor_work_order_id_fkey" FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."maintenance_work_orders" add constraint "maintenance_wo_pm_fk" FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id);
alter table public."maintenance_work_orders" add constraint "maintenance_work_orders_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_work_orders" add constraint "maintenance_work_orders_component_asset_id_fkey" FOREIGN KEY (component_asset_id) REFERENCES maintenance_assets(id);
alter table public."maintenance_work_orders" add constraint "maintenance_work_orders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."maintenance_work_orders" add constraint "maintenance_work_orders_source_pm_work_order_id_fkey" FOREIGN KEY (source_pm_work_order_id) REFERENCES maintenance_work_orders(id);
alter table public."manufacturing_order_lines" add constraint "manufacturing_order_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."manufacturing_order_lines" add constraint "manufacturing_order_lines_organization_id_manufacturing_or_fkey" FOREIGN KEY (organization_id, manufacturing_order_id) REFERENCES production_orders(organization_id, id) ON DELETE RESTRICT;
alter table public."manufacturing_order_lines" add constraint "manufacturing_order_lines_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id);
alter table public."manufacturing_order_lines" add constraint "manufacturing_order_lines_organization_id_production_deman_fkey" FOREIGN KEY (organization_id, production_demand_line_id) REFERENCES production_demand_lines(organization_id, id);
alter table public."manufacturing_order_lines" add constraint "manufacturing_order_lines_organization_id_routing_revision_fkey" FOREIGN KEY (organization_id, routing_revision_id) REFERENCES routings(organization_id, id);
alter table public."operations" add constraint "operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."oracle_line_ingestion_runs" add constraint "oracle_line_ingestion_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."oracle_line_ingestion_runs" add constraint "oracle_line_ingestion_runs_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."oracle_line_ingestion_staging" add constraint "oracle_line_ingestion_staging_ingestion_run_id_fkey" FOREIGN KEY (ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id) ON DELETE CASCADE;
alter table public."oracle_line_ingestion_staging" add constraint "oracle_line_ingestion_staging_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."product_families" add constraint "product_families_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."product_mapping_resolution_audit" add constraint "product_mapping_resolution_audit_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."product_mapping_resolution_audit" add constraint "product_mapping_resolution_audit_source_ingestion_run_id_fkey" FOREIGN KEY (source_ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id);
alter table public."product_routing_assignments" add constraint "product_routing_assignments_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."product_routing_assignments" add constraint "product_routing_assignments_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id);
alter table public."product_routing_assignments" add constraint "product_routing_assignments_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id);
alter table public."product_source_mappings" add constraint "product_source_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."product_source_mappings" add constraint "product_source_mappings_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id);
alter table public."product_source_mappings" add constraint "product_source_mappings_source_ingestion_run_id_fkey" FOREIGN KEY (source_ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id);
alter table public."product_types" add constraint "product_types_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_areas" add constraint "production_areas_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_demand_exceptions" add constraint "production_demand_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_demand_exceptions" add constraint "production_demand_exceptions_organization_id_production_de_fkey" FOREIGN KEY (organization_id, production_demand_line_id) REFERENCES production_demand_lines(organization_id, id) ON DELETE CASCADE;
alter table public."production_demand_lines" add constraint "production_demand_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_demand_lines" add constraint "production_demand_lines_organization_id_product_id_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id);
alter table public."production_demand_lines" add constraint "production_demand_lines_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id);
alter table public."production_demand_lines" add constraint "production_demand_lines_organization_id_routing_revision_i_fkey" FOREIGN KEY (organization_id, routing_revision_id) REFERENCES routings(organization_id, id);
alter table public."production_demand_lines" add constraint "production_demand_lines_routing_override_fkey" FOREIGN KEY (organization_id, routing_override_id) REFERENCES routings(organization_id, id);
alter table public."production_demand_release_events" add constraint "production_demand_release_even_manufacturing_order_line_id_fkey" FOREIGN KEY (manufacturing_order_line_id) REFERENCES manufacturing_order_lines(id);
alter table public."production_demand_release_events" add constraint "production_demand_release_events_event_snapshot_run_id_fkey" FOREIGN KEY (event_snapshot_run_id) REFERENCES oracle_line_ingestion_runs(id);
alter table public."production_demand_release_events" add constraint "production_demand_release_events_manufacturing_order_id_fkey" FOREIGN KEY (manufacturing_order_id) REFERENCES production_orders(id);
alter table public."production_demand_release_events" add constraint "production_demand_release_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_demand_release_events" add constraint "production_demand_release_events_original_snapshot_run_id_fkey" FOREIGN KEY (original_snapshot_run_id) REFERENCES oracle_line_ingestion_runs(id);
alter table public."production_demand_release_events" add constraint "production_demand_release_events_production_demand_line_id_fkey" FOREIGN KEY (production_demand_line_id) REFERENCES production_demand_lines(id);
alter table public."production_events" add constraint "production_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_order_history" add constraint "production_order_history_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_order_history" add constraint "production_order_history_production_order_id_fkey" FOREIGN KEY (production_order_id) REFERENCES production_orders(id);
alter table public."production_order_operation_evidence" add constraint "production_order_operation_e_organization_id_production_o_fkey1" FOREIGN KEY (organization_id, production_order_operation_id) REFERENCES production_order_operations(organization_id, id) ON DELETE CASCADE;
alter table public."production_order_operation_evidence" add constraint "production_order_operation_ev_organization_id_production_o_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE;
alter table public."production_order_operation_evidence" add constraint "production_order_operation_evidence_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_order_operation_evidence" add constraint "production_order_operation_evidence_source_audit_event_id_fkey" FOREIGN KEY (source_audit_event_id) REFERENCES source_audit_events(id);
alter table public."production_order_operation_evidence" add constraint "production_order_operation_evidence_source_mapping_id_fkey" FOREIGN KEY (source_mapping_id) REFERENCES source_operation_mappings(id);
alter table public."production_order_operations" add constraint "production_order_operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_order_operations" add constraint "production_order_operations_organization_id_production_ord_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE;
alter table public."production_order_operations" add constraint "production_order_operations_planned_shift_id_fkey" FOREIGN KEY (planned_shift_id) REFERENCES shift_templates(id);
alter table public."production_orders" add constraint "production_orders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_orders" add constraint "production_orders_planned_shift_id_fkey" FOREIGN KEY (planned_shift_id) REFERENCES shift_templates(id);
alter table public."production_orders" add constraint "production_orders_product_fkey" FOREIGN KEY (organization_id, product_id) REFERENCES products(organization_id, id);
alter table public."production_plan_history" add constraint "production_plan_history_production_plan_id_fkey" FOREIGN KEY (production_plan_id) REFERENCES production_plans(id);
alter table public."production_plan_items" add constraint "production_plan_items_production_order_id_fkey" FOREIGN KEY (production_order_id) REFERENCES production_orders(id);
alter table public."production_plan_items" add constraint "production_plan_items_production_plan_id_fkey" FOREIGN KEY (production_plan_id) REFERENCES production_plans(id) ON DELETE CASCADE;
alter table public."production_plans" add constraint "production_plans_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_plans" add constraint "production_plans_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."production_plans" add constraint "production_plans_shift_template_id_fkey" FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id);
alter table public."production_process_stages" add constraint "production_process_stages_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_process_stages" add constraint "production_process_stages_production_process_id_fkey" FOREIGN KEY (production_process_id) REFERENCES production_processes(id);
alter table public."production_processes" add constraint "production_processes_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_reconciliation_items" add constraint "production_reconciliation_items_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_reconciliation_items" add constraint "production_reconciliation_items_reconciliation_run_id_fkey" FOREIGN KEY (reconciliation_run_id) REFERENCES production_reconciliation_runs(id) ON DELETE CASCADE;
alter table public."production_reconciliation_runs" add constraint "production_reconciliation_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_reconciliation_runs" add constraint "production_reconciliation_runs_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."production_resources" add constraint "production_resources_asset_id_fkey" FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id);
alter table public."production_resources" add constraint "production_resources_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_resources" add constraint "production_resources_organization_id_work_center_id_fkey" FOREIGN KEY (organization_id, work_center_id) REFERENCES work_centers(organization_id, id);
alter table public."production_routing_exceptions" add constraint "production_routing_exception_organization_id_production_o_fkey1" FOREIGN KEY (organization_id, production_order_operation_id) REFERENCES production_order_operations(organization_id, id) ON DELETE CASCADE;
alter table public."production_routing_exceptions" add constraint "production_routing_exceptions_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_routing_exceptions" add constraint "production_routing_exceptions_organization_id_production_o_fkey" FOREIGN KEY (organization_id, production_order_id) REFERENCES production_orders(organization_id, id) ON DELETE CASCADE;
alter table public."production_stage_mappings" add constraint "production_stage_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_stage_mappings" add constraint "production_stage_mappings_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."production_stage_source_rules" add constraint "production_stage_source_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."production_stage_source_rules" add constraint "production_stage_source_rules_production_stage_id_fkey" FOREIGN KEY (production_stage_id) REFERENCES production_process_stages(id);
alter table public."products" add constraint "products_default_routing_organization_fkey" FOREIGN KEY (organization_id, default_routing_id) REFERENCES routings(organization_id, id);
alter table public."products" add constraint "products_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."products" add constraint "products_organization_id_product_family_id_fkey" FOREIGN KEY (organization_id, product_family_id) REFERENCES product_families(organization_id, id);
alter table public."products" add constraint "products_organization_id_product_type_id_fkey" FOREIGN KEY (organization_id, product_type_id) REFERENCES product_types(organization_id, id);
alter table public."quantity_conversion_rules" add constraint "quantity_conversion_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."resource_capacity_rules" add constraint "resource_capacity_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."routing_operations" add constraint "routing_operations_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."routing_operations" add constraint "routing_operations_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id);
alter table public."routing_operations" add constraint "routing_operations_organization_id_routing_id_fkey" FOREIGN KEY (organization_id, routing_id) REFERENCES routings(organization_id, id) ON DELETE CASCADE;
alter table public."routing_operations" add constraint "routing_operations_organization_id_work_center_id_fkey" FOREIGN KEY (organization_id, work_center_id) REFERENCES work_centers(organization_id, id);
alter table public."routings" add constraint "routings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sales_order_release_history" add constraint "sales_order_release_history_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sales_order_release_history" add constraint "sales_order_release_history_source_sync_batch_id_fkey" FOREIGN KEY (source_sync_batch_id) REFERENCES sync_batches(id);
alter table public."screen_print_jobs" add constraint "screen_print_jobs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."shift_rules" add constraint "shift_rules_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."shift_templates" add constraint "shift_templates_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_audit_events" add constraint "source_audit_events_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_operation_mappings" add constraint "source_operation_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_operation_mappings" add constraint "source_operation_mappings_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id);
alter table public."source_operational_code_mappings" add constraint "source_operational_code_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_order_release_lines" add constraint "source_order_release_lines_ingestion_run_fkey" FOREIGN KEY (ingestion_run_id) REFERENCES oracle_line_ingestion_runs(id);
alter table public."source_order_release_lines" add constraint "source_order_release_lines_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_order_release_lines" add constraint "source_order_release_lines_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."source_orders" add constraint "source_orders_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_orders" add constraint "source_orders_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."source_release_order_lines" add constraint "source_release_order_lines_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id) ON DELETE CASCADE;
alter table public."source_stock_items" add constraint "source_stock_items_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_stock_items" add constraint "source_stock_items_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."source_task_mappings" add constraint "source_task_mappings_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_task_mappings" add constraint "source_task_mappings_organization_id_operation_id_fkey" FOREIGN KEY (organization_id, operation_id) REFERENCES operations(organization_id, id);
alter table public."source_task_mappings" add constraint "source_task_mappings_organization_id_production_process_id_fkey" FOREIGN KEY (organization_id, production_process_id) REFERENCES production_processes(organization_id, id);
alter table public."source_workbank_items" add constraint "source_workbank_items_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."source_workbank_items" add constraint "source_workbank_items_sync_batch_id_fkey" FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id);
alter table public."staffing_layout_lines" add constraint "staffing_layout_lines_production_area_id_fkey" FOREIGN KEY (production_area_id) REFERENCES production_areas(id);
alter table public."staffing_layout_lines" add constraint "staffing_layout_lines_shift_template_id_fkey" FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id);
alter table public."staffing_layout_lines" add constraint "staffing_layout_lines_staffing_layout_id_fkey" FOREIGN KEY (staffing_layout_id) REFERENCES staffing_layouts(id) ON DELETE CASCADE;
alter table public."staffing_layouts" add constraint "staffing_layouts_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sync_agent_heartbeat" add constraint "sync_agent_heartbeat_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sync_batches" add constraint "sync_batches_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sync_refresh_requests" add constraint "sync_refresh_requests_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sync_refresh_requests" add constraint "sync_refresh_requests_sync_run_id_fkey" FOREIGN KEY (sync_run_id) REFERENCES sync_runs(id);
alter table public."sync_runs" add constraint "sync_runs_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
alter table public."sync_runs" add constraint "sync_runs_refresh_request_id_fkey" FOREIGN KEY (refresh_request_id) REFERENCES sync_refresh_requests(id);
alter table public."work_centers" add constraint "work_centers_organization_id_fkey" FOREIGN KEY (organization_id) REFERENCES organizations(id);
CREATE INDEX capacity_profiles_context_idx ON public.capacity_profiles USING btree (organization_id, production_area_id, shift_template_id) WHERE active;
CREATE INDEX capacity_scenario_lines_scenario_idx ON public.capacity_scenario_lines USING btree (capacity_scenario_id);
CREATE INDEX deputy_batch_date_idx ON public.deputy_import_batches USING btree (organization_id, imported_at DESC);
CREATE INDEX deputy_period_idx ON public.deputy_raw_timesheets USING btree (organization_id, timesheet_date, normalized_area);
CREATE INDEX deputy_quarantine_idx ON public.deputy_raw_timesheets USING btree (organization_id, row_status) WHERE (row_status = 'QUARANTINED'::text);
CREATE INDEX kpi_results_latest_idx ON public.kpi_results USING btree (organization_id, kpi_definition_id, calculated_at DESC);
CREATE INDEX kpi_targets_effective_idx ON public.kpi_targets USING btree (organization_id, kpi_definition_id, effective_from DESC);
CREATE INDEX labour_segments_period_idx ON public.labour_segments USING btree (organization_id, operational_date, shift_code, area_code);
CREATE INDEX labour_segments_person_week_idx ON public.labour_segments USING btree (organization_id, person_key, week_start);
CREATE INDEX maintenance_install_host_idx ON public.maintenance_asset_installations USING btree (organization_id, host_asset_id, installed_at DESC);
CREATE INDEX maintenance_install_movable_idx ON public.maintenance_asset_installations USING btree (organization_id, movable_asset_id, installed_at DESC);
CREATE UNIQUE INDEX maintenance_one_active_installation ON public.maintenance_asset_installations USING btree (movable_asset_id) WHERE (removed_at IS NULL);
CREATE INDEX maintenance_asset_org_status_idx ON public.maintenance_assets USING btree (organization_id, status) WHERE active;
CREATE INDEX maintenance_asset_parent_idx ON public.maintenance_assets USING btree (organization_id, parent_asset_id);
CREATE UNIQUE INDEX maintenance_asset_qr_token_idx ON public.maintenance_assets USING btree (public_qr_token);
CREATE INDEX maintenance_asset_search_idx ON public.maintenance_assets USING btree (organization_id, asset_code, name, serial_number);
CREATE INDEX maintenance_assets_availability_idx ON public.maintenance_assets USING btree (organization_id, counts_in_availability) WHERE (active AND counts_in_availability);
CREATE INDEX maintenance_attachments_wo_idx ON public.maintenance_attachments USING btree (work_order_id, created_at);
CREATE INDEX maintenance_audit_entity_idx ON public.maintenance_audit_log USING btree (organization_id, entity_type, entity_id, created_at DESC);
CREATE INDEX maintenance_downtime_org_started_idx ON public.maintenance_downtime_events USING btree (organization_id, started_at DESC);
CREATE INDEX maintenance_event_affected_idx ON public.maintenance_downtime_events USING btree (organization_id, affected_asset_id, event_date);
CREATE INDEX maintenance_event_date_idx ON public.maintenance_downtime_events USING btree (organization_id, event_date);
CREATE INDEX maintenance_event_host_idx ON public.maintenance_downtime_events USING btree (organization_id, host_asset_id, event_date);
CREATE UNIQUE INDEX maintenance_event_source_unique ON public.maintenance_downtime_events USING btree (organization_id, source_system, source_key) WHERE ((source_system IS NOT NULL) AND (source_key IS NOT NULL));
CREATE UNIQUE INDEX maintenance_one_active_down ON public.maintenance_downtime_events USING btree (asset_id) WHERE (ended_at IS NULL);
CREATE INDEX maintenance_staging_batch_idx ON public.maintenance_import_staging USING btree (batch_id, row_status);
CREATE INDEX maintenance_inventory_part_location_idx ON public.maintenance_inventory_transactions USING btree (part_id, location_id, created_at);
CREATE INDEX maintenance_inventory_wo_idx ON public.maintenance_inventory_transactions USING btree (work_order_id) WHERE (work_order_id IS NOT NULL);
CREATE INDEX maintenance_pm_due_idx ON public.maintenance_preventive_plans USING btree (organization_id, next_due_at) WHERE active;
CREATE INDEX maintenance_comments_wo_idx ON public.maintenance_work_order_comments USING btree (work_order_id, created_at);
CREATE INDEX maintenance_labor_wo_idx ON public.maintenance_work_order_labor USING btree (work_order_id, created_at);
CREATE UNIQUE INDEX maintenance_one_open_pm ON public.maintenance_work_orders USING btree (preventive_plan_id) WHERE ((preventive_plan_id IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])));
CREATE UNIQUE INDEX maintenance_operator_request_key_uq ON public.maintenance_work_orders USING btree (organization_id, operator_request_key) WHERE (operator_request_key IS NOT NULL);
CREATE INDEX maintenance_wo_org_status_due_idx ON public.maintenance_work_orders USING btree (organization_id, status, due_at);
CREATE INDEX maintenance_wo_source_pm_idx ON public.maintenance_work_orders USING btree (source_pm_work_order_id) WHERE (source_pm_work_order_id IS NOT NULL);
CREATE INDEX oracle_line_ingestion_runs_latest_complete_idx ON public.oracle_line_ingestion_runs USING btree (organization_id, completed_at DESC) WHERE ((snapshot_status = 'COMPLETE'::text) AND (status = 'COMPLETED'::text));
CREATE INDEX production_events_period_idx ON public.production_events USING btree (organization_id, operational_date, shift_code, metric);
CREATE INDEX production_events_timestamp_idx ON public.production_events USING btree (organization_id, event_ts_utc);
CREATE INDEX production_order_history_order_idx ON public.production_order_history USING btree (organization_id, order_no, changed_at DESC);
CREATE INDEX production_order_operation_evidence_order_idx ON public.production_order_operation_evidence USING btree (organization_id, production_order_id, observed_at);
CREATE INDEX production_order_operations_progress_idx ON public.production_order_operations USING btree (organization_id, production_order_id, sequence, status);
CREATE INDEX production_orders_execution_idx ON public.production_orders USING btree (organization_id, production_status, planned_date, planner_priority);
CREATE INDEX process_stage_org_idx ON public.production_process_stages USING btree (organization_id, production_process_id, sequence);
CREATE INDEX production_reconciliation_items_result_idx ON public.production_reconciliation_items USING btree (organization_id, reconciliation_run_id, overall_result);
CREATE INDEX production_reconciliation_runs_org_idx ON public.production_reconciliation_runs USING btree (organization_id, started_at DESC);
CREATE INDEX production_resources_center_idx ON public.production_resources USING btree (organization_id, work_center_id);
CREATE INDEX products_classification_idx ON public.products USING btree (organization_id, product_family_id, product_type_id);
CREATE INDEX products_default_routing_idx ON public.products USING btree (organization_id, default_routing_id);
CREATE INDEX resource_capacity_rules_lookup_idx ON public.resource_capacity_rules USING btree (organization_id, process, effective_from, effective_to) WHERE active;
CREATE INDEX routing_operations_routing_idx ON public.routing_operations USING btree (organization_id, routing_id, sequence);
CREATE INDEX screen_print_jobs_org_status_idx ON public.screen_print_jobs USING btree (organization_id, status, planned_date);
CREATE INDEX shift_rules_lookup_idx ON public.shift_rules USING btree (organization_id, weekday, effective_from, effective_to) WHERE active;
CREATE INDEX source_audit_event_idx ON public.source_audit_events USING btree (event_at);
CREATE INDEX source_audit_events_dtg_history_idx ON public.source_audit_events USING btree (order_no, from_zone, to_zone, event_at);
CREATE INDEX source_audit_events_record_key_idx ON public.source_audit_events USING btree (organization_id, COALESCE(source_audit_id, raw_hash));
CREATE INDEX source_audit_from_location_idx ON public.source_audit_events USING btree (from_location);
CREATE INDEX source_audit_order_idx ON public.source_audit_events USING btree (order_no);
CREATE INDEX source_audit_to_location_idx ON public.source_audit_events USING btree (to_location);
CREATE INDEX source_operation_mappings_lookup_idx ON public.source_operation_mappings USING btree (organization_id, source_dataset, source_field, priority) WHERE active;
CREATE INDEX source_orders_current_lookup_idx ON public.source_orders USING btree (organization_id, sync_batch_id, order_no);
CREATE INDEX source_orders_order_no_idx ON public.source_orders USING btree (order_no);
CREATE INDEX source_orders_site_idx ON public.source_orders USING btree (site);
CREATE INDEX source_release_lines_order_idx ON public.source_release_order_lines USING btree (organization_id, order_no);
CREATE INDEX source_stock_batch_location_idx ON public.source_stock_items USING btree (sync_batch_id, location);
CREATE INDEX source_stock_location_idx ON public.source_stock_items USING btree (location);
CREATE INDEX source_stock_pack_idx ON public.source_stock_items USING btree (pack_id);
CREATE INDEX source_stock_product_idx ON public.source_stock_items USING btree (product);
CREATE INDEX source_stock_zone_idx ON public.source_stock_items USING btree (source_zone);
CREATE UNIQUE INDEX source_task_mappings_identity ON public.source_task_mappings USING btree (organization_id, source_system, source_dataset, source_task, match_type, COALESCE(context_field, ''::text), COALESCE(context_match_type, ''::text), COALESCE(context_value, ''::text));
CREATE INDEX source_workbank_batch_zone_idx ON public.source_workbank_items USING btree (sync_batch_id, from_zone);
CREATE INDEX source_workbank_items_e61_lookup_idx ON public.source_workbank_items USING btree (organization_id, order_no, upper(TRIM(BOTH FROM product_code)));
CREATE INDEX source_workbank_items_e61_snapshot_lookup ON public.source_workbank_items USING btree (sync_batch_id, organization_id, order_no, upper(TRIM(BOTH FROM product_code)));
CREATE INDEX source_workbank_location_idx ON public.source_workbank_items USING btree (from_location);
CREATE INDEX source_workbank_order_no_idx ON public.source_workbank_items USING btree (order_no);
CREATE INDEX source_workbank_zone_idx ON public.source_workbank_items USING btree (from_zone);
CREATE UNIQUE INDEX staffing_layout_line_context ON public.staffing_layout_lines USING btree (staffing_layout_id, production_area_id, shift_template_id, COALESCE((day_of_week)::integer, 0));
CREATE UNIQUE INDEX sync_refresh_one_active_idx ON public.sync_refresh_requests USING btree (organization_id) WHERE (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text]));
CREATE INDEX sync_runs_recent_idx ON public.sync_runs USING btree (organization_id, requested_at DESC);
CREATE OR REPLACE FUNCTION public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p production_plans%rowtype;n text;po production_orders%rowtype;units numeric;seq integer;added integer:=0;begin select*into p from production_plans where id=p_plan_id for update;if p.id is null then raise exception 'Plan not found';end if;if p.status<>'draft'then raise exception 'Only drafts can be edited';end if;select coalesce(max(sequence),0)into seq from production_plan_items where production_plan_id=p_plan_id;foreach n in array p_order_nos loop select*into po from production_orders where organization_id=p.organization_id and order_no=n and planning_status in('planned','ready','in_progress');if po.id is null then raise exception 'Order % is not planned',n;end if;select remaining_units into units from v_production_planning where organization_id=p.organization_id and order_no=n and line=(select code from production_areas where id=p.production_area_id)limit 1;if units is null or units<=0 then raise exception 'Order unavailable in area';end if;seq=seq+1;insert into production_plan_items(production_plan_id,production_order_id,order_no,sequence,planned_units,special_instruction)values(p_plan_id,po.id,n,seq,units,po.special_instruction)on conflict(production_plan_id,production_order_id)do nothing;if found then added=added+1;end if;end loop;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)values(p_plan_id,'items_added',p_actor_id,p_actor_email,jsonb_build_object('orders',p_order_nos,'added',added));return added;end$function$
;
CREATE OR REPLACE FUNCTION public.apply_kpi_target_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare t kpi_targets%rowtype;dir text;begin
select direction into dir from kpi_definitions where id=new.kpi_definition_id;
select*into t from kpi_targets where organization_id=new.organization_id and kpi_definition_id=new.kpi_definition_id and(production_area_id is null or production_area_id=new.production_area_id)and(shift_id is null or shift_id=new.shift_id)and effective_from<=new.production_date and(effective_to is null or effective_to>=new.production_date)order by(production_area_id is not null)desc,(shift_id is not null)desc,effective_from desc limit 1;
if new.value is null then new.status='NO_DATA';new.target_value=null;return new;end if;if t.id is null then new.status='NO_TARGET';new.target_value=null;return new;end if;new.target_value=t.target_value;
if dir='HIGHER_IS_BETTER'then new.status=case when new.value>=t.target_value then'GOOD'when t.warning_value is not null and new.value>=t.warning_value then'WARNING'else'CRITICAL'end;elsif dir='LOWER_IS_BETTER'then new.status=case when new.value<=t.target_value then'GOOD'when t.warning_value is not null and new.value<=t.warning_value then'WARNING'else'CRITICAL'end;else new.status=case when t.critical_value is not null and abs(new.value-t.target_value)>t.critical_value then'CRITICAL'when t.warning_value is not null and abs(new.value-t.target_value)>t.warning_value then'WARNING'else'GOOD'end;end if;return new;end$function$
;
CREATE OR REPLACE FUNCTION public.apply_production_planning(p_organization_id uuid, p_order_nos text[], p_changes jsonb, p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n text; row_id uuid; old_row jsonb; new_row jsonb; old_status text; new_status text; changed integer:=0;
begin
  if coalesce(array_length(p_order_nos,1),0)=0 then raise exception 'At least one order is required'; end if;
  if p_changes ? 'planned_shift_id' and nullif(p_changes->>'planned_shift_id','') is not null and not exists(select 1 from shift_templates where id=(p_changes->>'planned_shift_id')::uuid and organization_id=p_organization_id and active) then raise exception 'Invalid shift'; end if;
  foreach n in array p_order_nos loop
    if not exists(select 1 from v_current_orders where organization_id=p_organization_id and order_no=n) then raise exception 'Unknown source order %',n; end if;
    insert into production_orders(organization_id,order_no,updated_by) values(p_organization_id,n,p_actor_id) on conflict do nothing;
    select id,to_jsonb(po),planning_status into row_id,old_row,old_status from production_orders po where organization_id=p_organization_id and order_no=n for update;
    new_status=coalesce(nullif(p_changes->>'planning_status',''),old_status);
    if new_status<>old_status and not ((old_status='unplanned' and new_status in ('planned','cancelled')) or (old_status='planned' and new_status in ('unplanned','ready','blocked','waiting','cancelled')) or (old_status='ready' and new_status in ('planned','in_progress','blocked','waiting','cancelled')) or (old_status='in_progress' and new_status in ('blocked','waiting','completed','cancelled')) or (old_status in ('blocked','waiting') and new_status in ('planned','ready','in_progress','cancelled')) or (old_status in ('completed','cancelled') and new_status='unplanned')) then raise exception 'Invalid status transition: % to %',old_status,new_status; end if;
    update production_orders set
      planner_priority=case when p_changes?'planner_priority' then nullif(p_changes->>'planner_priority','')::integer else planner_priority end,
      planned_date=case when p_changes?'planned_date' then nullif(p_changes->>'planned_date','')::date else planned_date end,
      planned_shift_id=case when p_changes?'planned_shift_id' then nullif(p_changes->>'planned_shift_id','')::uuid else planned_shift_id end,
      planning_status=new_status,
      special_instruction=case when p_changes?'special_instruction' then nullif(trim(p_changes->>'special_instruction'),'') else special_instruction end,
      planner_note=case when p_changes?'planner_note' then nullif(trim(p_changes->>'planner_note'),'') else planner_note end,
      blocked_reason=case when new_status='blocked' then nullif(trim(p_changes->>'blocked_reason'),'') else null end,
      updated_at=now(),updated_by=p_actor_id where id=row_id returning to_jsonb(production_orders.*) into new_row;
    insert into production_order_history(production_order_id,organization_id,order_no,changed_by,changed_by_email,before_state,after_state) values(row_id,p_organization_id,n,p_actor_id,p_actor_email,old_row,new_row);
    changed=changed+1;
  end loop;
  return changed;
end $function$
;
CREATE OR REPLACE FUNCTION public.backfill_active_wip_manufacturing_orders(p_organization_id uuid, p_source_system text DEFAULT 'ORACLE_WMS'::text)
 RETURNS TABLE(run_id uuid, staged_lines integer, created_mos integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare rid uuid;staged integer:=0;mos integer:=0;ev integer:=0;ex integer:=0;cov integer:=0;r record;begin
insert into active_wip_backfill_runs(organization_id,source_system)values(p_organization_id,p_source_system)returning id into rid;
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,source_product_code,source_description,quantity,due_date,source_priority,status,resolution_status)
select w.organization_id,p_source_system,w.order_no,'WORKBANK:'||w.source_row_id,p.id,p.default_routing_id,p.default_routing_id,w.product_code,w.product_description,w.production_units,w.source_due_at,w.source_priority,case when p.id is not null and rt.id is not null then'READY'else'EXCEPTION'end,case when p.id is null then'PRODUCT_UNMAPPED'when rt.id is null then'ROUTING_UNMAPPED'else'RESOLVED'end from v_current_workbank w left join product_source_mappings pm on pm.organization_id=w.organization_id and pm.source_system=p_source_system and pm.source_product_code=w.product_code and pm.active left join products p on p.id=pm.product_id and p.organization_id=w.organization_id and p.active left join routings rt on rt.id=p.default_routing_id and rt.organization_id=w.organization_id and rt.status='ACTIVE'and rt.active and(rt.effective_from is null or rt.effective_from<=current_date)and(rt.effective_to is null or rt.effective_to>=current_date)where w.organization_id=p_organization_id and nullif(w.source_row_id,'')is not null and w.production_units>0 and w.product_code!~'^#?[0-9]+$'and(upper(trim(coalesce(w.queue,'')))in('SP11','PCOR')or upper(trim(coalesce(w.from_location,'')))like'%UP')
on conflict(organization_id,source_system,source_order_no,source_order_line_id)do update set product_id=excluded.product_id,routing_id=excluded.routing_id,routing_revision_id=excluded.routing_revision_id,source_product_code=excluded.source_product_code,source_description=excluded.source_description,quantity=excluded.quantity,due_date=excluded.due_date,source_priority=excluded.source_priority,status=case when production_demand_lines.status='GROUPED'then'GROUPED'else excluded.status end,resolution_status=case when production_demand_lines.status='GROUPED'then production_demand_lines.resolution_status else excluded.resolution_status end,updated_at=now();get diagnostics staged=row_count;
insert into production_demand_exceptions(organization_id,production_demand_line_id,exception_type,description)select d.organization_id,d.id,d.resolution_status,'Active WIP line requires governed Product and Routing setup before MO creation.'from production_demand_lines d where d.organization_id=p_organization_id and d.source_system=p_source_system and d.status='EXCEPTION'on conflict do nothing;get diagnostics ex=row_count;
select count(*)into mos from create_manufacturing_orders(p_organization_id,p_source_system);select*into r from resolve_production_order_actual_state(p_organization_id,null);ev:=coalesce(r.evidence_added,0);ex:=ex+coalesce(r.exceptions_added,0);
insert into active_wip_coverage_exceptions(organization_id,source_system,source_order_no,stage_code,units,primary_cause,blocking_cause,explanation,status)select c.organization_id,p_source_system,c.source_order_no,c.stage_code,c.units,'PRE_EXISTING_WIP',case when not c.line_source_available then'SOURCE_LINE_MISSING'when exists(select 1 from production_demand_lines d where d.organization_id=c.organization_id and d.source_order_no=c.source_order_no and d.resolution_status='PRODUCT_UNMAPPED')then'PRODUCT_UNMAPPED'when exists(select 1 from production_demand_lines d where d.organization_id=c.organization_id and d.source_order_no=c.source_order_no and d.resolution_status in('ROUTING_UNMAPPED','ROUTING_INACTIVE'))then'ROUTING_UNMAPPED'else'MO_GENERATION_BUG'end,'Order was active before canonical MO coverage. No MO is fabricated from header-only or unmapped evidence.','ACCEPTED'from v_active_wip_mo_coverage c where c.organization_id=p_organization_id and c.canonical_mos=0 on conflict(organization_id,source_system,source_order_no,stage_code)do update set units=excluded.units,primary_cause=excluded.primary_cause,blocking_cause=excluded.blocking_cause,explanation=excluded.explanation,status='ACCEPTED',last_detected_at=now(),resolved_at=null;get diagnostics cov=row_count;ex:=ex+cov;
update active_wip_coverage_exceptions e set status='RESOLVED',resolved_at=now(),last_detected_at=now()where e.organization_id=p_organization_id and e.source_system=p_source_system and e.status<>'RESOLVED'and not exists(select 1 from v_active_wip_mo_coverage c where c.organization_id=e.organization_id and c.source_order_no=e.source_order_no and c.stage_code=e.stage_code and c.canonical_mos=0);
update active_wip_backfill_runs set completed_at=now(),staged_lines=staged,created_mos=mos,evidence_added=ev,exceptions_added=ex,status='COMPLETED'where id=rid;return query select rid,staged,mos,ev,ex;exception when others then update active_wip_backfill_runs set completed_at=now(),status='FAILED'where id=rid;raise;end$function$
;
CREATE OR REPLACE FUNCTION public.canonical_mo_planned_quantity(p_mo uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce(sum(ml.planned_quantity)filter(where d.status in('READY','GROUPED')),0)::numeric(14,3)from manufacturing_order_lines ml join production_demand_lines d on d.id=ml.production_demand_line_id where ml.manufacturing_order_id=p_mo$function$
;
CREATE OR REPLACE FUNCTION public.capture_sales_order_release_transitions(p_organization_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare n integer;
begin
  insert into sales_order_release_history(
    organization_id,source_order_no,previous_release_status,new_release_status,
    eligibility_snapshot,blockers_snapshot,source_status_snapshot,source_sync_batch_id
  )
  select s.organization_id,s.source_order_no,h.new_release_status,s.release_status,
    e.release_eligibility,to_jsonb(e.release_blockers),
    jsonb_build_object('status',s.source_status,'date_released',s.date_released),s.sync_batch_id
  from v_sales_order_release_state s
  join v_sales_order_release_eligibility e
    on e.organization_id=s.organization_id and e.source_order_no=s.source_order_no
  left join lateral(
    select x.new_release_status from sales_order_release_history x
    where x.organization_id=s.organization_id and x.source_order_no=s.source_order_no
    order by changed_at desc limit 1
  ) h on true
  where s.organization_id=p_organization_id
    and h.new_release_status is distinct from s.release_status
  on conflict do nothing;
  get diagnostics n=row_count;
  return n;
end
$function$;
CREATE OR REPLACE FUNCTION public.claim_sync_work(p_organization_id uuid, p_agent_id text, p_connector_version text, p_interval_seconds integer DEFAULT 300)
 RETURNS TABLE(run_id uuid, request_id uuid, trigger_type text, should_execute boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_run uuid;v_request uuid;v_trigger text;v_last_auto timestamptz;begin perform pg_advisory_xact_lock(hashtextextended('sync-control:'||p_organization_id::text,0));update sync_runs set status='FAILED',completed_at=now(),duration_ms=extract(epoch from(now()-started_at))*1000,failure_reason='STALE_RUN_LEASE_EXPIRED'where organization_id=p_organization_id and status='RUNNING'and started_at<now()-interval'20 minutes';update sync_refresh_requests r set status='FAILED',completed_at=now(),failure_reason='STALE_RUN_LEASE_EXPIRED'where r.organization_id=p_organization_id and r.status='RUNNING'and not exists(select 1 from sync_runs s where s.id=r.sync_run_id and s.status='RUNNING');if exists(select 1 from sync_runs s where s.organization_id=p_organization_id and s.status='RUNNING')then insert into sync_runs(organization_id,trigger_type,status,requested_at,completed_at,agent_id,connector_version,failure_reason)values(p_organization_id,'AUTOMATIC','SKIPPED_ALREADY_RUNNING',now(),now(),p_agent_id,p_connector_version,'ACTIVE_RUN_EXISTS')returning id into v_run;return query select v_run,null::uuid,'AUTOMATIC'::text,false;return;end if;select r.id into v_request from sync_refresh_requests r where r.organization_id=p_organization_id and r.status='QUEUED'order by r.requested_at limit 1 for update skip locked;if v_request is not null then v_trigger:='MANUAL';else select max(s.requested_at)into v_last_auto from sync_runs s where s.organization_id=p_organization_id and s.trigger_type='AUTOMATIC'and s.status in('RUNNING','SUCCESS','FAILED');if v_last_auto is not null and v_last_auto>now()-make_interval(secs=>greatest(60,p_interval_seconds))then return;end if;v_trigger:='AUTOMATIC';end if;insert into sync_runs(organization_id,refresh_request_id,trigger_type,status,requested_at,started_at,agent_id,connector_version)values(p_organization_id,v_request,v_trigger,'RUNNING',now(),now(),p_agent_id,p_connector_version)returning id into v_run;if v_request is not null then update sync_refresh_requests set status='RUNNING',started_at=now(),sync_run_id=v_run where id=v_request;end if;return query select v_run,v_request,v_trigger,true;end$function$
;
CREATE OR REPLACE FUNCTION public.clone_routing_revision(p_routing_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare source routings%rowtype;new_id uuid;new_revision integer;begin
  select * into strict source from routings where id=p_routing_id;
  perform pg_advisory_xact_lock(hashtext(source.organization_id::text||source.code));
  select coalesce(max(revision),0)+1 into new_revision from routings where organization_id=source.organization_id and code=source.code;
  insert into routings(organization_id,code,name,revision,status,active)values(source.organization_id,source.code,source.name,new_revision,'DRAFT',true)returning id into new_id;
  insert into routing_operations(organization_id,routing_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions)
  select organization_id,new_id,sequence,operation_id,work_center_id,required,setup_minutes,run_rate,queue_minutes,capacity_profile_id,instructions from routing_operations where routing_id=p_routing_id order by sequence;
  return new_id;
end$function$
;
CREATE OR REPLACE FUNCTION public.copy_production_order_operations()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.source_routing_id is null or exists(select 1 from production_order_operations where production_order_id=new.id)then return new;end if;
  insert into production_order_operations(organization_id,production_order_id,source_routing_operation_id,source_operation_id,sequence,operation_code_snapshot,operation_name_snapshot,work_center_code_snapshot,work_center_name_snapshot,required,setup_minutes_snapshot,run_rate_snapshot,queue_minutes_snapshot,instructions_snapshot,planned_quantity,planned_date,planned_shift_id)
  select new.organization_id,new.id,ro.id,o.id,ro.sequence,o.code,o.name,w.code,w.name,ro.required,ro.setup_minutes,ro.run_rate,ro.queue_minutes,ro.instructions,new.planned_quantity,new.planned_date,new.planned_shift_id
  from routing_operations ro join operations o on o.id=ro.operation_id and o.organization_id=ro.organization_id left join work_centers w on w.id=ro.work_center_id and w.organization_id=ro.organization_id
  where ro.routing_id=new.source_routing_id and ro.organization_id=new.organization_id order by ro.sequence;
  return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare result uuid;begin if not exists(select 1 from shift_templates where id=p_shift_id and organization_id=p_organization_id and active)then raise exception 'Invalid shift';end if;if not exists(select 1 from production_areas where id=p_area_id and organization_id=p_organization_id and active and code<>'UNMAPPED')then raise exception 'Invalid area';end if;insert into production_plans(organization_id,production_date,shift_template_id,production_area_id,created_by)values(p_organization_id,p_production_date,p_shift_id,p_area_id,p_actor_id)returning id into result;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select result,'created',p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=result;return result;end$function$
;
CREATE OR REPLACE FUNCTION public.create_manufacturing_orders(p_organization_id uuid, p_source_system text DEFAULT 'ORACLE_WMS'::text)
 RETURNS TABLE(out_manufacturing_order_id uuid, out_mo_number text, out_source_order_no text, out_routing_id uuid, out_planned_quantity numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;mo uuid;number text;
begin
  for g in
    select d.source_order_no,d.routing_revision_id,sum(d.quantity)::numeric(14,3) qty,
      min(d.due_date)::date planned_date,min(d.planner_priority) planner_priority,r.code routing_code
    from production_demand_lines d join routings r on r.id=d.routing_revision_id and r.organization_id=d.organization_id
    where d.organization_id=p_organization_id and d.source_system=p_source_system and d.status='READY' and d.resolution_status='RESOLVED'
    group by d.source_order_no,d.routing_revision_id,r.code order by d.source_order_no,r.code
  loop
    number:='MO-'||regexp_replace(g.source_order_no,'[^A-Za-z0-9_-]','','g')||'-'||g.routing_code||'-1';
    insert into production_orders(organization_id,order_no,mo_number,source_system,source_order_no,source_routing_id,planned_quantity,planned_date,planner_priority,split_number)
    values(p_organization_id,number,number,p_source_system,g.source_order_no,g.routing_revision_id,g.qty,g.planned_date,g.planner_priority,1)
    on conflict on constraint production_orders_so_routing_split_key do update set updated_at=now()
    returning id into mo;
    insert into manufacturing_order_lines(organization_id,manufacturing_order_id,production_demand_line_id,source_order_no,source_order_line_id,product_id,routing_revision_id,planned_quantity,sequence)
    select d.organization_id,mo,d.id,d.source_order_no,d.source_order_line_id,d.product_id,d.routing_revision_id,d.quantity,
      row_number()over(order by d.source_order_line_id)::integer
    from production_demand_lines d where d.organization_id=p_organization_id and d.source_system=p_source_system
      and d.source_order_no=g.source_order_no and d.routing_revision_id=g.routing_revision_id and d.status='READY' and d.resolution_status='RESOLVED'
    on conflict(production_demand_line_id) do nothing;
    update production_demand_lines set status='GROUPED',updated_at=now() where organization_id=p_organization_id and source_system=p_source_system
      and source_order_no=g.source_order_no and routing_revision_id=g.routing_revision_id and status='READY';
    return query select po.id,po.mo_number,po.source_order_no,po.source_routing_id,po.planned_quantity from production_orders po where po.id=mo;
  end loop;
end$function$
;
CREATE OR REPLACE FUNCTION public.enforce_manufacturing_order_line_boundary()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare parent production_orders%rowtype; demand production_demand_lines%rowtype;
begin
  select * into strict parent from production_orders where id=new.manufacturing_order_id and organization_id=new.organization_id;
  if parent.source_order_no is distinct from new.source_order_no then raise exception 'MO line Sales Order must equal parent Sales Order';end if;
  if parent.source_routing_id is distinct from new.routing_revision_id then raise exception 'MO line Routing must equal parent Routing';end if;
  if new.production_demand_line_id is not null then
    select * into strict demand from production_demand_lines where id=new.production_demand_line_id and organization_id=new.organization_id;
    if (demand.source_order_no,demand.source_order_line_id,demand.product_id,demand.routing_revision_id) is distinct from
       (new.source_order_no,new.source_order_line_id,new.product_id,new.routing_revision_id) then
      raise exception 'MO line does not match its demand line';
    end if;
  end if;
  new.updated_at:=now();return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.enforce_production_resource_asset_organization()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin if new.asset_id is not null and not exists(select 1 from maintenance_assets a where a.id=new.asset_id and a.organization_id=new.organization_id)then raise exception 'Production resource asset must belong to the same organization';end if;return new;end$function$
;
CREATE OR REPLACE FUNCTION public.enforce_sync_batch_organization()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  batch_organization_id uuid;
begin
  select organization_id
    into batch_organization_id
    from public.sync_batches
   where id = new.sync_batch_id;

  if batch_organization_id is null then
    raise exception 'SYNC_BATCH_NOT_FOUND';
  end if;

  if batch_organization_id is distinct from new.organization_id then
    raise exception 'SYNC_BATCH_ORGANIZATION_MISMATCH';
  end if;

  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.finalize_oracle_line_ingestion(p_organization_id uuid, p_run_id uuid, p_expected_rows integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare r oracle_line_ingestion_runs;n integer;dupes integer;unknowns integer;begin select*into r from oracle_line_ingestion_runs where id=p_run_id and organization_id=p_organization_id for update;select count(*),count(*)filter(where raw_release_value not in('Y','N'))into n,unknowns from oracle_line_ingestion_staging where ingestion_run_id=p_run_id;select count(*)-count(distinct(source_order_no,source_line_id))into dupes from oracle_line_ingestion_staging where ingestion_run_id=p_run_id;if r.status<>'RUNNING'or n=0 or n<>p_expected_rows or n<>r.rows_processed or dupes<>0 then raise exception'INCOMPLETE_SNAPSHOT rows=% expected=% processed=% duplicates=%',n,p_expected_rows,r.rows_processed,dupes;end if;
update source_order_release_lines set source_presence='NOT_SEEN_IN_LATEST_COMPLETE_SNAPSHOT'where organization_id=p_organization_id and source_system='ORACLE_WMS';
insert into source_order_release_lines(organization_id,sync_batch_id,source_system,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at,ingestion_run_id,source_presence,source_routing,source_operational_code,source_operational_codes,operational_code_conflict)
select s.organization_id,r.sync_batch_id,'ORACLE_WMS',s.source_order_no,s.source_line_id,s.source_product_code,s.source_description,s.production_units,s.released,s.raw_release_value,s.source_line_status,s.quantity_processed,s.source_weight,s.stock_reserved_flag,s.source_updated_at,p_run_id,'ACTIVE',s.source_routing,s.source_operational_code,s.source_operational_codes,s.operational_code_conflict from oracle_line_ingestion_staging s where s.ingestion_run_id=p_run_id
on conflict(organization_id,source_system,source_order_no,source_line_id)do update set sync_batch_id=excluded.sync_batch_id,source_product_code=excluded.source_product_code,source_description=excluded.source_description,production_units=excluded.production_units,released=excluded.released,raw_release_value=excluded.raw_release_value,source_line_status=excluded.source_line_status,quantity_processed=excluded.quantity_processed,source_weight=excluded.source_weight,stock_reserved_flag=excluded.stock_reserved_flag,source_updated_at=excluded.source_updated_at,ingestion_run_id=excluded.ingestion_run_id,source_presence='ACTIVE',source_routing=excluded.source_routing,source_operational_code=excluded.source_operational_code,source_operational_codes=excluded.source_operational_codes,operational_code_conflict=excluded.operational_code_conflict;
update oracle_line_ingestion_runs set status='COMPLETED',snapshot_status='COMPLETE',completed_at=now(),updated_at=now()where id=p_run_id;perform capture_sales_order_release_transitions(p_organization_id); perform reconcile_release_reactivations(p_organization_id,p_run_id,true);return jsonb_build_object('runId',p_run_id,'status','COMPLETE','sourceRows',n,'duplicateKeys',dupes,'unknownReleasedValues',unknowns);end$function$
;
CREATE OR REPLACE FUNCTION public.finish_sync_work(p_run_id uuid, p_status text, p_batch_id uuid, p_duration_ms bigint, p_orders integer, p_workbank integer, p_stock integer, p_audit integer, p_failure text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_request uuid;begin if p_status not in('SUCCESS','FAILED')then raise exception'INVALID_SYNC_STATUS';end if;update sync_runs set status=p_status,completed_at=now(),duration_ms=p_duration_ms,batch_id=p_batch_id,orders_count=coalesce(p_orders,0),workbank_count=coalesce(p_workbank,0),stock_count=coalesce(p_stock,0),audit_count=coalesce(p_audit,0),failure_reason=left(p_failure,1000)where id=p_run_id and status='RUNNING'returning refresh_request_id into v_request;if v_request is not null then update sync_refresh_requests set status=p_status,completed_at=now(),failure_reason=left(p_failure,1000)where id=v_request;end if;end$function$
;
CREATE OR REPLACE FUNCTION public.ingest_audit_backfill(p_organization_id uuid, p_events jsonb, p_rebuild boolean DEFAULT false)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_inserted bigint:=0;begin
 if jsonb_typeof(p_events)<>'array'or jsonb_array_length(p_events)>1000 then raise exception'INVALID_BACKFILL_PAYLOAD';end if;
 insert into public.source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,queue,task)
 select p_organization_id,event->>'sourceAuditId',coalesce(event->>'orderNo',''),event->>'username',event->>'fromZone',event->>'toZone',event->>'fromLocation',event->>'toLocation',event->>'product',event->>'fromPackId',event->>'toPackId',nullif(event->>'sourceQty','')::numeric,nullif(event->>'sourceWeight','')::numeric,coalesce(nullif(event->>'productionUnits','')::numeric,0),(event->>'eventAt')::timestamptz,event->>'rawHash',event->>'queue',event->>'task'from jsonb_array_elements(p_events)event on conflict do nothing;
 insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)
 select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone'Australia/Brisbane',(a.event_at at time zone'Australia/Brisbane')::date,case when r.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<r.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end,extract(hour from a.event_at at time zone'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,a.production_units,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then'OUT_OF_SHIFT'else'COMPLETE'end,'ERP_KPI_V1'
 from source_audit_events a cross join lateral(select*from(values('DTG'::text,'DTG_PRINT'::text,'prints'::text,upper(coalesce(a.queue,''))='PCOR'or upper(coalesce(a.task,''))='PCOR'),('DTG','DTG_PUTWALL_IN','garments',upper(coalesce(a.to_zone,''))='PWL1'),('DTG','DTG_PUTWALL_OUT','garments',upper(coalesce(a.from_zone,''))='PWL1'),('UP','UP_IN','garments',upper(coalesce(a.to_location,''))like'%UNDERPRINT%'),('UP','UP_OUT','garments',upper(coalesce(a.from_location,''))like'%UNDERPRINT%'and upper(coalesce(a.to_location,''))not like'%UNDERPRINT%'))v(area,metric,unit,accepted)where accepted)m
 left join lateral(select s.*from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone'Australia/Brisbane')::date and(s.effective_to is null or s.effective_to>=(a.event_at at time zone'Australia/Brisbane')::date)and s.weekday=extract(isodow from case when s.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end)and(case when s.cross_midnight then(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time or(a.event_at at time zone'Australia/Brisbane')::time<s.end_time else(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time end)order by s.effective_from desc limit 1)r on true
 where a.organization_id=p_organization_id and a.production_units>0 and a.raw_hash in(select event->>'rawHash'from jsonb_array_elements(p_events)event)on conflict do nothing;get diagnostics v_inserted=row_count;return v_inserted;end$function$
;
CREATE OR REPLACE FUNCTION public.ingest_authoritative_release_lines(p_organization_id uuid, p_sync_batch_id uuid, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 if not exists(select 1 from sync_batches where id=p_sync_batch_id and organization_id=p_organization_id and status='completed')then raise exception 'INVALID_COMPLETED_SYNC_BATCH';end if;
 delete from source_order_release_lines where organization_id=p_organization_id and source_system='ORACLE_WMS';
 insert into source_order_release_lines(organization_id,sync_batch_id,source_system,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at)
 select p_organization_id,p_sync_batch_id,'ORACLE_WMS',x."orderNo",x."lineNumber"::text,x."productCode",x."sourceDescription",greatest(coalesce(x.quantity,0),0),case upper(trim(coalesce(x.released,'')))when'Y'then true when'N'then false else null end,nullif(upper(trim(x.released)),''),x."sourceStatus",x."quantityProcessed",x.weight,x."stockReservedFlag",x."sourceUpdatedAt"
 from jsonb_to_recordset(p_lines)x("orderNo" text,"lineNumber" integer,"productCode" text,"sourceDescription" text,quantity numeric,weight numeric,released text,"sourceStatus" text,"quantityProcessed" numeric,"stockReservedFlag" text,"sourceUpdatedAt" timestamptz);
 get diagnostics n=row_count;return n;end$function$
;
create or replace function public.ingest_sync_batch(payload jsonb)
returns uuid
language plpgsql
security definer
set search_path to 'public'
set statement_timeout to '120s'
as $function$
declare
  batch_id uuid;
  audit_count integer := 0;
  v_organization_id uuid := (payload ->> 'organizationId')::uuid;
  v_orders jsonb := coalesce(payload -> 'orders', '[]'::jsonb);
  v_release_lines jsonb := coalesce(payload -> 'releaseOrderLines', '[]'::jsonb);
  v_workbank jsonb := coalesce(payload -> 'workbank', '[]'::jsonb);
  v_stock jsonb := coalesce(payload -> 'stock', '[]'::jsonb);
  v_audit jsonb := coalesce(payload -> 'auditEvents', '[]'::jsonb);
begin
  if v_organization_id is null then
    raise exception 'ORGANIZATION_ID_REQUIRED';
  end if;
  if jsonb_typeof(v_orders) <> 'array'
     or jsonb_typeof(v_release_lines) <> 'array'
     or jsonb_typeof(v_workbank) <> 'array'
     or jsonb_typeof(v_stock) <> 'array'
     or jsonb_typeof(v_audit) <> 'array' then
    raise exception 'INVALID_SYNC_PAYLOAD';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_organization_id::text, 0));

  insert into public.sync_batches(organization_id, status, connector_version)
  values(v_organization_id, 'running', payload ->> 'connectorVersion')
  returning id into batch_id;

  delete from public.source_release_order_lines where organization_id = v_organization_id;
  delete from public.source_orders where organization_id = v_organization_id;
  delete from public.source_workbank_items where organization_id = v_organization_id;
  delete from public.source_stock_items where organization_id = v_organization_id;

  insert into public.source_orders(
    organization_id, sync_batch_id, order_no, date_received, date_due,
    date_released, source_status, source_sub_status, customer_code,
    customer_name, ship_to_name, customer_state, city, delivery_desc,
    client_so_number, source_priority, site, source_route_id, cost_centre,
    stop_ship_flag, release_source_status, source_updated_at
  )
  select v_organization_id, batch_id, x."orderNo", x."dateReceived",
    x."dateDue", x."dateReleased", x."sourceStatus", x."sourceSubStatus",
    x."customerCode", x."customerName", x."shipToName", x."customerState",
    x.city, x."deliveryDesc", x."clientSoNumber", x."sourcePriority", x.site,
    x."routeId", x."costCentre", x."stopShipFlag", x."releaseSourceStatus",
    x."sourceUpdatedAt"
  from jsonb_to_recordset(v_orders) as x(
    "orderNo" text, "dateReceived" timestamptz, "dateDue" timestamptz,
    "dateReleased" timestamptz, "sourceStatus" text, "sourceSubStatus" text,
    "customerCode" text, "customerName" text, "shipToName" text,
    "customerState" text, city text, "deliveryDesc" text,
    "clientSoNumber" text, "sourcePriority" integer, site text,
    "routeId" text, "costCentre" text, "stopShipFlag" text,
    "releaseSourceStatus" text, "sourceUpdatedAt" timestamptz
  );

  insert into public.source_release_order_lines(
    organization_id, sync_batch_id, order_no, line_number, product, client,
    qty_lcd, orig_ref3, group_code, product_name, source_updated_at
  )
  select v_organization_id, batch_id, x."orderNo", x."lineNumber", x.product,
    x.client, x."qtyLcd", x."origRef3", x."groupCode", x."productName",
    x."sourceUpdatedAt"
  from jsonb_to_recordset(v_release_lines) as x(
    "orderNo" text, "lineNumber" text, product text, client text,
    "qtyLcd" numeric, "origRef3" text, "groupCode" text,
    "productName" text, "sourceUpdatedAt" timestamptz
  );

  insert into public.source_workbank_items(
    organization_id, sync_batch_id, source_row_id, order_no, customer_code,
    customer_name, source_due_at, from_location, from_zone, to_location,
    from_pack_id, to_pack_id, source_priority, product_code,
    product_description, product_group, source_qty, source_weight,
    production_units, prints_per_garment, queue, task
  )
  select v_organization_id, batch_id, x.*
  from jsonb_to_recordset(v_workbank) as x(
    "sourceRowId" text, "orderNo" text, "customerCode" text,
    "customerName" text, "sourceDueAt" timestamptz, "fromLocation" text,
    "fromZone" text, "toLocation" text, "fromPackId" text, "toPackId" text,
    "sourcePriority" integer, "productCode" text, "productDescription" text,
    "productGroup" text, "sourceQty" numeric, "sourceWeight" numeric,
    "productionUnits" numeric, "printsPerGarment" numeric, queue text, task text
  );

  insert into public.source_stock_items(
    organization_id, sync_batch_id, product, pack_id, location, source_zone,
    source_timestamp, source_qty, source_weight, production_units
  )
  select v_organization_id, batch_id, x.*
  from jsonb_to_recordset(v_stock) as x(
    product text, "packId" text, location text, "sourceZone" text,
    "sourceTimestamp" timestamptz, "sourceQty" numeric,
    "sourceWeight" numeric, "productionUnits" numeric
  );

  insert into public.source_audit_events(
    organization_id, source_audit_id, order_no, username, from_zone, to_zone,
    from_location, to_location, product, from_pack_id, to_pack_id, source_qty,
    source_weight, production_units, event_at, raw_hash
  )
  select v_organization_id, x.*
  from jsonb_to_recordset(v_audit) as x(
    "sourceAuditId" text, "orderNo" text, username text, "fromZone" text,
    "toZone" text, "fromLocation" text, "toLocation" text, product text,
    "fromPackId" text, "toPackId" text, "sourceQty" numeric,
    "sourceWeight" numeric, "productionUnits" numeric, "eventAt" timestamptz,
    "rawHash" text
  )
  on conflict do nothing;
  get diagnostics audit_count = row_count;

  update public.sync_batches
  set status = 'completed', completed_at = now(),
      orders_count = jsonb_array_length(v_orders),
      release_line_count = jsonb_array_length(v_release_lines),
      workbank_count = jsonb_array_length(v_workbank),
      stock_count = jsonb_array_length(v_stock),
      audit_new_count = audit_count
  where id = batch_id;

  perform public.ingest_authoritative_release_lines(
    v_organization_id,
    batch_id,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'orderNo', line ->> 'orderNo',
        'lineNumber', line ->> 'lineNumber',
        'productCode', line ->> 'product',
        'sourceDescription', line ->> 'productName',
        'quantity', line -> 'qtyLcd',
        'released', line ->> 'released',
        'sourceUpdatedAt', line ->> 'sourceUpdatedAt'
      ))
      from jsonb_array_elements(v_release_lines) line
    ), '[]'::jsonb)
  );

  delete from public.sync_batches b
  where b.organization_id = v_organization_id and b.id <> batch_id
    and b.id not in (
      select k.id from public.sync_batches k
      where k.organization_id = v_organization_id
      order by k.created_at desc limit 99
    );

  return batch_id;
exception when others then
  raise;
end
$function$;
CREATE OR REPLACE FUNCTION public.maintenance_audit_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare row_data jsonb;org uuid;eid uuid;begin row_data:=case when tg_op='DELETE'then to_jsonb(old)else to_jsonb(new)end;org:=(row_data->>'organization_id')::uuid;eid:=nullif(row_data->>'id','')::uuid;insert into maintenance_audit_log(organization_id,user_id,entity_type,entity_id,action,old_values,new_values)values(org,auth.uid(),tg_table_name,eid,tg_op,case when tg_op in('UPDATE','DELETE')then to_jsonb(old)end,case when tg_op in('INSERT','UPDATE')then to_jsonb(new)end);return case when tg_op='DELETE'then old else new end;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p text;c uuid;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select prefix,category_id into p,c from maintenance_asset_prefixes where id=p_prefix_id and organization_id=p_organization_id and active for share;if p is null then raise exception'Invalid or inactive asset prefix';end if;insert into maintenance_asset_code_sequences values(p_organization_id,p,0,now())on conflict do nothing;update maintenance_asset_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and prefix=p returning last_number into n;if n>999 then raise exception'Asset sequence exhausted';end if;code:=p||'-'||lpad(n::text,3,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,category_id,prefix_id,location,manufacturer,model,serial_number,description,criticality,status,installation_date,purchase_date,purchase_cost,warranty_expiry,installed_at,created_by)values(p_organization_id,code,p_name,p_name,c,p_prefix_id,nullif(trim(p_location),''),nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,p_purchase_date,p_purchase_cost,p_warranty_expiry,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pc text;p text;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select asset_code into pc from maintenance_assets where id=p_parent_asset_id and organization_id=p_organization_id and active for share;select prefix into p from maintenance_component_prefixes where id=p_component_prefix_id and organization_id=p_organization_id and active for share;if pc is null or p is null then raise exception'Invalid parent or component prefix';end if;insert into maintenance_component_code_sequences values(p_organization_id,p_parent_asset_id,p,0,now())on conflict do nothing;update maintenance_component_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and parent_asset_id=p_parent_asset_id and component_prefix=p returning last_number into n;if n>99 then raise exception'Component sequence exhausted';end if;code:=pc||'-'||p||'-'||lpad(n::text,2,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,manufacturer,model,serial_number,description,criticality,status,installation_date,installed_at,created_by)values(p_organization_id,code,p_name,p_name,p_parent_asset_id,nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_generate_due_pm(p_organization_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare p record;w uuid;n text;made integer:=0;begin for p in select*from maintenance_preventive_plans where organization_id=p_organization_id and active and trigger_type='calendar'and next_due_at<=now()+(lead_time_days||' days')::interval and not exists(select 1 from maintenance_work_orders where preventive_plan_id=maintenance_preventive_plans.id and status not in('completed','cancelled'))for update skip locked loop n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,work_order_type,preventive_plan_id,status,priority,title,problem_description,requested_by,requested_by_email,due_at)values(p_organization_id,n,p.asset_id,'preventive',p.id,'open',p.priority,p.name,p.description,p_actor_id,p_actor_email,p.next_due_at)returning id into w;insert into maintenance_work_order_checklist(organization_id,work_order_id,sequence,task,instructions,required)select p_organization_id,w,sequence,task,instructions,required from maintenance_preventive_plan_tasks where preventive_plan_id=p.id;insert into maintenance_work_order_history(organization_id,work_order_id,to_status,changed_by,changed_by_email)values(p_organization_id,w,'open',p_actor_id,p_actor_email);made:=made+1;end loop;return made;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_import_history(p_organization_id uuid, p_file_name text, p_file_hash text, p_assets jsonb, p_events jsonb, p_report jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare b uuid;r jsonb;a uuid;h uuid;s uuid;ph uuid;ins integer:=0;upd integer:=0;begin
 insert into maintenance_import_batches(organization_id,file_name,file_hash,source_system,status,total_rows,valid_rows,warning_rows,error_rows,import_report)
 values(p_organization_id,p_file_name,p_file_hash,'ERP_MAINTENANCE_HISTORY','IMPORTING',jsonb_array_length(p_events),(p_report->>'valid_rows')::int,(p_report->>'warning_rows')::int,(p_report->>'error_rows')::int,p_report)
 on conflict(organization_id,file_hash)do update set import_report=excluded.import_report returning id into b;
 if exists(select 1 from maintenance_import_batches where id=b and status='COMPLETED')then return jsonb_build_object('batch_id',b,'status','duplicate');end if;
 if coalesce((p_report->>'error_rows')::int,0)>0 then raise exception 'Blocking dry-run errors remain';end if;
 for r in select * from jsonb_array_elements(p_assets)loop
  insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,asset_kind,asset_type,asset_category,status,active,notes)
  values(p_organization_id,r->>'asset_code',r->>'asset_name',r->>'asset_name',
   (select id from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'parent_asset_code','')),
   coalesce(r->>'asset_kind','FIXED'),r->>'asset_type',r->>'category',
   case upper(coalesce(r->>'status','ACTIVE'))when 'ACTIVE'then'operational'when'STORED'then'standby'when'UNDER_MAINTENANCE'then'maintenance'when'SCRAPPED'then'scrapped'else'retired'end,
   upper(coalesce(r->>'status','ACTIVE'))not in('RETIRED','SCRAPPED'),r->>'notes')
  on conflict(organization_id,asset_code)do update set name=excluded.name,asset_name=excluded.asset_name,
   asset_kind=excluded.asset_kind,asset_type=coalesce(excluded.asset_type,maintenance_assets.asset_type),
   asset_category=coalesce(excluded.asset_category,maintenance_assets.asset_category),
   notes=coalesce(excluded.notes,maintenance_assets.notes),updated_at=now();
 end loop;
 for r in select * from jsonb_array_elements(p_events)loop
  select id into h from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'parent_asset_code';
  select id into a from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'asset_code';
  select id into s from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'host_print_system_code','');
  select id into ph from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'ph_asset_code','') and asset_kind='MOVABLE';
  if h is null or a is null then raise exception 'Unresolved required asset at source row %',r->>'source_row';end if;
  insert into maintenance_import_staging(batch_id,organization_id,source_row,row_status,source_key,host_asset_code,affected_asset_code,historical_asset_reference,payload)
  values(b,p_organization_id,(r->>'source_row')::int,case when ph is null and nullif(r->>'ph_reference','')is not null then'UNRESOLVED_PH'else'VALID'end,
   r->>'source_key',r->>'parent_asset_code',r->>'ph_asset_code',r->>'ph_reference',r);
  if exists(select 1 from maintenance_downtime_events where organization_id=p_organization_id and source_system=r->>'source_system' and source_key=r->>'source_key')then upd:=upd+1;else ins:=ins+1;end if;
  insert into maintenance_downtime_events(organization_id,asset_id,event_code,event_date,host_asset_id,host_system_asset_id,affected_asset_id,
   started_at,ended_at,downtime_minutes,event_type,maintenance_class,failure_category,failure_mode,root_cause,action_taken,spare_parts_text,
   description,counts_as_failure,counts_as_downtime,event_status,source_system,source_key,source_row,original_duration_minutes,
   clock_duration_minutes,correction_factor,data_quality_status,correction_confidence,correction_method,correction_note,raw_reason,historical_asset_reference,reason)
  values(p_organization_id,a,r->>'event_id',(r->>'event_date')::date,h,s,ph,(r->>'started_at')::timestamptz,(r->>'ended_at')::timestamptz,
   (r->>'downtime_minutes')::numeric,r->>'event_type',r->>'maintenance_class',r->>'failure_category',r->>'failure_mode',
   r->>'root_cause_inferred',r->>'action_inferred',r->>'spare_parts_text',r->>'description',(r->>'counts_as_failure')='YES',
   (r->>'counts_as_downtime')='YES',r->>'status',r->>'source_system',r->>'source_key',(r->>'source_row')::int,
   nullif(r->>'original_duration_minutes','')::numeric,nullif(r->>'clock_duration_minutes','')::numeric,nullif(r->>'correction_factor','')::numeric,
   r->>'data_quality_status',r->>'correction_confidence',r->>'correction_method',r->>'correction_note',r->>'raw_reason',r->>'ph_reference',r->>'raw_reason')
  on conflict(organization_id,source_system,source_key)where source_system is not null and source_key is not null do update set
   host_asset_id=excluded.host_asset_id,host_system_asset_id=excluded.host_system_asset_id,affected_asset_id=excluded.affected_asset_id,
   downtime_minutes=excluded.downtime_minutes,event_type=excluded.event_type,maintenance_class=excluded.maintenance_class,
   failure_category=excluded.failure_category,failure_mode=excluded.failure_mode,counts_as_failure=excluded.counts_as_failure,
   counts_as_downtime=excluded.counts_as_downtime,original_duration_minutes=excluded.original_duration_minutes,
   clock_duration_minutes=excluded.clock_duration_minutes,correction_factor=excluded.correction_factor,data_quality_status=excluded.data_quality_status,
   correction_confidence=excluded.correction_confidence,correction_method=excluded.correction_method,correction_note=excluded.correction_note,
   historical_asset_reference=excluded.historical_asset_reference,updated_at=now();
 end loop;
 update maintenance_import_batches set status='COMPLETED',inserted_rows=ins,updated_rows=upd,completed_at=now() where id=b;
 return jsonb_build_object('batch_id',b,'status','COMPLETED','inserted_rows',ins,'updated_rows',upd);
end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_operator_classify(p_organization_id uuid, p_work_order_id uuid, p_problem_area text, p_symptom text, p_comment text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin update maintenance_work_orders set problem_description=concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')),updated_at=now()where id=p_work_order_id and organization_id=p_organization_id;if not found then raise exception'Work order not found';end if;insert into maintenance_work_order_comments(organization_id,work_order_id,user_id,author_email,comment)select p_organization_id,p_work_order_id,p_actor_id,p_actor_email,concat('Operator classification: ',concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')))where coalesce(trim(p_problem_area),'')<>''or coalesce(trim(p_symptom),'')<>''or coalesce(trim(p_comment),'')<>'';end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_operator_escalate(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;begin select status into old from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='WAITING_MAINTENANCE',request_type='CORRECTIVE_NOW',maintenance_requested_at=coalesce(maintenance_requested_at,now()),updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'WAITING_MAINTENANCE',p_actor_id,p_actor_email);end if;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_operator_pm_action(p_organization_id uuid, p_work_order_id uuid, p_action text, p_checklist_id uuid, p_completed boolean, p_no_parts_used boolean, p_resolution text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare w maintenance_work_orders%rowtype;p maintenance_preventive_plans%rowtype;old_status text;missing_tasks integer;has_parts boolean;
begin
 select * into w from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id and work_order_type='preventive' for update;
 if w.id is null then raise exception'Preventive work order not found';end if;
 select * into p from maintenance_preventive_plans where id=w.preventive_plan_id and organization_id=p_organization_id;old_status:=w.status;
 if p_action='start' then
  if w.status not in('open','in_progress')then raise exception'Preventive work cannot be started from this status';end if;
  update maintenance_work_orders set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()where id=w.id;
  if old_status<>'in_progress'then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'in_progress',p_actor_id,p_actor_email);end if;
  if p.requires_downtime and not exists(select 1 from maintenance_downtime_events where work_order_id=w.id and ended_at is null)then
   insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,w.asset_id,w.asset_id,w.id,w.title,p_actor_id,'PLANNED',false,true);
   update maintenance_assets set status='maintenance',updated_at=now()where id=w.asset_id and status<>'down';
  end if;
 elsif p_action='check'then
  if w.status<>'in_progress'then raise exception'Start preventive work first';end if;
  update maintenance_work_order_checklist set completed=p_completed,completed_at=case when p_completed then now()else null end,completed_by=case when p_completed then p_actor_id else null end where id=p_checklist_id and work_order_id=w.id and organization_id=p_organization_id;
  if not found then raise exception'Checklist item not found';end if;
 elsif p_action='parts_confirm'then
  update maintenance_work_orders set no_parts_used_confirmed=p_no_parts_used,no_parts_used_confirmed_at=case when p_no_parts_used then now()else null end,no_parts_used_confirmed_by=case when p_no_parts_used then p_actor_id else null end,updated_at=now()where id=w.id;
 elsif p_action='complete'then
  if w.status<>'in_progress'then raise exception'Preventive work must be in progress';end if;
  select count(*)into missing_tasks from maintenance_work_order_checklist where work_order_id=w.id and required and not completed;
  if missing_tasks>0 then raise exception'Complete all required checklist items';end if;
  select exists(select 1 from maintenance_inventory_transactions where work_order_id=w.id and transaction_type='issue')into has_parts;
  if not(w.no_parts_used_confirmed or has_parts)then raise exception'Record parts used or confirm No Parts Used';end if;
  update maintenance_work_orders set status='completed',resolution=coalesce(nullif(trim(p_resolution),''),'Preventive maintenance completed'),completed_at=now(),updated_at=now()where id=w.id;
  insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'completed',p_actor_id,p_actor_email);
  update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=w.id and ended_at is null;
  update maintenance_assets set status='operational',updated_at=now()where id=w.asset_id and not exists(select 1 from maintenance_downtime_events where asset_id=w.asset_id and ended_at is null);
  update maintenance_preventive_plans set next_due_at=case frequency_unit when'day'then greatest(next_due_at,now())+make_interval(days=>frequency_value)when'week'then greatest(next_due_at,now())+make_interval(days=>frequency_value*7)when'month'then greatest(next_due_at,now())+make_interval(months=>frequency_value)when'year'then greatest(next_due_at,now())+make_interval(years=>frequency_value)else next_due_at end,updated_at=now()where id=w.preventive_plan_id;
 else raise exception'Unsupported PM action';end if;
end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_operator_resolve(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='completed',resolution='Resolved by operator',completed_at=now(),updated_at=now()where id=p_work_order_id;update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'completed',p_actor_id,p_actor_email);end if;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_operator_start_request(p_organization_id uuid, p_asset_id uuid, p_request_type text, p_request_key text, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare w uuid;n text;s text;stopped boolean;event_start timestamptz;begin if p_request_type not in('OPERATOR_FIX','CORRECTIVE_NOW','SCHEDULE_CORRECTIVE')then raise exception'Invalid request type';end if;perform pg_advisory_xact_lock(hashtext(p_asset_id::text));select id into w from maintenance_work_orders where organization_id=p_organization_id and operator_request_key=p_request_key limit 1;if w is not null then return w;end if;stopped:=p_request_type in('OPERATOR_FIX','CORRECTIVE_NOW');if stopped then select work_order_id into w from maintenance_downtime_events where organization_id=p_organization_id and asset_id=p_asset_id and ended_at is null order by started_at limit 1;if w is not null then return w;end if;end if;if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;s:=case p_request_type when'OPERATOR_FIX'then'OPEN_OPERATOR'when'CORRECTIVE_NOW'then'WAITING_MAINTENANCE'else'REQUESTED'end;event_start:=case when stopped then clock_timestamp() else null end;n:='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,status,priority,title,requested_by,requested_by_email,request_type,maintenance_requested_at,counts_as_downtime,operator_request_key,downtime_started_at)values(p_organization_id,n,p_asset_id,s,case when p_request_type='CORRECTIVE_NOW'then'critical'when p_request_type='OPERATOR_FIX'then'high'else'medium'end,replace(p_request_type,'_',' '),p_actor_id,p_actor_email,p_request_type,case when p_request_type='CORRECTIVE_NOW'then event_start end,stopped,p_request_key,event_start)returning id into w;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w,null,s,p_actor_id,p_actor_email);if stopped then insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_at,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,p_asset_id,p_asset_id,w,replace(p_request_type,'_',' '),event_start,p_actor_id,'CORRECTIVE',true,true);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_post_inventory(p_organization_id uuid, p_part_id uuid, p_location_id uuid, p_work_order_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric, p_notes text, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare id uuid;q numeric;available numeric;begin if p_quantity<=0 then raise exception'Quantity must be positive';end if;if not exists(select 1 from maintenance_parts where id=p_part_id and organization_id=p_organization_id and active)or not exists(select 1 from maintenance_inventory_locations where id=p_location_id and organization_id=p_organization_id and active)then raise exception'Invalid inventory reference';end if;q:=case when p_type='issue'then-p_quantity else p_quantity end;if p_type='issue'then select coalesce(sum(quantity),0)into available from maintenance_inventory_transactions where part_id=p_part_id and location_id=p_location_id;if available<p_quantity then raise exception'Insufficient stock';end if;end if;insert into maintenance_inventory_transactions(organization_id,part_id,location_id,work_order_id,transaction_type,quantity,unit_cost_snapshot,notes,created_by,created_by_email)values(p_organization_id,p_part_id,p_location_id,p_work_order_id,p_type,q,p_unit_cost,p_notes,p_actor_id,p_actor_email)returning maintenance_inventory_transactions.id into id;return id;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_report_problem(p_organization_id uuid, p_asset_id uuid, p_title text, p_description text, p_priority text, p_machine_stopped boolean, p_actor_id uuid, p_actor_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare w uuid;n text;begin if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,priority,title,problem_description,requested_by,requested_by_email)values(p_organization_id,n,p_asset_id,p_priority,p_title,p_description,p_actor_id,p_actor_email)returning id into w;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,w,null,'open',p_actor_id,p_actor_email,now());if p_machine_stopped then insert into maintenance_downtime_events(organization_id,asset_id,work_order_id,reason,started_by)values(p_organization_id,p_asset_id,w,p_title,p_actor_id);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email,now());if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$
;
CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text, p_cancel_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare old text;a uuid;allowed boolean:=false;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;allowed:=case old when'open'then p_status in('open','in_progress','cancelled')when'in_progress'then p_status in('in_progress','waiting_parts','waiting_external','completed')when'waiting_parts'then p_status in('waiting_parts','in_progress','cancelled')when'waiting_external'then p_status in('waiting_external','in_progress','cancelled')else p_status=old end;if not allowed then raise exception'Invalid work order transition';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;if p_status='cancelled'and nullif(trim(p_cancel_reason),'')is null then raise exception'Cancellation reason required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),cancel_reason=coalesce(nullif(trim(p_cancel_reason),''),cancel_reason),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;if old<>p_status then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email);end if;if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$
;
CREATE OR REPLACE FUNCTION public.normalize_production_event_units()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$begin
 if new.source='ORACLE_AUDIT'and new.metric<>'DTG_PRINT'then select coalesce(a.source_weight,a.source_qty,a.production_units)into new.quantity from source_audit_events a where a.organization_id=new.organization_id and coalesce(a.source_audit_id,a.raw_hash)=new.source_record_key limit 1;end if;
 return new;end$function$
;
CREATE OR REPLACE FUNCTION public.prepare_production_order_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare p products%rowtype;r routings%rowtype;resolved_routing uuid;
begin
  if tg_op='UPDATE'and old.source_routing_id is not null and(new.product_id,new.source_routing_id,new.routing_code_snapshot,new.routing_name_snapshot,new.routing_revision_snapshot)is distinct from(old.product_id,old.source_routing_id,old.routing_code_snapshot,old.routing_name_snapshot,old.routing_revision_snapshot)then
    raise exception 'Production order routing snapshot is immutable';
  end if;
  if new.product_id is null and new.source_routing_id is null then return new;end if;
  if new.product_id is not null then
    select * into p from products where id=new.product_id and organization_id=new.organization_id and active;
    if p.id is null then raise exception 'Invalid or inactive product';end if;
  end if;
  resolved_routing:=coalesce(new.source_routing_id,p.default_routing_id);
  select * into r from routings where id=resolved_routing and organization_id=new.organization_id and status='ACTIVE'and active
    and(effective_from is null or effective_from<=current_date)and(effective_to is null or effective_to>=current_date);
  if r.id is null then raise exception 'Manufacturing Order requires an active effective routing';end if;
  if not exists(select 1 from routing_operations where routing_id=r.id and organization_id=r.organization_id)then raise exception 'Routing has no operations';end if;
  new.source_order_no:=coalesce(new.source_order_no,new.order_no);
  new.source_routing_id:=r.id;
  new.routing_code_snapshot:=r.code;
  new.routing_name_snapshot:=r.name;
  new.routing_revision_snapshot:=r.revision;
  if new.production_status='UNROUTED'then new.production_status:='PLANNED';end if;
  return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.protect_active_operation_deactivation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if old.active and not new.active and exists(select 1 from routing_operations ro join routings r on r.id=ro.routing_id and r.organization_id=ro.organization_id where ro.operation_id=old.id and ro.organization_id=old.organization_id and r.status='ACTIVE')then raise exception 'Operation is used by an active routing revision';end if;return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.protect_production_operation_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE'then raise exception 'Production operation snapshots cannot be deleted';end if;
  if(new.organization_id,new.production_order_id,new.source_routing_operation_id,new.source_operation_id,new.sequence,new.operation_code_snapshot,new.operation_name_snapshot,new.work_center_code_snapshot,new.work_center_name_snapshot,new.required,new.setup_minutes_snapshot,new.run_rate_snapshot,new.queue_minutes_snapshot,new.instructions_snapshot)is distinct from(old.organization_id,old.production_order_id,old.source_routing_operation_id,old.source_operation_id,old.sequence,old.operation_code_snapshot,old.operation_name_snapshot,old.work_center_code_snapshot,old.work_center_name_snapshot,old.required,old.setup_minutes_snapshot,old.run_rate_snapshot,old.queue_minutes_snapshot,old.instructions_snapshot)then raise exception 'Production operation definition snapshot is immutable';end if;
  if new.status<>old.status and not((old.status='PENDING'and new.status in('READY','IN_PROGRESS','SKIPPED'))or(old.status='READY'and new.status in('IN_PROGRESS','SKIPPED'))or(old.status='IN_PROGRESS'and new.status in('ON_HOLD','COMPLETED'))or(old.status='ON_HOLD'and new.status in('IN_PROGRESS','SKIPPED')))then raise exception 'Invalid production operation status transition';end if;
  if new.status='IN_PROGRESS'and old.status<>'IN_PROGRESS'then new.started_at:=coalesce(new.started_at,now());end if;
  if new.status in('COMPLETED','SKIPPED')and old.status not in('COMPLETED','SKIPPED')then new.completed_at:=coalesce(new.completed_at,now());end if;
  new.updated_at:=now();return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.protect_routing_operation_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare route_status text;operation_active boolean;begin
  select status into route_status from routings where id=coalesce(new.routing_id,old.routing_id)and organization_id=coalesce(new.organization_id,old.organization_id);
  if route_status is distinct from 'DRAFT'then raise exception 'Routing operations may only change on draft revisions';end if;
  if tg_op<>'DELETE'then select active into operation_active from operations where id=new.operation_id and organization_id=new.organization_id;if operation_active is distinct from true then raise exception 'Only active canonical operations may be added';end if;end if;
  return case when tg_op='DELETE'then old else new end;
end$function$
;
CREATE OR REPLACE FUNCTION public.protect_routing_revision()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if tg_op='DELETE' and old.status<>'DRAFT' then raise exception 'Only draft routing revisions may be deleted';end if;
  if tg_op='UPDATE' and old.status='ACTIVE' and (new.code,new.name,new.revision,new.effective_from,new.organization_id)is distinct from(old.code,old.name,old.revision,old.effective_from,old.organization_id)then raise exception 'Active routing revisions are immutable';end if;
  if tg_op='UPDATE' and old.status='INACTIVE' and new is distinct from old then raise exception 'Inactive routing revisions are immutable';end if;
  if tg_op='UPDATE' and not((old.status=new.status)or(old.status='DRAFT'and new.status in('ACTIVE','INACTIVE'))or(old.status='ACTIVE'and new.status='INACTIVE'))then raise exception 'Invalid routing status transition';end if;
  return case when tg_op='DELETE'then old else new end;
end$function$
;
CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_actual()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin update production_orders set actual_quantity=(select coalesce(sum(actual_quantity),0)from manufacturing_order_lines where manufacturing_order_id=new.manufacturing_order_id),updated_at=now()where id=new.manufacturing_order_id;return new;end$function$
;
CREATE OR REPLACE FUNCTION public.recalculate_manufacturing_order_quantity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare mo uuid:=coalesce(new.manufacturing_order_id,old.manufacturing_order_id);q numeric;begin q:=canonical_mo_planned_quantity(mo);update production_orders set planned_quantity=q,updated_at=now()where id=mo;update production_order_operations set planned_quantity=q,updated_at=now()where q>0 and production_order_id=mo and status in('PENDING','READY');return coalesce(new,old);end$function$
;
CREATE OR REPLACE FUNCTION public.reconcile_release_reactivations(p_organization_id uuid, p_snapshot_run_id uuid DEFAULT NULL::uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_snapshot uuid;v_at timestamptz;r record;detected integer:=0;restored integer:=0;qty numeric:=0;events integer:=0;exceptions integer:=0;mos integer:=0;
begin
 select id,completed_at into v_snapshot,v_at from oracle_line_ingestion_runs
 where id=coalesce(p_snapshot_run_id,(select id from oracle_line_ingestion_runs x where x.organization_id=p_organization_id and x.status='COMPLETED' and x.snapshot_status='COMPLETE' order by x.completed_at desc,x.id desc limit 1))
  and organization_id=p_organization_id and status='COMPLETED' and snapshot_status='COMPLETE';
 if v_snapshot is null then raise exception 'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;
 create temp table if not exists e68_mos(id uuid primary key)on commit drop;truncate e68_mos;
 for r in select * from v_release_reactivation_candidates where organization_id=p_organization_id and reactivation_snapshot_run_id=v_snapshot loop
  detected:=detected+1;
  if r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then
   if p_apply then
    update production_demand_lines set status='GROUPED',updated_at=now() where id=r.production_demand_line_id and status='CANCELLED';
    if found then restored:=restored+1;qty:=qty+r.mapped_quantity;insert into e68_mos values(r.manufacturing_order_id)on conflict do nothing;end if;
   end if;
  else exceptions:=exceptions+1;end if;
  if p_apply then
   insert into production_demand_release_events(id,organization_id,production_demand_line_id,manufacturing_order_line_id,manufacturing_order_id,event_type,action,original_mapping_at,original_snapshot_run_id,original_released,original_raw_release_value,event_snapshot_run_id,event_at,previous_release_value,current_release_value,mapped_quantity,executed_quantity,mo_status,created_at)
   values(gen_random_uuid(),r.organization_id,r.production_demand_line_id,r.manufacturing_order_line_id,r.manufacturing_order_id,
    case when r.recommended_action='RESTORED_TO_PLANNED_DEMAND' then 'RELEASE_REACTIVATED' else 'RE_RELEASED_REQUIRES_RECONCILIATION' end,
    r.recommended_action,r.original_mapping_at,r.original_snapshot_run_id,true,'Y',v_snapshot,v_at,'N','Y',r.mapped_quantity,coalesce(r.executed_quantity,0),r.mo_status,now())
   on conflict(production_demand_line_id,event_type,event_snapshot_run_id)do nothing;
   if found then events:=events+1;end if;
  end if;
 end loop;
 if p_apply then
  update production_orders po set planned_quantity=canonical_mo_planned_quantity(po.id),updated_at=now()
   from e68_mos m where po.id=m.id;
  update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()
   from production_orders po join e68_mos m on m.id=po.id
   where op.production_order_id=po.id and op.status in('PENDING','READY');
  select count(*)into mos from e68_mos;
 end if;
 return jsonb_build_object('snapshotRunId',v_snapshot,'apply',p_apply,'linesDetected',detected,'linesReactivated',restored,'quantityRestored',qty,'mosRecalculated',mos,'controlledExceptions',exceptions,'eventsCreated',events);
end$function$
;
CREATE OR REPLACE FUNCTION public.reconcile_release_revocations(p_organization_id uuid, p_snapshot_run_id uuid DEFAULT NULL::uuid, p_apply boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare v_snapshot uuid;v_at timestamptz;r record;n integer:=0;q numeric:=0;m integer:=0;e integer:=0;begin select id,completed_at into v_snapshot,v_at from oracle_line_ingestion_runs where id=coalesce(p_snapshot_run_id,(select id from oracle_line_ingestion_runs x where x.organization_id=p_organization_id and x.status='COMPLETED'and x.snapshot_status='COMPLETE'order by x.completed_at desc,x.id desc limit 1))and organization_id=p_organization_id and status='COMPLETED'and snapshot_status='COMPLETE';if v_snapshot is null then raise exception'COMPLETE_RELEASE_SNAPSHOT_REQUIRED';end if;create temp table if not exists e65_mos(id uuid primary key)on commit drop;truncate e65_mos;for r in select*from v_release_revocation_candidates where organization_id=p_organization_id and revocation_snapshot_run_id=v_snapshot loop if p_apply then insert into production_demand_release_events values(default,r.organization_id,r.production_demand_line_id,r.manufacturing_order_line_id,r.manufacturing_order_id,'RELEASE_REVOKED_AFTER_MAPPING',r.recommended_action,r.original_mapping_at,r.original_snapshot_run_id,r.original_released,r.original_raw_release_value,v_snapshot,v_at,case when r.original_released then'Y'else'N'end,'N',r.mapped_quantity,coalesce(r.executed_quantity,0),r.mo_status,default)on conflict(production_demand_line_id,event_type,event_snapshot_run_id)do nothing;if found then e:=e+1;end if;end if;if r.recommended_action='WITHDRAWN_FROM_PLANNED_DEMAND'and r.demand_status<>'CANCELLED'then n:=n+1;q:=q+r.mapped_quantity;if p_apply then update production_demand_lines set status='CANCELLED',updated_at=now()where id=r.production_demand_line_id and status<>'CANCELLED';insert into e65_mos values(r.manufacturing_order_id)on conflict do nothing;end if;end if;end loop;if p_apply then update production_orders po set planned_quantity=x.qty,production_status=case when x.qty=0 then'CANCELLED'else po.production_status end,updated_at=now()from(select t.id,coalesce(sum(ml.planned_quantity)filter(where d.status<>'CANCELLED'),0)::numeric qty from e65_mos t join manufacturing_order_lines ml on ml.manufacturing_order_id=t.id join production_demand_lines d on d.id=ml.production_demand_line_id group by t.id)x where po.id=x.id;update production_order_operations op set planned_quantity=po.planned_quantity,updated_at=now()from production_orders po join e65_mos t on t.id=po.id where po.planned_quantity>0 and op.production_order_id=po.id and op.status in('PENDING','READY');select count(*)into m from e65_mos;end if;return jsonb_build_object('snapshotRunId',v_snapshot,'apply',p_apply,'linesDetected',n,'quantityDetected',q,'linesRevoked',case when p_apply then n else 0 end,'quantityWithdrawn',case when p_apply then q else 0 end,'mosRecalculated',m,'eventsCreated',e);end$function$
;
CREATE OR REPLACE FUNCTION public.release_reactivation_action(p_status text, p_executed numeric, p_eligible boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
select case
 when p_eligible is not true then 'RELEASE_REACTIVATION_BLOCKED'
 when p_status='COMPLETED' then 'RELEASE_REACTIVATED_AFTER_COMPLETION'
 when p_status='IN_PROGRESS' or coalesce(p_executed,0)>0 then 'RELEASE_REACTIVATED_AFTER_PRODUCTION_START'
 when p_status='PLANNED' then 'RESTORED_TO_PLANNED_DEMAND'
 when p_status='CANCELLED' then 'RELEASE_REACTIVATED_MO_CANCELLED'
 else 'INCREMENTAL_RECONCILIATION_REQUIRED'
end$function$
;
CREATE OR REPLACE FUNCTION public.release_revocation_action(p_status text, p_executed numeric, p_valid boolean)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$select case when p_valid is not true then case when p_valid is false then'INVALID_AT_CREATION'else'CANNOT_PROVE'end when p_status='COMPLETED'then'RELEASE_REVOKED_AFTER_COMPLETION'when p_status='IN_PROGRESS'or coalesce(p_executed,0)>0 then'RELEASE_REVOKED_AFTER_PRODUCTION_START'when p_status in('PLANNED','PENDING','READY','RELEASED')then'WITHDRAWN_FROM_PLANNED_DEMAND'when p_status='CANCELLED'then'CANCELLED_MO_REVIEW_REQUIRED'else'CANNOT_PROVE'end$function$
;
CREATE OR REPLACE FUNCTION public.resolve_product_process_routing(p_organization_id uuid, p_product_id uuid, p_process_code text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select coalesce((select a.routing_id from product_routing_assignments a join routings r on r.id=a.routing_id and r.organization_id=a.organization_id where a.organization_id=p_organization_id and a.product_id=p_product_id and a.process_code=p_process_code and a.approved and r.active and r.status='ACTIVE'and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date)limit 1),(select r.id from routings r where r.id=p_order_line_override and r.organization_id=p_organization_id and r.active and r.status='ACTIVE'limit 1),(select p.default_routing_id from products p join routings r on r.id=p.default_routing_id and r.organization_id=p.organization_id where p.id=p_product_id and p.organization_id=p_organization_id and r.active and r.status='ACTIVE'and(select count(distinct a.routing_id)from product_routing_assignments a where a.organization_id=p_organization_id and a.product_id=p_product_id and a.approved)=1))$function$
;
CREATE OR REPLACE FUNCTION public.resolve_product_routing_from_source_task(p_organization_id uuid, p_product_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text, p_order_line_override uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select resolve_product_process_routing(p_organization_id,p_product_id,r.process_code,p_order_line_override)from resolve_source_task_context(p_organization_id,p_source_dataset,p_source_task,p_queue,p_from_zone,p_to_zone,p_from_location,p_to_location)r where r.process_code is not null limit 1$function$
;
CREATE OR REPLACE FUNCTION public.resolve_production_order_actual_state(p_organization_id uuid, p_production_order_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(orders_resolved integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare poid uuid;r record;o integer:=0;e integer:=0;x integer:=0;begin
with ambiguous as(select ev.source_dataset,ev.source_record_key,ev.operation_id from v_source_operation_evidence ev join production_orders po on po.organization_id=ev.organization_id and coalesce(po.source_order_no,po.order_no)=ev.order_no join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where ev.organization_id=p_organization_id and(p_production_order_id is null or po.id=p_production_order_id)group by ev.source_dataset,ev.source_record_key,ev.operation_id having count(distinct po.id)>1),ins as(insert into production_routing_exceptions(organization_id,production_order_id,production_order_operation_id,exception_type,description,source_dataset,source_record_key)select distinct po.organization_id,po.id,op.id,'AMBIGUOUS_SOURCE_EVIDENCE','Evidence matches multiple MOs in the same SO; execution was not changed.',ev.source_dataset,ev.source_record_key from ambiguous a join v_source_operation_evidence ev using(source_dataset,source_record_key,operation_id)join production_orders po on po.organization_id=ev.organization_id and coalesce(po.source_order_no,po.order_no)=ev.order_no join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where not exists(select 1 from production_routing_exceptions z where z.production_order_id=po.id and z.production_order_operation_id=op.id and z.exception_type='AMBIGUOUS_SOURCE_EVIDENCE'and z.source_dataset=ev.source_dataset and z.source_record_key=ev.source_record_key)returning 1)select count(*)into x from ins;
for poid in select po.id from production_orders po where po.organization_id=p_organization_id and(p_production_order_id is null or po.id=p_production_order_id)and not exists(select 1 from v_source_operation_evidence ev join production_order_operations op on op.production_order_id=po.id and op.source_operation_id=ev.operation_id where ev.organization_id=po.organization_id and ev.order_no=coalesce(po.source_order_no,po.order_no)and exists(select 1 from production_orders other join production_order_operations oop on oop.production_order_id=other.id and oop.source_operation_id=ev.operation_id where other.organization_id=po.organization_id and other.id<>po.id and coalesce(other.source_order_no,other.order_no)=ev.order_no))loop select * into r from resolve_production_order_actual_state_unambiguous(p_organization_id,poid);o:=o+coalesce(r.orders_resolved,0);e:=e+coalesce(r.evidence_added,0);x:=x+coalesce(r.exceptions_added,0);end loop;return query select o,e,x;end$function$
;
CREATE OR REPLACE FUNCTION public.resolve_production_order_actual_state_unambiguous(p_organization_id uuid, p_production_order_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(orders_resolved integer, evidence_added integer, exceptions_added integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_orders integer:=0; v_evidence integer:=0; v_exceptions integer:=0; v_count integer;
begin
  perform seed_source_operation_mappings(p_organization_id);

  with inserted as (
    insert into production_order_operation_evidence(
      organization_id,production_order_id,production_order_operation_id,source_mapping_id,source_dataset,
      source_record_key,source_audit_event_id,semantics,observed_at,quantity,source_value)
    select po.organization_id,po.id,poo.id,e.source_mapping_id,e.source_dataset,e.source_record_key,
      e.source_audit_event_id,e.completion_semantics,e.observed_at,e.quantity,e.source_value
    from production_orders po
    join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    join production_order_operations poo on poo.production_order_id=po.id
      and poo.organization_id=po.organization_id and poo.source_operation_id=e.operation_id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    on conflict do nothing returning 1
  ) select count(*) into v_evidence from inserted;

  with touched as (
    update production_order_operations poo set
      status=case
        when x.has_completion then 'COMPLETED'
        when poo.status in ('PENDING','READY') and x.has_entry then 'IN_PROGRESS'
        else poo.status end,
      started_at=coalesce(poo.started_at,x.first_observed_at),
      completed_at=case when x.has_completion then coalesce(poo.completed_at,x.last_completion_at) else poo.completed_at end,
      actual_quantity=greatest(poo.actual_quantity,coalesce(x.observed_quantity,0)),updated_at=now()
    from (
      select production_order_operation_id,
        bool_or(semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) has_completion,
        bool_or(semantics in ('CURRENT_LOCATION','ENTERED_OPERATION','MOVED_TO_OPERATION')) has_entry,
        min(observed_at) first_observed_at,
        max(observed_at) filter(where semantics in ('COMPLETED_OPERATION','MOVED_FROM_OPERATION')) last_completion_at,
        sum(coalesce(quantity,0)) observed_quantity
      from production_order_operation_evidence
      where organization_id=p_organization_id and (p_production_order_id is null or production_order_id=p_production_order_id)
      group by production_order_operation_id
    ) x where poo.id=x.production_order_operation_id
    returning poo.production_order_id
  ) select count(distinct production_order_id) into v_orders from touched;

  with observed as (
    select po.id production_order_id,max(poo.sequence) max_observed_sequence
    from production_orders po join production_order_operations poo on poo.production_order_id=po.id
    join production_order_operation_evidence e on e.production_order_operation_id=poo.id
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
    group by po.id
  ), inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,production_order_operation_id,exception_type,description)
    select poo.organization_id,poo.production_order_id,poo.id,'SKIPPED_OPERATION',
      'Required operation '||poo.operation_code_snapshot||' has no source evidence before a later observed operation.'
    from observed o join production_order_operations poo on poo.production_order_id=o.production_order_id
    where poo.required and poo.sequence<o.max_observed_sequence
      and not exists(select 1 from production_order_operation_evidence e where e.production_order_operation_id=poo.id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  with inserted as (
    insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
    select po.organization_id,po.id,'UNEXPECTED_OPERATION',
      'Mapped source operation is not present in the Production Order routing snapshot.',e.source_dataset,e.source_record_key
    from production_orders po join v_source_operation_evidence e on e.organization_id=po.organization_id
      and e.order_no=coalesce(po.source_order_no,po.order_no)
    where po.organization_id=p_organization_id and (p_production_order_id is null or po.id=p_production_order_id)
      and not exists(select 1 from production_order_operations poo where poo.production_order_id=po.id and poo.source_operation_id=e.operation_id)
    on conflict do nothing returning 1
  ) select count(*) into v_count from inserted;
  v_exceptions:=v_exceptions+v_count;

  update production_orders po set
    production_status=case
      when not exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status<>'COMPLETED') then 'COMPLETED'
      when exists(select 1 from production_order_operations x where x.production_order_id=po.id and x.status='IN_PROGRESS') then 'IN_PROGRESS'
      else po.production_status end,
    actual_quantity=coalesce((select max(x.actual_quantity) from production_order_operations x where x.production_order_id=po.id),po.actual_quantity),
    updated_at=now()
  where po.organization_id=p_organization_id and po.production_status<>'UNROUTED'
    and (p_production_order_id is null or po.id=p_production_order_id);

  return query select v_orders,v_evidence,v_exceptions;
end $function$
;
CREATE OR REPLACE FUNCTION public.resolve_source_task_context(p_organization_id uuid, p_source_dataset text, p_source_task text, p_queue text DEFAULT NULL::text, p_from_zone text DEFAULT NULL::text, p_to_zone text DEFAULT NULL::text, p_from_location text DEFAULT NULL::text, p_to_location text DEFAULT NULL::text)
 RETURNS TABLE(mapping_id uuid, production_process_id uuid, process_code text, operation_id uuid, operation_code text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$select m.id,m.production_process_id,p.code,m.operation_id,o.code from source_task_mappings m join production_processes p on p.id=m.production_process_id and p.organization_id=m.organization_id left join operations o on o.id=m.operation_id and o.organization_id=m.organization_id where m.organization_id=p_organization_id and m.source_system='ORACLE_WMS'and m.source_dataset=upper(p_source_dataset)and m.active and source_value_matches(p_source_task,m.match_type,m.source_task)and(m.context_field is null or source_value_matches(case m.context_field when'queue'then p_queue when'from_zone'then p_from_zone when'to_zone'then p_to_zone when'from_location'then p_from_location when'to_location'then p_to_location end,m.context_match_type,m.context_value))order by(case when m.context_field is not null then 0 else 1 end),m.priority,m.id limit 1$function$
;
CREATE OR REPLACE FUNCTION public.run_production_reconciliation(p_organization_id uuid, p_quantity_tolerance numeric DEFAULT 1)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_run_id uuid; v_batch_id uuid;
begin
  if p_quantity_tolerance < 0 then raise exception 'Quantity tolerance cannot be negative'; end if;
  select id into v_batch_id from v_latest_completed_batch where organization_id=p_organization_id;
  insert into production_reconciliation_runs(organization_id,sync_batch_id,quantity_tolerance)
  values(p_organization_id,v_batch_id,p_quantity_tolerance) returning id into v_run_id;

  insert into production_reconciliation_items(
    organization_id,reconciliation_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,
    quantity_result,overall_result,detail)
  with legacy as (
    select organization_id,order_no,'DTG'::text legacy_area,'DTG_PRINT'::text expected_operation_code,remaining_units legacy_remaining_quantity
    from v_dtg_operational_orders where organization_id=p_organization_id
    union all
    select organization_id,order_no,'UP','UNDERPRINT',remaining_units
    from v_up_operational_orders where organization_id=p_organization_id
  ), canonical as (
    select x.organization_id,coalesce(x.source_order_no,x.order_no) order_no,x.current_operation_code,
      case when poo.planned_quantity is null then null
        else greatest(poo.planned_quantity-coalesce(poo.actual_quantity,0),0) end canonical_remaining_quantity,
      x.production_order_id,x.production_status
    from v_production_order_execution x
    left join production_order_operations poo on poo.id=x.current_operation_id
    where x.organization_id=p_organization_id and x.production_status not in ('CANCELLED','COMPLETED','UNROUTED')
  ), compared as (
    select coalesce(l.organization_id,c.organization_id) organization_id,coalesce(l.order_no,c.order_no) order_no,
      l.legacy_area,l.expected_operation_code,c.current_operation_code canonical_operation_code,
      l.legacy_remaining_quantity,c.canonical_remaining_quantity,
      case when l.legacy_remaining_quantity is not null and c.canonical_remaining_quantity is not null
        then c.canonical_remaining_quantity-l.legacy_remaining_quantity end quantity_variance,
      case when c.order_no is null then 'MISSING_CANONICAL' when l.order_no is null then 'MISSING_LEGACY' else 'BOTH' end presence_result,
      case when c.order_no is null or l.order_no is null then 'NOT_COMPARABLE'
        when c.current_operation_code=l.expected_operation_code then 'MATCH' else 'MISMATCH' end operation_result,
      case when l.legacy_remaining_quantity is null or c.canonical_remaining_quantity is null then 'NOT_COMPARABLE'
        when abs(c.canonical_remaining_quantity-l.legacy_remaining_quantity)<=p_quantity_tolerance then 'MATCH' else 'MISMATCH' end quantity_result,
      c.production_order_id,c.production_status
    from legacy l full join canonical c on c.organization_id=l.organization_id and c.order_no=l.order_no
  )
  select organization_id,v_run_id,order_no,legacy_area,expected_operation_code,canonical_operation_code,
    legacy_remaining_quantity,canonical_remaining_quantity,quantity_variance,presence_result,operation_result,quantity_result,
    case when presence_result='MISSING_CANONICAL' then 'MISSING_CANONICAL'
      when presence_result='MISSING_LEGACY' then 'MISSING_LEGACY'
      when operation_result='MISMATCH' or quantity_result='MISMATCH' then 'MISMATCH' else 'MATCH' end,
    jsonb_build_object('production_order_id',production_order_id,'production_status',production_status,
      'quantity_semantics','legacy remaining versus canonical planned minus actual')
  from compared;

  update production_reconciliation_runs r set
    status='COMPLETED',completed_at=now(),
    total_orders=s.total_orders,matched_orders=s.matched_orders,mismatched_orders=s.mismatched_orders,
    missing_canonical_orders=s.missing_canonical_orders,missing_legacy_orders=s.missing_legacy_orders,
    comparable_quantity_orders=s.comparable_quantity_orders,quantity_matched_orders=s.quantity_matched_orders,
    match_rate=case when s.total_orders=0 then null else round(100.0*s.matched_orders/s.total_orders,4) end
  from (
    select count(*)::integer total_orders,count(*) filter(where overall_result='MATCH')::integer matched_orders,
      count(*) filter(where overall_result='MISMATCH')::integer mismatched_orders,
      count(*) filter(where overall_result='MISSING_CANONICAL')::integer missing_canonical_orders,
      count(*) filter(where overall_result='MISSING_LEGACY')::integer missing_legacy_orders,
      count(*) filter(where quantity_result<>'NOT_COMPARABLE')::integer comparable_quantity_orders,
      count(*) filter(where quantity_result='MATCH')::integer quantity_matched_orders
    from production_reconciliation_items where reconciliation_run_id=v_run_id
  ) s where r.id=v_run_id;
  return v_run_id;
exception when others then
  if v_run_id is not null then update production_reconciliation_runs set status='FAILED',completed_at=now(),error_message=left(sqlerrm,1000) where id=v_run_id; end if;
  raise;
end $function$
;
CREATE OR REPLACE FUNCTION public.seed_source_operation_mappings(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare affected integer;
begin
  insert into source_operation_mappings(organization_id,source_dataset,source_field,match_type,match_value,operation_id,completion_semantics,priority)
  select p_organization_id, x.dataset, x.field_name, x.match_type, x.match_value, o.id, x.semantics, x.priority
  from (values
    ('WORKBANK','queue','EXACT','SP11','PICKING','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','SP11','PICKING','ENTERED_OPERATION',10),
    ('WORKBANK','queue','EXACT','PCOR','DTG_PRINT','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',10),
    ('AUDIT','task','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',20),
    ('AUDIT','to_zone','EXACT','PWL1','PUTWALL','ENTERED_OPERATION',10),
    ('AUDIT','from_zone','EXACT','PWL1','PUTWALL','COMPLETED_OPERATION',10),
    ('STOCK','source_zone','EXACT','PWL1','PUTWALL','CURRENT_LOCATION',10),
    ('AUDIT','to_location','EXACT','DTGMOVE','DISPATCH','MOVED_TO_OPERATION',10),
    ('STOCK','location','LIKE','%UNDERPRINT%','UNDERPRINT','CURRENT_LOCATION',10),
    ('WORKBANK','from_location','SUFFIX','UP','UNDERPRINT','CURRENT_LOCATION',20),
    ('AUDIT','to_location','EXACT','UPMOVE','DISPATCH','MOVED_TO_OPERATION',20)
  ) x(dataset,field_name,match_type,match_value,operation_code,semantics,priority)
  join operations o on o.organization_id=p_organization_id and o.code=x.operation_code
  on conflict do nothing;
  get diagnostics affected=row_count;
  return affected;
end $function$
;
CREATE OR REPLACE FUNCTION public.source_value_matches(p_actual text, p_match_type text, p_expected text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  select case p_match_type
    when 'EXACT' then upper(coalesce(p_actual,'')) = upper(p_expected)
    when 'PREFIX' then upper(coalesce(p_actual,'')) like upper(p_expected) || '%'
    when 'SUFFIX' then upper(coalesce(p_actual,'')) like '%' || upper(p_expected)
    when 'LIKE' then upper(coalesce(p_actual,'')) like upper(p_expected)
    else false
  end
$function$
;
CREATE OR REPLACE FUNCTION public.transition_daily_plan(p_plan_id uuid, p_action text, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare stat text;items integer;begin select status into stat from production_plans where id=p_plan_id for update;select count(*)into items from production_plan_items where production_plan_id=p_plan_id;if p_action='publish'then if stat<>'draft'or items=0 then raise exception 'Only non-empty drafts can be published';end if;update production_plans set status='published',published_by=p_actor_id,published_at=now(),updated_at=now()where id=p_plan_id;elsif p_action='close'then if stat<>'published'then raise exception 'Only published plans can be closed';end if;update production_plans set status='closed',closed_by=p_actor_id,closed_at=now(),updated_at=now()where id=p_plan_id;else raise exception 'Invalid action';end if;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select p_plan_id,p_action,p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=p_plan_id;end$function$
;
CREATE OR REPLACE FUNCTION public.update_daily_plan_item(p_item_id uuid, p_sequence integer, p_responsible text, p_units numeric, p_actor_id uuid, p_actor_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare pid uuid;stat text;begin select i.production_plan_id,p.status into pid,stat from production_plan_items i join production_plans p on p.id=i.production_plan_id where i.id=p_item_id for update;if stat<>'draft'then raise exception 'Only drafts can be edited';end if;update production_plan_items set sequence=p_sequence,responsible=nullif(trim(p_responsible),''),planned_units=p_units,updated_at=now()where id=p_item_id;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select pid,'item_updated',p_actor_id,p_actor_email,to_jsonb(i)from production_plan_items i where id=p_item_id;end$function$
;
CREATE OR REPLACE FUNCTION public.update_manufacturing_order_line_quantity(p_organization_id uuid, p_source_system text, p_source_order_no text, p_source_order_line_id text, p_new_quantity numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare d production_demand_lines%rowtype;line manufacturing_order_lines%rowtype;po production_orders%rowtype;
begin
  if p_new_quantity<=0 then raise exception 'Quantity must be positive';end if;
  select * into strict d from production_demand_lines where organization_id=p_organization_id and source_system=p_source_system and source_order_no=p_source_order_no and source_order_line_id=p_source_order_line_id for update;
  select * into line from manufacturing_order_lines where production_demand_line_id=d.id;
  if line.id is null then update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;return 'DEMAND_UPDATED';end if;
  select * into strict po from production_orders where id=line.manufacturing_order_id for update;
  if po.production_status in('UNROUTED','PLANNED','RELEASED') then
    update production_demand_lines set quantity=p_new_quantity,updated_at=now() where id=d.id;
    update manufacturing_order_lines set planned_quantity=p_new_quantity where id=line.id;
    return 'MO_UPDATED';
  end if;
  insert into production_routing_exceptions(organization_id,production_order_id,exception_type,description,source_dataset,source_record_key)
  values(p_organization_id,po.id,'SOURCE_QUANTITY_CHANGE',format('Source quantity changed from %s to %s (delta %s)',d.quantity,p_new_quantity,p_new_quantity-d.quantity),'ORDER_LINE',p_source_order_no||':'||p_source_order_line_id);
  return 'EXCEPTION_CREATED';
end$function$
;
CREATE OR REPLACE FUNCTION public.validate_product_default_routing()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$begin
  if new.default_routing_id is not null and not exists(select 1 from routings r where r.id=new.default_routing_id and r.organization_id=new.organization_id and r.status='ACTIVE'and r.active and(r.effective_from is null or r.effective_from<=current_date)and(r.effective_to is null or r.effective_to>=current_date))then raise exception 'Product default routing must be active, effective and in the same organization';end if;return new;
end$function$
;
CREATE OR REPLACE FUNCTION public.move_routing_operation(p_operation_id uuid, p_direction text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$declare route uuid;ids uuid[];position integer;swap uuid;i integer;begin
  if p_direction not in('up','down')then raise exception 'Direction must be up or down';end if;
  select routing_id into strict route from routing_operations where id=p_operation_id;
  select array_agg(id order by sequence)into ids from routing_operations where routing_id=route;
  position:=array_position(ids,p_operation_id);if position is null or(p_direction='up'and position=1)or(p_direction='down'and position=array_length(ids,1))then return;end if;
  i:=case when p_direction='up'then position-1 else position+1 end;swap:=ids[i];ids[i]:=ids[position];ids[position]:=swap;
  update routing_operations set sequence=sequence+100000 where routing_id=route;
  for i in 1..array_length(ids,1)loop update routing_operations set sequence=i*10 where id=ids[i];end loop;
end$function$
;
create or replace view public."maintenance_asset_current_installations" as
 SELECT i.id,
    i.organization_id,
    i.movement_id,
    i.movable_asset_id,
    i.host_asset_id,
    i.host_system_asset_id,
    i."position",
    i.channel,
    i.installed_at,
    i.removed_at,
    i.movement_reason,
    i.installed_by,
    i.notes,
    i.created_at,
    i.updated_at,
    m.asset_code AS movable_asset_code,
    h.asset_code AS host_asset_code,
    s.asset_code AS host_system_asset_code
   FROM (((maintenance_asset_installations i
     JOIN maintenance_assets m ON ((m.id = i.movable_asset_id)))
     JOIN maintenance_assets h ON ((h.id = i.host_asset_id)))
     LEFT JOIN maintenance_assets s ON ((s.id = i.host_system_asset_id)))
  WHERE (i.removed_at IS NULL);;
create or replace view public."maintenance_part_stock_levels" as
 SELECT p.organization_id,
    p.id AS part_id,
    p.part_number,
    p.description,
    p.manufacturer,
    p.unit_cost,
    p.reorder_point,
    l.id AS location_id,
    l.name AS location,
    (COALESCE(sum(t.quantity), (0)::numeric))::numeric(14,2) AS stock_on_hand
   FROM ((maintenance_parts p
     CROSS JOIN maintenance_inventory_locations l)
     LEFT JOIN maintenance_inventory_transactions t ON (((t.part_id = p.id) AND (t.location_id = l.id))))
  WHERE (p.active AND l.active AND (p.organization_id = l.organization_id))
  GROUP BY p.organization_id, p.id, l.id;;
create or replace view public."v_authoritative_release_lines" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.sync_batch_id
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text) AND (oracle_line_ingestion_runs.status = 'COMPLETED'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC
        )
 SELECT s.organization_id,
    l.sync_batch_id,
    'ORACLE_WMS'::text AS source_system,
    s.source_order_no,
    s.source_line_id,
    s.source_product_code,
    s.source_description,
    s.production_units,
    s.released,
    s.raw_release_value,
    s.source_line_status,
    s.quantity_processed,
    s.source_weight,
    s.stock_reserved_flag,
    s.source_updated_at,
    l.id AS ingestion_run_id,
    s.source_routing,
    s.source_operational_code,
    s.source_operational_codes,
    s.operational_code_conflict,
    s.process_origin_code,
    s.process_origin_codes,
    s.process_origin_conflict,
    s.process_origin_at
   FROM (oracle_line_ingestion_staging s
     JOIN latest l ON ((l.id = s.ingestion_run_id)))
UNION ALL
 SELECT x.organization_id,
    x.sync_batch_id,
    x.source_system,
    x.source_order_no,
    x.source_line_id,
    x.source_product_code,
    x.source_description,
    x.production_units,
    x.released,
    x.raw_release_value,
    x.source_line_status,
    x.quantity_processed,
    x.source_weight,
    x.stock_reserved_flag,
    x.source_updated_at,
    x.ingestion_run_id,
    x.source_routing,
    x.source_operational_code,
    x.source_operational_codes,
    x.operational_code_conflict,
    x.process_origin_code,
    x.process_origin_codes,
    x.process_origin_conflict,
    x.process_origin_at
   FROM source_order_release_lines x
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM latest
          WHERE (latest.organization_id = x.organization_id)))) AND (x.source_presence = 'ACTIVE'::text));;
create or replace view public."v_current_labour_segments" as
 WITH ranked AS (
         SELECT r_1.id,
            row_number() OVER (PARTITION BY r_1.organization_id, COALESCE(NULLIF(r_1.source_timesheet_id, ''::text), r_1.source_row_key) ORDER BY b.imported_at DESC, r_1.created_at DESC) AS rn
           FROM (deputy_raw_timesheets r_1
             JOIN deputy_import_batches b ON ((b.id = r_1.import_batch_id)))
          WHERE ((b.status = 'COMPLETED'::text) AND (r_1.row_status = 'ACCEPTED'::text))
        )
 SELECT s.id,
    s.organization_id,
    s.import_batch_id,
    s.source_timesheet_row_id,
    s.person_key,
    s.area_code,
    s.segment_start,
    s.segment_end,
    s.calendar_date,
    s.operational_date,
    s.hour_bucket,
    s.shift_code,
    s.paid_hours,
    s.regular_hours,
    s.overtime_hours,
    s.paid_break_hours,
    s.productive_hours,
    s.approval_status,
    s.allocation_method,
    s.week_start,
    s.calculation_version,
    s.created_at
   FROM (labour_segments s
     JOIN ranked r ON (((r.id = s.source_timesheet_row_id) AND (r.rn = 1))));;
create or replace view public."v_daily_plans" as
 SELECT p.id,
    p.organization_id,
    p.production_date,
    p.shift_template_id,
    p.production_area_id,
    p.status,
    p.version,
    p.created_by,
    p.published_by,
    p.published_at,
    p.closed_by,
    p.closed_at,
    p.created_at,
    p.updated_at,
    s.name AS shift_name,
    a.code AS area_code,
    a.name AS area_name,
    count(i.id) AS item_count,
    COALESCE(sum(i.planned_units), (0)::numeric) AS planned_units
   FROM (((production_plans p
     JOIN shift_templates s ON ((s.id = p.shift_template_id)))
     JOIN production_areas a ON ((a.id = p.production_area_id)))
     LEFT JOIN production_plan_items i ON ((i.production_plan_id = p.id)))
  GROUP BY p.id, s.name, a.code, a.name;;
create or replace view public."v_dtg_order_history" as
 SELECT order_no,
    count(*) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS printed,
    min(event_at) FILTER (WHERE ((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text))) AS first_pick,
    min(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS first_print,
    max(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS last_print
   FROM source_audit_events
  WHERE (((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text)) OR ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text)))
  GROUP BY order_no;;
create or replace view public."v_kpi_dashboard" as
 SELECT d.id AS definition_id,
    d.organization_id,
    d.code,
    d.name,
    d.category,
    d.unit,
    d.data_readiness_status,
    d.dashboard_priority,
    r.value,
    r.numerator,
    r.denominator,
    r.status,
    r.data_quality_status,
    r.production_area_id,
    a.code AS area_code,
    r.source_refresh_at,
    r.calculated_at
   FROM ((kpi_definitions d
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.kpi_definition_id,
            x.period_start,
            x.period_end,
            x.production_date,
            x.production_area_id,
            x.shift_id,
            x.machine_id,
            x.operator_id,
            x.order_no,
            x.product_code,
            x.numerator,
            x.denominator,
            x.value,
            x.target_value,
            x.status,
            x.data_quality_status,
            x.source_refresh_at,
            x.calculated_at
           FROM kpi_results x
          WHERE (x.kpi_definition_id = d.id)
          ORDER BY x.calculated_at DESC
         LIMIT 1) r ON (true))
     LEFT JOIN production_areas a ON ((a.id = r.production_area_id)));;
create or replace view public."v_kpi_trends" as
 WITH daily_base AS (
         SELECT DISTINCT ON (r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid)) r.organization_id,
            r.kpi_definition_id,
            r.production_area_id,
            r.production_date,
            r.value
           FROM kpi_results r
          WHERE (r.value IS NOT NULL)
          ORDER BY r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid), r.calculated_at DESC
        ), periods AS (
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'DAILY'::text AS period_type,
            daily_base.production_date AS period_start,
            daily_base.production_date AS period_end,
            (1)::bigint AS points,
            daily_base.value AS latest_value,
            daily_base.value AS average_value,
            daily_base.value AS minimum_value,
            daily_base.value AS maximum_value
           FROM daily_base
        UNION ALL
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'WEEKLY'::text,
            (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,
            ((date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone) + '6 days'::interval))::date AS date,
            count(*) AS count,
            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,
            avg(daily_base.value) AS avg,
            min(daily_base.value) AS min,
            max(daily_base.value) AS max
           FROM daily_base
          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))
        UNION ALL
         SELECT daily_base.organization_id,
            daily_base.kpi_definition_id,
            daily_base.production_area_id,
            'MONTHLY'::text,
            (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,
            ((date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone) + '1 mon -1 days'::interval))::date AS date,
            count(*) AS count,
            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,
            avg(daily_base.value) AS avg,
            min(daily_base.value) AS min,
            max(daily_base.value) AS max
           FROM daily_base
          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))
        ), compared AS (
         SELECT p.organization_id,
            p.kpi_definition_id,
            p.production_area_id,
            p.period_type,
            p.period_start,
            p.period_end,
            p.points,
            p.latest_value,
            p.average_value,
            p.minimum_value,
            p.maximum_value,
            lag(p.latest_value) OVER (PARTITION BY p.organization_id, p.kpi_definition_id, p.production_area_id, p.period_type ORDER BY p.period_start) AS previous_value
           FROM periods p
        )
 SELECT organization_id,
    kpi_definition_id,
    production_area_id,
    period_type,
    period_start,
    period_end,
    points,
    latest_value,
    average_value,
    minimum_value,
    maximum_value,
    previous_value,
    (latest_value - previous_value) AS absolute_change,
        CASE
            WHEN (previous_value = (0)::numeric) THEN NULL::numeric
            ELSE round((((latest_value - previous_value) / abs(previous_value)) * (100)::numeric), 2)
        END AS percentage_change
   FROM compared c;;
create or replace view public."v_latest_completed_batch" as
 SELECT DISTINCT ON (organization_id) id,
    organization_id,
    started_at,
    completed_at,
    status,
    orders_count,
    workbank_count,
    stock_count,
    audit_new_count,
    error_message,
    connector_version,
    created_at
   FROM sync_batches
  WHERE (status = 'completed'::text)
  ORDER BY organization_id, completed_at DESC;;
create or replace view public."v_latest_production_reconciliation" as
 SELECT DISTINCT ON (organization_id) id,
    organization_id,
    sync_batch_id,
    status,
    quantity_tolerance,
    total_orders,
    matched_orders,
    mismatched_orders,
    missing_canonical_orders,
    missing_legacy_orders,
    comparable_quantity_orders,
    quantity_matched_orders,
    match_rate,
    started_at,
    completed_at,
    error_message,
    created_at
   FROM production_reconciliation_runs
  WHERE (status = 'COMPLETED'::text)
  ORDER BY organization_id, completed_at DESC;;
create or replace view public."v_latest_production_reconciliation_items" as
 SELECT i.id,
    i.organization_id,
    i.reconciliation_run_id,
    i.order_no,
    i.legacy_area,
    i.expected_operation_code,
    i.canonical_operation_code,
    i.legacy_remaining_quantity,
    i.canonical_remaining_quantity,
    i.quantity_variance,
    i.presence_result,
    i.operation_result,
    i.quantity_result,
    i.overall_result,
    i.detail,
    i.created_at
   FROM (production_reconciliation_items i
     JOIN v_latest_production_reconciliation r ON ((r.id = i.reconciliation_run_id)));;
create or replace view public."v_manufacturing_order_product_mix" as
 SELECT po.organization_id,
    po.id AS manufacturing_order_id,
    po.mo_number,
    po.source_order_no,
    po.routing_code_snapshot,
    l.product_id,
    p.sku,
    p.description,
    (sum(l.planned_quantity))::numeric(14,3) AS planned_quantity,
    round(((sum(l.planned_quantity) / NULLIF(po.planned_quantity, (0)::numeric)) * (100)::numeric), 1) AS mix_percent
   FROM ((production_orders po
     JOIN manufacturing_order_lines l ON ((l.manufacturing_order_id = po.id)))
     LEFT JOIN products p ON (((p.id = l.product_id) AND (p.organization_id = l.organization_id))))
  GROUP BY po.organization_id, po.id, po.mo_number, po.source_order_no, po.routing_code_snapshot, l.product_id, p.sku, p.description, po.planned_quantity;;
create or replace view public."v_production_order_execution" as
 SELECT po.organization_id,
    po.id AS production_order_id,
    po.order_no,
    po.source_order_no,
    po.product_id,
    po.routing_code_snapshot,
    po.routing_name_snapshot,
    po.routing_revision_snapshot,
    po.production_status,
    po.planned_quantity,
    po.actual_quantity,
    po.planned_date,
    po.planned_shift_id,
    po.planner_priority,
    current_op.id AS current_operation_id,
    current_op.sequence AS current_operation_sequence,
    current_op.operation_code_snapshot AS current_operation_code,
    current_op.operation_name_snapshot AS current_operation_name,
    next_op.id AS next_operation_id,
    next_op.sequence AS next_operation_sequence,
    next_op.operation_code_snapshot AS next_operation_code,
    next_op.operation_name_snapshot AS next_operation_name,
    last_op.id AS last_completed_operation_id,
    last_op.sequence AS last_completed_operation_sequence,
    last_op.operation_code_snapshot AS last_completed_operation_code,
    last_op.operation_name_snapshot AS last_completed_operation_name
   FROM (((production_orders po
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['IN_PROGRESS'::text, 'READY'::text, 'PENDING'::text, 'ON_HOLD'::text])))
          ORDER BY
                CASE x.status
                    WHEN 'IN_PROGRESS'::text THEN 0
                    WHEN 'ON_HOLD'::text THEN 1
                    WHEN 'READY'::text THEN 2
                    ELSE 3
                END, x.sequence
         LIMIT 1) current_op ON (true))
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['READY'::text, 'PENDING'::text])) AND ((current_op.sequence IS NULL) OR (x.sequence > current_op.sequence)))
          ORDER BY x.sequence
         LIMIT 1) next_op ON (true))
     LEFT JOIN LATERAL ( SELECT x.id,
            x.organization_id,
            x.production_order_id,
            x.source_routing_operation_id,
            x.source_operation_id,
            x.sequence,
            x.operation_code_snapshot,
            x.operation_name_snapshot,
            x.work_center_code_snapshot,
            x.work_center_name_snapshot,
            x.required,
            x.setup_minutes_snapshot,
            x.run_rate_snapshot,
            x.queue_minutes_snapshot,
            x.instructions_snapshot,
            x.status,
            x.planned_quantity,
            x.actual_quantity,
            x.planned_date,
            x.planned_shift_id,
            x.started_at,
            x.completed_at,
            x.created_at,
            x.updated_at
           FROM production_order_operations x
          WHERE ((x.production_order_id = po.id) AND (x.status = ANY (ARRAY['COMPLETED'::text, 'SKIPPED'::text])))
          ORDER BY x.sequence DESC
         LIMIT 1) last_op ON (true));;
create or replace view public."v_production_order_routing_status" as
 SELECT po.organization_id,
    po.id AS production_order_id,
    po.order_no,
    po.source_order_no,
    po.production_status,
    count(poo.id) AS operation_count,
    count(poo.id) FILTER (WHERE (poo.status = 'COMPLETED'::text)) AS completed_operation_count,
    count(e.id) AS evidence_count,
    count(ex.id) FILTER (WHERE (ex.status = ANY (ARRAY['OPEN'::text, 'ACKNOWLEDGED'::text]))) AS open_exception_count,
    max(e.observed_at) AS last_source_observed_at
   FROM (((production_orders po
     LEFT JOIN production_order_operations poo ON ((poo.production_order_id = po.id)))
     LEFT JOIN production_order_operation_evidence e ON ((e.production_order_id = po.id)))
     LEFT JOIN production_routing_exceptions ex ON ((ex.production_order_id = po.id)))
  GROUP BY po.organization_id, po.id, po.order_no, po.source_order_no, po.production_status;;
create or replace view public."v_production_reconciliation_gate" as
 SELECT id,
    organization_id,
    sync_batch_id,
    status,
    quantity_tolerance,
    total_orders,
    matched_orders,
    mismatched_orders,
    missing_canonical_orders,
    missing_legacy_orders,
    comparable_quantity_orders,
    quantity_matched_orders,
    match_rate,
    started_at,
    completed_at,
    error_message,
    created_at,
        CASE
            WHEN (total_orders = 0) THEN 'NO_DATA'::text
            WHEN (missing_canonical_orders > 0) THEN 'BLOCKED_MISSING_CANONICAL'::text
            WHEN (match_rate >= (98)::numeric) THEN 'READY_FOR_UI_PILOT'::text
            WHEN (match_rate >= (90)::numeric) THEN 'REVIEW_REQUIRED'::text
            ELSE 'NOT_READY'::text
        END AS migration_gate
   FROM v_latest_production_reconciliation r;;
create or replace view public."v_release_reactivation_candidates" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.completed_at
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.status = 'COMPLETED'::text) AND (oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC, oracle_line_ingestion_runs.id DESC
        ), candidates AS (
         SELECT s.organization_id,
            s.source_order_no,
            s.source_line_id,
            s.production_units AS source_quantity,
            l.id AS reactivation_snapshot_run_id,
            l.completed_at AS reactivation_at,
            d.id AS production_demand_line_id,
            d.status AS demand_status,
            ml.id AS manufacturing_order_line_id,
            ml.manufacturing_order_id,
            ml.planned_quantity AS mapped_quantity,
            ml.actual_quantity AS executed_quantity,
            ml.created_at AS original_mapping_at,
            po.mo_number,
            po.production_status AS mo_status,
            ((d.resolution_status = 'RESOLVED'::text) AND (d.product_id IS NOT NULL) AND (d.routing_revision_id IS NOT NULL) AND (d.product_id = ml.product_id) AND (d.routing_revision_id = ml.routing_revision_id) AND (d.routing_revision_id = po.source_routing_id)) AS currently_eligible,
            rev.original_snapshot_run_id,
            rev.event_snapshot_run_id AS revocation_snapshot_run_id
           FROM (((((latest l
             JOIN oracle_line_ingestion_staging s ON ((s.ingestion_run_id = l.id)))
             JOIN production_demand_lines d ON (((d.organization_id = s.organization_id) AND (d.source_order_no = s.source_order_no) AND ((d.source_order_line_id = ('E56:'::text || s.source_line_id)) OR (d.source_order_line_id = ('E6:'::text || s.source_line_id))))))
             JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
             JOIN production_orders po ON ((po.id = ml.manufacturing_order_id)))
             JOIN LATERAL ( SELECT e.original_snapshot_run_id,
                    e.event_snapshot_run_id
                   FROM production_demand_release_events e
                  WHERE ((e.production_demand_line_id = d.id) AND (e.event_type = 'RELEASE_REVOKED_AFTER_MAPPING'::text))
                  ORDER BY e.event_at DESC, e.id DESC
                 LIMIT 1) rev ON (true))
          WHERE ((s.released = true) AND (s.raw_release_value = 'Y'::text) AND (d.status = 'CANCELLED'::text))
        )
 SELECT organization_id,
    source_order_no,
    source_line_id,
    source_quantity,
    reactivation_snapshot_run_id,
    reactivation_at,
    production_demand_line_id,
    demand_status,
    manufacturing_order_line_id,
    manufacturing_order_id,
    mapped_quantity,
    executed_quantity,
    original_mapping_at,
    mo_number,
    mo_status,
    currently_eligible,
    original_snapshot_run_id,
    revocation_snapshot_run_id,
    release_reactivation_action(mo_status, executed_quantity, currently_eligible) AS recommended_action
   FROM candidates c;;
create or replace view public."v_release_revocation_candidates" as
 WITH latest AS (
         SELECT DISTINCT ON (oracle_line_ingestion_runs.organization_id) oracle_line_ingestion_runs.id,
            oracle_line_ingestion_runs.organization_id,
            oracle_line_ingestion_runs.completed_at
           FROM oracle_line_ingestion_runs
          WHERE ((oracle_line_ingestion_runs.status = 'COMPLETED'::text) AND (oracle_line_ingestion_runs.snapshot_status = 'COMPLETE'::text))
          ORDER BY oracle_line_ingestion_runs.organization_id, oracle_line_ingestion_runs.completed_at DESC, oracle_line_ingestion_runs.id DESC
        )
 SELECT s.organization_id,
    s.source_order_no,
    s.source_line_id,
    s.production_units AS source_quantity,
    l.id AS revocation_snapshot_run_id,
    l.completed_at AS revocation_at,
    d.id AS production_demand_line_id,
    d.status AS demand_status,
    ml.id AS manufacturing_order_line_id,
    ml.manufacturing_order_id,
    ml.planned_quantity AS mapped_quantity,
    ml.actual_quantity AS executed_quantity,
    ml.created_at AS original_mapping_at,
    po.mo_number,
    po.production_status AS mo_status,
    o.id AS original_snapshot_run_id,
    o.released AS original_released,
    o.raw_release_value AS original_raw_release_value,
    ((o.released = true) AND (o.raw_release_value = 'Y'::text)) AS valid_at_creation,
    release_revocation_action(po.production_status, ml.actual_quantity, ((o.released = true) AND (o.raw_release_value = 'Y'::text))) AS recommended_action
   FROM (((((latest l
     JOIN oracle_line_ingestion_staging s ON ((s.ingestion_run_id = l.id)))
     JOIN production_demand_lines d ON (((d.organization_id = s.organization_id) AND (d.source_order_no = s.source_order_no) AND ((d.source_order_line_id = ('E56:'::text || s.source_line_id)) OR (d.source_order_line_id = ('E6:'::text || s.source_line_id))))))
     JOIN manufacturing_order_lines ml ON ((ml.production_demand_line_id = d.id)))
     JOIN production_orders po ON ((po.id = ml.manufacturing_order_id)))
     LEFT JOIN LATERAL ( SELECT r.id,
            x.released,
            x.raw_release_value
           FROM (oracle_line_ingestion_runs r
             JOIN oracle_line_ingestion_staging x ON (((x.ingestion_run_id = r.id) AND (x.organization_id = s.organization_id) AND (x.source_order_no = s.source_order_no) AND (x.source_line_id = s.source_line_id))))
          WHERE ((r.status = 'COMPLETED'::text) AND (r.snapshot_status = 'COMPLETE'::text) AND (r.completed_at <= ml.created_at))
          ORDER BY r.completed_at DESC, r.id DESC
         LIMIT 1) o ON (true))
  WHERE ((s.released = false) AND (s.raw_release_value = 'N'::text));;
create or replace view public."v_source_reconciliation" as
 SELECT organization_id,
    id AS sync_batch_id,
    completed_at,
    orders_count AS batch_orders,
    ( SELECT count(*) AS count
           FROM source_orders o
          WHERE (o.sync_batch_id = b.id)) AS current_orders,
    workbank_count AS batch_workbank,
    ( SELECT count(*) AS count
           FROM source_workbank_items w
          WHERE (w.sync_batch_id = b.id)) AS current_workbank,
    stock_count AS batch_stock,
    ( SELECT count(*) AS count
           FROM source_stock_items s
          WHERE (s.sync_batch_id = b.id)) AS current_stock,
    audit_new_count
   FROM v_latest_completed_batch b;;
create or replace view public.v_current_orders
with (security_invoker = true)
as
select
  o.id,
  o.organization_id,
  o.sync_batch_id,
  o.order_no,
  o.date_received,
  o.date_due,
  o.date_released,
  o.source_status,
  o.source_sub_status,
  o.customer_code,
  o.customer_name,
  o.ship_to_name,
  o.customer_state,
  o.city,
  o.delivery_desc,
  o.client_so_number,
  o.source_priority,
  o.source_updated_at,
  o.created_at,
  o.site,
  o.source_route_id,
  o.cost_centre,
  o.stop_ship_flag,
  o.release_source_status
from public.source_orders o
join public.v_latest_completed_batch b
  on b.id = o.sync_batch_id
 and b.organization_id = o.organization_id;
create or replace view public."v_current_release_order_lines" as
 SELECT l.id,
    l.organization_id,
    l.sync_batch_id,
    l.order_no,
    l.line_number,
    l.product,
    l.client,
    l.qty_lcd,
    l.orig_ref3,
    l.group_code,
    l.product_name,
    l.source_updated_at,
    l.created_at
   FROM (source_release_order_lines l
     JOIN v_latest_completed_batch b ON ((b.id = l.sync_batch_id)));;
create or replace view public."v_current_stock" as
 SELECT s.id,
    s.organization_id,
    s.sync_batch_id,
    s.product,
    s.pack_id,
    s.location,
    s.source_timestamp,
    s.source_qty,
    s.source_weight,
    s.production_units,
    s.created_at,
    s.source_zone
   FROM (source_stock_items s
     JOIN v_latest_completed_batch b ON ((b.id = s.sync_batch_id)));;
create or replace view public."v_current_workbank" as
 SELECT w.id,
    w.organization_id,
    w.sync_batch_id,
    w.source_row_id,
    w.order_no,
    w.customer_code,
    w.customer_name,
    w.source_due_at,
    w.from_location,
    w.from_zone,
    w.to_location,
    w.from_pack_id,
    w.to_pack_id,
    w.source_priority,
    w.product_code,
    w.product_description,
    w.product_group,
    w.source_qty,
    w.source_weight,
    w.production_units,
    w.queue,
    w.task,
    w.created_at,
    w.prints_per_garment
   FROM (source_workbank_items w
     JOIN v_latest_completed_batch b ON ((b.id = w.sync_batch_id)));;
create or replace view public."v_dtg_operational_orders" as
 SELECT w.organization_id,
    w.order_no,
    max(COALESCE(w.customer_name, o.customer_name)) AS customer_name,
    max(o.delivery_desc) AS screen,
    max(o.source_status) AS status,
    max(COALESCE(w.source_priority, o.source_priority)) AS priority,
    min(COALESCE(w.source_due_at, o.date_due)) AS date_due,
    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((max(o.date_released) AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,
    count(*) AS item_count,
    (count(*))::numeric AS remaining_units,
    NULL::timestamp with time zone AS last_movement,
    string_agg(DISTINCT COALESCE(NULLIF(w.to_location, ''::text), w.from_location), ', '::text ORDER BY COALESCE(NULLIF(w.to_location, ''::text), w.from_location)) AS putwall_locations,
    'At DTG'::text AS progress_label,
    sum(w.prints_per_garment) AS total_prints,
    sum(
        CASE
            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text)) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS adult_prints,
    sum(
        CASE
            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text)) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS kids_prints,
    sum(
        CASE
            WHEN (NOT ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text))) THEN w.prints_per_garment
            ELSE (0)::numeric
        END) AS unclassified_prints
   FROM (v_current_workbank w
     LEFT JOIN v_current_orders o ON (((o.organization_id = w.organization_id) AND (o.order_no = w.order_no))))
  WHERE (upper(COALESCE(w.from_zone, ''::text)) = 'DTGS'::text)
  GROUP BY w.organization_id, w.order_no;;
create or replace view public."v_manufacturing_order_current_operation" as
 SELECT e.organization_id,
    e.production_order_id AS manufacturing_order_id,
    po.mo_number,
    COALESCE(e.source_order_no, e.order_no) AS source_order_no,
    po.routing_code_snapshot,
    po.routing_revision_snapshot,
    e.production_status,
    e.planned_quantity,
    e.actual_quantity,
    GREATEST((COALESCE(e.planned_quantity, (0)::numeric) - COALESCE(e.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    e.planned_date,
    e.planner_priority,
    e.current_operation_id,
    e.current_operation_code,
    e.current_operation_name,
    e.next_operation_id,
    e.next_operation_code,
    e.next_operation_name,
    e.last_completed_operation_id,
    e.last_completed_operation_code
   FROM (v_production_order_execution e
     JOIN production_orders po ON ((po.id = e.production_order_id)))
  WHERE (po.source_routing_id IS NOT NULL);;
create or replace view public."v_manufacturing_order_progress" as
 SELECT m.organization_id,
    m.manufacturing_order_id,
    m.mo_number,
    m.source_order_no,
    m.routing_code_snapshot,
    m.routing_revision_snapshot,
    m.production_status,
    m.planned_quantity,
    m.actual_quantity,
    m.remaining_quantity,
    m.planned_date,
    m.planner_priority,
    m.current_operation_id,
    m.current_operation_code,
    m.current_operation_name,
    m.next_operation_id,
    m.next_operation_code,
    m.next_operation_name,
    m.last_completed_operation_id,
    m.last_completed_operation_code,
    count(op.id) AS operation_count,
    count(op.id) FILTER (WHERE (op.status = 'COMPLETED'::text)) AS completed_operation_count,
    round((((count(op.id) FILTER (WHERE (op.status = 'COMPLETED'::text)))::numeric / (NULLIF(count(op.id), 0))::numeric) * (100)::numeric), 1) AS routing_progress_percent
   FROM (v_manufacturing_order_current_operation m
     LEFT JOIN production_order_operations op ON ((op.production_order_id = m.manufacturing_order_id)))
  GROUP BY m.organization_id, m.manufacturing_order_id, m.mo_number, m.source_order_no, m.routing_code_snapshot, m.routing_revision_snapshot, m.production_status, m.planned_quantity, m.actual_quantity, m.remaining_quantity, m.planned_date, m.planner_priority, m.current_operation_id, m.current_operation_code, m.current_operation_name, m.next_operation_id, m.next_operation_code, m.next_operation_name, m.last_completed_operation_id, m.last_completed_operation_code;;
create or replace view public."v_manufacturing_order_routing_status" as
 SELECT p.organization_id,
    p.manufacturing_order_id,
    p.mo_number,
    p.source_order_no,
    p.routing_code_snapshot,
    p.routing_revision_snapshot,
    p.production_status,
    p.planned_quantity,
    p.actual_quantity,
    p.remaining_quantity,
    p.planned_date,
    p.planner_priority,
    p.current_operation_id,
    p.current_operation_code,
    p.current_operation_name,
    p.next_operation_id,
    p.next_operation_code,
    p.next_operation_name,
    p.last_completed_operation_id,
    p.last_completed_operation_code,
    p.operation_count,
    p.completed_operation_count,
    p.routing_progress_percent,
    COALESCE(s.open_exception_count, (0)::bigint) AS open_exception_count,
    s.last_source_observed_at,
        CASE
            WHEN (COALESCE(s.open_exception_count, (0)::bigint) > 0) THEN 'DEVIATION'::text
            WHEN (s.evidence_count > 0) THEN 'VALIDATED'::text
            ELSE 'AWAITING_EVIDENCE'::text
        END AS validation_status
   FROM (v_manufacturing_order_progress p
     LEFT JOIN v_production_order_routing_status s ON ((s.production_order_id = p.manufacturing_order_id)));;
create or replace view public."v_order_stage_summary" as
 WITH classified AS (
         SELECT w.id,
            w.organization_id,
            w.sync_batch_id,
            w.source_row_id,
            w.order_no,
            w.customer_code,
            w.customer_name,
            w.source_due_at,
            w.from_location,
            w.from_zone,
            w.to_location,
            w.from_pack_id,
            w.to_pack_id,
            w.source_priority,
            w.product_code,
            w.product_description,
            w.product_group,
            w.source_qty,
            w.source_weight,
            w.production_units,
            w.queue,
            w.task,
            w.created_at,
            COALESCE(mapped.code, 'UNMAPPED'::text) AS stage_code,
            COALESCE(mapped.name, 'Unmapped'::text) AS stage_name,
            (w.production_units * COALESCE(rule.multiplier, (1)::numeric)) AS converted_units
           FROM ((v_current_workbank w
             LEFT JOIN LATERAL ( SELECT a.code,
                    a.name
                   FROM (production_stage_mappings m
                     JOIN production_areas a ON ((a.id = m.production_area_id)))
                  WHERE ((m.organization_id = w.organization_id) AND m.active AND a.active AND
                        CASE m.source_field
                            WHEN 'from_zone'::text THEN (COALESCE(w.from_zone, ''::text) ~~* m.match_pattern)
                            WHEN 'from_location'::text THEN (COALESCE(w.from_location, ''::text) ~~* m.match_pattern)
                            ELSE NULL::boolean
                        END)
                  ORDER BY m.priority
                 LIMIT 1) mapped ON (true))
             LEFT JOIN LATERAL ( SELECT r.multiplier
                   FROM quantity_conversion_rules r
                  WHERE ((r.organization_id = w.organization_id) AND r.active AND (COALESCE(w.product_group, ''::text) ~~* r.product_group_pattern))
                  ORDER BY r.priority
                 LIMIT 1) rule ON (true))
        )
 SELECT organization_id,
    order_no,
    max(customer_name) AS customer_name,
    min(source_due_at) AS due_at,
    stage_code,
    max(stage_name) AS stage_name,
    count(*) AS item_count,
    sum(converted_units) AS production_units,
    GREATEST(0, (CURRENT_DATE - COALESCE((min(source_due_at))::date, CURRENT_DATE))) AS age_days
   FROM classified
  GROUP BY organization_id, order_no, stage_code;;
create or replace view public."v_production_order_current_operation" as
 SELECT organization_id,
    production_order_id,
    order_no,
    source_order_no,
    routing_code_snapshot,
    production_status,
    planned_quantity,
    actual_quantity,
    current_operation_id,
    current_operation_sequence,
    current_operation_code,
    current_operation_name,
    next_operation_id,
    next_operation_code,
    next_operation_name,
    last_completed_operation_id,
    last_completed_operation_code,
    last_completed_operation_name
   FROM v_production_order_execution e;;
create or replace view public."v_production_order_progress" as
 SELECT c.organization_id,
    c.production_order_id,
    c.order_no,
    c.source_order_no,
    c.routing_code_snapshot,
    c.production_status,
    c.planned_quantity,
    c.actual_quantity,
    c.current_operation_id,
    c.current_operation_sequence,
    c.current_operation_code,
    c.current_operation_name,
    c.next_operation_id,
    c.next_operation_code,
    c.next_operation_name,
    c.last_completed_operation_id,
    c.last_completed_operation_code,
    c.last_completed_operation_name,
    GREATEST((COALESCE(c.planned_quantity, (0)::numeric) - COALESCE(c.actual_quantity, (0)::numeric)), (0)::numeric) AS remaining_quantity,
    s.operation_count,
    s.completed_operation_count,
    s.evidence_count,
    s.open_exception_count,
    s.last_source_observed_at
   FROM (v_production_order_current_operation c
     JOIN v_production_order_routing_status s USING (organization_id, production_order_id));;
create or replace view public."v_release_queue_all" as
 WITH process_qty AS (
         SELECT v_current_release_order_lines.organization_id,
            v_current_release_order_lines.sync_batch_id,
            v_current_release_order_lines.order_no,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))), (0)::numeric) AS dtg_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'UNDERPRINT'::text)), (0)::numeric) AS underprint_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'UV PRINT'::text)), (0)::numeric) AS uv_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'HATS'::text)), (0)::numeric) AS hats_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'FINISHED'::text)), (0)::numeric) AS finished_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'STICKERS'::text)), (0)::numeric) AS stickers_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'VISUAL'::text)), (0)::numeric) AS visual_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'PROD'::text)), (0)::numeric) AS production_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'CUSTOM EMB'::text)), (0)::numeric) AS custom_emb_qty,
            COALESCE(sum(v_current_release_order_lines.qty_lcd) FILTER (WHERE (upper(TRIM(BOTH FROM v_current_release_order_lines.group_code)) = 'EYEWEAR'::text)), (0)::numeric) AS eyewear_qty
           FROM v_current_release_order_lines
          GROUP BY v_current_release_order_lines.organization_id, v_current_release_order_lines.sync_batch_id, v_current_release_order_lines.order_no
        ), evidence AS (
         SELECT o.id,
            o.organization_id,
            o.sync_batch_id,
            o.order_no,
            o.date_received,
            o.date_due,
            o.date_released,
            o.source_status,
            o.source_sub_status,
            o.customer_code,
            o.customer_name,
            o.ship_to_name,
            o.customer_state,
            o.city,
            o.delivery_desc,
            o.client_so_number,
            o.source_priority,
            o.source_updated_at,
            o.created_at,
            o.site,
            o.source_route_id AS route_id,
            o.cost_centre,
            o.stop_ship_flag,
            o.release_source_status,
            b.completed_at AS snapshot_completed_at,
            COALESCE(p.dtg_qty, (0)::numeric) AS dtg_qty,
            COALESCE(p.underprint_qty, (0)::numeric) AS underprint_qty,
            COALESCE(p.uv_qty, (0)::numeric) AS uv_qty,
            COALESCE(p.hats_qty, (0)::numeric) AS hats_qty,
            COALESCE(p.finished_qty, (0)::numeric) AS finished_qty,
            COALESCE(p.stickers_qty, (0)::numeric) AS stickers_qty,
            COALESCE(p.visual_qty, (0)::numeric) AS visual_qty,
            COALESCE(p.production_qty, (0)::numeric) AS production_qty,
            COALESCE(p.custom_emb_qty, (0)::numeric) AS custom_emb_qty,
            COALESCE(p.eyewear_qty, (0)::numeric) AS eyewear_qty
           FROM ((v_current_orders o
             JOIN v_latest_completed_batch b ON ((b.id = o.sync_batch_id)))
             LEFT JOIN process_qty p ON (((p.organization_id = o.organization_id) AND (p.sync_batch_id = o.sync_batch_id) AND (p.order_no = o.order_no))))
          WHERE ((o.site = 'B'::text) AND (o.order_no ~~ '13%'::text) AND (o.release_source_status = '1'::text) AND ((o.date_due >= (now() - '30 days'::interval)) AND (o.date_due <= (now() + '30 days'::interval))))
        ), resolved AS (
         SELECT e.id,
            e.organization_id,
            e.sync_batch_id,
            e.order_no,
            e.date_received,
            e.date_due,
            e.date_released,
            e.source_status,
            e.source_sub_status,
            e.customer_code,
            e.customer_name,
            e.ship_to_name,
            e.customer_state,
            e.city,
            e.delivery_desc,
            e.client_so_number,
            e.source_priority,
            e.source_updated_at,
            e.created_at,
            e.site,
            e.route_id,
            e.cost_centre,
            e.stop_ship_flag,
            e.release_source_status,
            e.snapshot_completed_at,
            e.dtg_qty,
            e.underprint_qty,
            e.uv_qty,
            e.hats_qty,
            e.finished_qty,
            e.stickers_qty,
            e.visual_qty,
            e.production_qty,
            e.custom_emb_qty,
            e.eyewear_qty,
            (((((((((e.dtg_qty + e.underprint_qty) + e.uv_qty) + e.hats_qty) + e.finished_qty) + e.stickers_qty) + e.visual_qty) + e.production_qty) + e.custom_emb_qty) + e.eyewear_qty) AS total_process_qty,
            array_remove(ARRAY[
                CASE
                    WHEN (upper(TRIM(BOTH FROM e.route_id)) = 'NO'::text) THEN 'ROUTE_BLOCKED'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN (upper(TRIM(BOTH FROM e.stop_ship_flag)) = 'Y'::text) THEN 'STOP_SHIP'::text
                    ELSE NULL::text
                END,
                CASE
                    WHEN (e.custom_emb_qty > (0)::numeric) THEN 'CUSTOM_EMB'::text
                    ELSE NULL::text
                END], NULL::text) AS release_blockers
           FROM evidence e
        )
 SELECT id,
    organization_id,
    sync_batch_id,
    order_no,
    date_received,
    date_due,
    date_released,
    source_status,
    source_sub_status,
    customer_code,
    customer_name,
    ship_to_name,
    customer_state,
    city,
    delivery_desc,
    client_so_number,
    source_priority,
    source_updated_at,
    created_at,
    site,
    route_id,
    cost_centre,
    stop_ship_flag,
    release_source_status,
    snapshot_completed_at,
    dtg_qty,
    underprint_qty,
    uv_qty,
    hats_qty,
    finished_qty,
    stickers_qty,
    visual_qty,
    production_qty,
    custom_emb_qty,
    eyewear_qty,
    total_process_qty,
    release_blockers,
        CASE
            WHEN (total_process_qty <= (0)::numeric) THEN 'ZERO_PRODUCTION_QTY'::text
            ELSE NULL::text
        END AS diagnostic_status,
        CASE
            WHEN ((route_id IS NULL) OR (TRIM(BOTH FROM route_id) = ''::text) OR (stop_ship_flag IS NULL) OR (TRIM(BOTH FROM stop_ship_flag) = ''::text) OR (date_due IS NULL) OR (release_source_status IS NULL)) THEN 'UNKNOWN'::text
            WHEN (upper(TRIM(BOTH FROM COALESCE(cost_centre, ''::text))) = 'NOTAPPRO'::text) THEN 'NOT_APPROVED'::text
            WHEN (cardinality(release_blockers) > 0) THEN 'BLOCKED'::text
            WHEN ((date_due)::date > (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date + 7)) THEN 'FUTURE_DUE'::text
            ELSE 'ELIGIBLE'::text
        END AS release_status
   FROM resolved r;;
create or replace view public."v_sales_order_release_state" as
 WITH l AS (
         SELECT v_authoritative_release_lines.organization_id,
            v_authoritative_release_lines.source_order_no,
            count(*) AS line_count,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released = true)) AS released_lines,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released = false)) AS unreleased_lines,
            count(*) FILTER (WHERE (v_authoritative_release_lines.released IS NULL)) AS unknown_lines,
            sum(v_authoritative_release_lines.production_units) AS production_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released = true)) AS released_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released = false)) AS unreleased_units,
            sum(v_authoritative_release_lines.production_units) FILTER (WHERE (v_authoritative_release_lines.released IS NULL)) AS unknown_units,
            (array_agg(v_authoritative_release_lines.sync_batch_id))[1] AS sync_batch_id
           FROM v_authoritative_release_lines
          GROUP BY v_authoritative_release_lines.organization_id, v_authoritative_release_lines.source_order_no
        )
 SELECT o.organization_id,
    o.order_no AS source_order_no,
    o.customer_name,
    o.ship_to_name,
    o.date_received,
    o.date_due,
    o.date_released,
    o.source_status,
    o.source_sub_status,
    o.source_route_id,
    o.cost_centre,
    o.stop_ship_flag,
    o.source_priority,
    COALESCE(l.sync_batch_id, o.sync_batch_id) AS sync_batch_id,
    COALESCE(l.line_count, (0)::bigint) AS product_lines,
    COALESCE(l.production_units, (0)::numeric) AS production_units,
    COALESCE(l.released_lines, (0)::bigint) AS released_lines,
    COALESCE(l.unreleased_lines, (0)::bigint) AS unreleased_lines,
    COALESCE(l.released_units, (0)::numeric) AS released_units,
    COALESCE(l.unreleased_units, (0)::numeric) AS unreleased_units,
        CASE
            WHEN (COALESCE(l.line_count, (0)::bigint) = 0) THEN 'SOURCE_DATA_INVALID'::text
            WHEN (l.unknown_lines > 0) THEN 'UNKNOWN_RELEASE_STATUS'::text
            WHEN ((l.released_lines > 0) AND (l.unreleased_lines > 0)) THEN 'PARTIALLY_RELEASED'::text
            WHEN (l.released_lines = l.line_count) THEN 'RELEASED'::text
            WHEN (l.unreleased_lines = l.line_count) THEN 'UNRELEASED'::text
            ELSE 'SOURCE_DATA_INVALID'::text
        END AS release_status,
    COALESCE(l.unknown_lines, (0)::bigint) AS unknown_lines,
    COALESCE(l.unknown_units, (0)::numeric) AS unknown_units
   FROM (v_current_orders o
     LEFT JOIN l ON (((l.organization_id = o.organization_id) AND (l.source_order_no = o.order_no))));;
create or replace view public."v_source_operation_evidence" as
 WITH source_values AS (
         SELECT a.organization_id,
            a.order_no,
            'AUDIT'::text AS source_dataset,
            COALESCE(a.source_audit_id, a.raw_hash, (a.id)::text) AS source_record_key,
            a.id AS source_audit_event_id,
            a.event_at AS observed_at,
            a.production_units AS quantity,
            v.source_field,
            v.source_value
           FROM (source_audit_events a
             CROSS JOIN LATERAL ( VALUES ('queue'::text,a.queue), ('task'::text,a.task), ('from_zone'::text,a.from_zone), ('to_zone'::text,a.to_zone), ('from_location'::text,a.from_location), ('to_location'::text,a.to_location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        UNION ALL
         SELECT w.organization_id,
            w.order_no,
            'WORKBANK'::text,
            COALESCE(w.source_row_id, (w.id)::text) AS "coalesce",
            NULL::uuid AS uuid,
            w.created_at,
            w.production_units,
            v.source_field,
            v.source_value
           FROM (v_current_workbank w
             CROSS JOIN LATERAL ( VALUES ('queue'::text,w.queue), ('task'::text,w.task), ('from_zone'::text,w.from_zone), ('from_location'::text,w.from_location), ('to_location'::text,w.to_location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        UNION ALL
         SELECT s.organization_id,
            regexp_replace(s.product, '^#'::text, ''::text) AS regexp_replace,
            'STOCK'::text,
            (s.id)::text AS id,
            NULL::uuid AS uuid,
            COALESCE(s.source_timestamp, s.created_at) AS "coalesce",
            s.production_units,
            v.source_field,
            v.source_value
           FROM (v_current_stock s
             CROSS JOIN LATERAL ( VALUES ('source_zone'::text,s.source_zone), ('location'::text,s.location)) v(source_field, source_value))
          WHERE (NULLIF(TRIM(BOTH FROM v.source_value), ''::text) IS NOT NULL)
        ), ranked AS (
         SELECT sv.organization_id,
            sv.order_no,
            sv.source_dataset,
            sv.source_record_key,
            sv.source_audit_event_id,
            sv.observed_at,
            sv.quantity,
            sv.source_field,
            sv.source_value,
            m.id AS source_mapping_id,
            m.operation_id,
            m.completion_semantics,
            row_number() OVER (PARTITION BY sv.organization_id, sv.source_dataset, sv.source_record_key, sv.source_field ORDER BY m.priority, m.id) AS mapping_rank
           FROM (source_values sv
             JOIN source_operation_mappings m ON (((m.organization_id = sv.organization_id) AND m.active AND (m.source_dataset = sv.source_dataset) AND (m.source_field = sv.source_field) AND source_value_matches(sv.source_value, m.match_type, m.match_value))))
        )
 SELECT organization_id,
    order_no,
    source_dataset,
    source_record_key,
    source_audit_event_id,
    observed_at,
    quantity,
    source_field,
    source_value,
    source_mapping_id,
    operation_id,
    completion_semantics
   FROM ranked
  WHERE (mapping_rank = 1);;
create or replace view public."v_source_task_observations" as
 SELECT w.organization_id,
    'WORKBANK'::text AS source_dataset,
    w.source_row_id AS source_record_key,
    w.order_no,
    w.task AS source_task,
    w.queue,
    w.from_zone,
    NULL::text AS to_zone,
    w.from_location,
    w.to_location,
    w.production_units,
    w.created_at AS observed_at
   FROM v_current_workbank w
  WHERE (NULLIF(TRIM(BOTH FROM w.task), ''::text) IS NOT NULL)
UNION ALL
 SELECT a.organization_id,
    'AUDIT'::text AS source_dataset,
    COALESCE(a.source_audit_id, (a.id)::text) AS source_record_key,
    a.order_no,
    a.task AS source_task,
    a.queue,
    a.from_zone,
    a.to_zone,
    a.from_location,
    a.to_location,
    a.production_units,
    a.event_at AS observed_at
   FROM source_audit_events a
  WHERE (NULLIF(TRIM(BOTH FROM a.task), ''::text) IS NOT NULL);;
create or replace view public."v_source_task_resolution" as
 SELECT s.organization_id,
    s.source_dataset,
    s.source_record_key,
    s.order_no,
    s.source_task,
    s.queue,
    s.from_zone,
    s.to_zone,
    s.from_location,
    s.to_location,
    s.production_units,
    s.observed_at,
    r.mapping_id,
    r.production_process_id,
    r.process_code,
    r.operation_id,
    r.operation_code,
        CASE
            WHEN (r.mapping_id IS NULL) THEN 'TASK_UNMAPPED'::text
            WHEN (r.operation_id IS NULL) THEN 'PROCESS_ONLY'::text
            ELSE 'PROCESS_AND_OPERATION'::text
        END AS resolution_status
   FROM (v_source_task_observations s
     LEFT JOIN LATERAL resolve_source_task_context(s.organization_id, s.source_dataset, s.source_task, s.queue, s.from_zone, s.to_zone, s.from_location, s.to_location) r(mapping_id, production_process_id, process_code, operation_id, operation_code) ON (true));;
create or replace view public."v_up_operational_orders" as
 WITH stock AS (
         SELECT s_1.organization_id,
            regexp_replace(s_1.product, '^#'::text, ''::text) AS order_no,
            count(*) AS box_count,
            sum(s_1.production_units) AS remaining_units,
            min(s_1.source_timestamp) AS last_movement
           FROM v_current_stock s_1
          WHERE (upper(COALESCE(s_1.location, ''::text)) = 'UNDERPRINT'::text)
          GROUP BY s_1.organization_id, (regexp_replace(s_1.product, '^#'::text, ''::text))
        ), putwall AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no,
            string_agg(DISTINCT COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location), ', '::text ORDER BY COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location)) AS putwall_locations
           FROM v_current_workbank
          WHERE (upper(COALESCE(v_current_workbank.from_zone, ''::text)) = 'PWL1'::text)
          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no
        )
 SELECT s.organization_id,
    s.order_no,
    o.customer_name,
    o.delivery_desc AS screen,
    o.source_status AS status,
    o.source_priority AS priority,
    o.date_due,
    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((o.date_released AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,
    s.box_count AS item_count,
    s.remaining_units,
    s.last_movement,
    p.putwall_locations,
    'At UP'::text AS progress_label,
    NULL::numeric AS total_prints,
    NULL::numeric AS adult_prints,
    NULL::numeric AS kids_prints,
    NULL::numeric AS unclassified_prints
   FROM ((stock s
     LEFT JOIN v_current_orders o ON (((o.organization_id = s.organization_id) AND (o.order_no = s.order_no))))
     LEFT JOIN putwall p ON (((p.organization_id = s.organization_id) AND (p.order_no = s.order_no))));;
create or replace view public."v_active_legacy_wip_detail" as
 WITH source_rows AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no AS source_order_no,
                CASE
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'SP11'::text) THEN 'DTG_PICKING'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = 'PCOR'::text) THEN 'DTG_PRINTING'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text) THEN 'DTG_PUTWALL'::text
                    WHEN (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_location, ''::text))) ~~ '%UP'::text) THEN 'UP_PRINTING'::text
                    ELSE NULL::text
                END AS stage_code,
            v_current_workbank.production_units AS units,
            v_current_workbank.source_row_id,
            v_current_workbank.product_code,
            ((NULLIF(v_current_workbank.product_code, ''::text) IS NOT NULL) AND (v_current_workbank.product_code !~ '^#?[0-9]+$'::text)) AS line_source_available
           FROM v_current_workbank
          WHERE ((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = ANY (ARRAY['SP11'::text, 'PCOR'::text])) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_location, ''::text))) ~~ '%UP'::text))
        UNION ALL
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS regexp_replace,
            'UP_PICKING'::text,
            v_current_stock.production_units,
            (v_current_stock.id)::text AS id,
            v_current_stock.product,
            false
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
        UNION ALL
         SELECT source_audit_events.organization_id,
            source_audit_events.order_no,
                CASE upper(TRIM(BOTH FROM source_audit_events.to_location))
                    WHEN 'DTGMOVE'::text THEN 'DTG_DISPATCH'::text
                    ELSE 'UP_DISPATCH'::text
                END AS "case",
            source_audit_events.production_units,
            COALESCE(source_audit_events.source_audit_id, (source_audit_events.id)::text) AS "coalesce",
            source_audit_events.product,
            false
           FROM source_audit_events
          WHERE ((upper(TRIM(BOTH FROM COALESCE(source_audit_events.to_location, ''::text))) = ANY (ARRAY['DTGMOVE'::text, 'UPMOVE'::text])) AND (((source_audit_events.event_at AT TIME ZONE 'Australia/Brisbane'::text))::date = ((now() AT TIME ZONE 'Australia/Brisbane'::text))::date))
        )
 SELECT organization_id,
    source_order_no,
    stage_code,
    count(*) AS product_lines,
    (sum(COALESCE(units, (0)::numeric)))::numeric(14,3) AS units,
    bool_or(line_source_available) AS line_source_available
   FROM source_rows
  WHERE ((NULLIF(TRIM(BOTH FROM source_order_no), ''::text) IS NOT NULL) AND (stage_code IS NOT NULL))
  GROUP BY organization_id, source_order_no, stage_code;;
create or replace view public."v_active_source_product_lines" as
 WITH active AS (
         SELECT v_current_workbank.organization_id,
            v_current_workbank.order_no AS source_order_no,
            'DTG'::text AS process_code,
            (sum(v_current_workbank.production_units))::numeric(14,3) AS active_units
           FROM v_current_workbank
          WHERE ((upper(TRIM(BOTH FROM COALESCE(v_current_workbank.queue, ''::text))) = ANY (ARRAY['SP11'::text, 'PCOR'::text])) OR (upper(TRIM(BOTH FROM COALESCE(v_current_workbank.from_zone, ''::text))) = 'PWL1'::text))
          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no
        UNION ALL
         SELECT v_current_stock.organization_id,
            regexp_replace(v_current_stock.product, '^#'::text, ''::text) AS regexp_replace,
            'UNDERPRINT'::text,
            (sum(v_current_stock.production_units))::numeric(14,3) AS sum
           FROM v_current_stock
          WHERE (upper(TRIM(BOTH FROM COALESCE(v_current_stock.location, ''::text))) = 'UNDERPRINT'::text)
          GROUP BY v_current_stock.organization_id, (regexp_replace(v_current_stock.product, '^#'::text, ''::text))
        UNION ALL
         SELECT screen_print_jobs.organization_id,
            COALESCE(screen_print_jobs.order_no, (screen_print_jobs.id)::text) AS "coalesce",
            'SCREEN_PRINT'::text,
            (sum(GREATEST((screen_print_jobs.planned_quantity - screen_print_jobs.completed_quantity), (0)::numeric)))::numeric(14,3) AS sum
           FROM screen_print_jobs
          WHERE (screen_print_jobs.status <> ALL (ARRAY['completed'::text, 'cancelled'::text]))
          GROUP BY screen_print_jobs.organization_id, COALESCE(screen_print_jobs.order_no, (screen_print_jobs.id)::text)
        ), historical AS (
         SELECT x.organization_id,
            x.source_order_no,
            x.source_line_id,
            x.source_sku,
            x.source_description,
            x.quantity,
            x.rn
           FROM ( SELECT w.organization_id,
                    w.order_no AS source_order_no,
                    w.source_row_id AS source_line_id,
                    w.product_code AS source_sku,
                    w.product_description AS source_description,
                    w.production_units AS quantity,
                    row_number() OVER (PARTITION BY w.organization_id, w.order_no, w.source_row_id ORDER BY w.created_at DESC, w.id DESC) AS rn
                   FROM source_workbank_items w
                  WHERE ((NULLIF(w.source_row_id, ''::text) IS NOT NULL) AND (NULLIF(w.product_code, ''::text) IS NOT NULL) AND (w.product_code !~ '^#?[0-9]+$'::text) AND (w.production_units > (0)::numeric))) x
          WHERE (x.rn = 1)
        ), expanded AS (
         SELECT a.organization_id,
            a.source_order_no,
            a.process_code,
            h.source_line_id,
            h.source_sku,
            h.source_description,
            h.quantity,
            a.active_units
           FROM (active a
             JOIN historical h ON (((h.organization_id = a.organization_id) AND (h.source_order_no = a.source_order_no))))
        UNION ALL
         SELECT a.organization_id,
            a.source_order_no,
            a.process_code,
            ((('MISSING:'::text || a.process_code) || ':'::text) || a.source_order_no),
            NULL::text,
            NULL::text,
            a.active_units,
            a.active_units
           FROM active a
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM historical h
                  WHERE ((h.organization_id = a.organization_id) AND (h.source_order_no = a.source_order_no)))))
        )
 SELECT organization_id,
    source_order_no,
    process_code,
    source_line_id,
    source_sku,
    source_description,
    quantity,
    active_units,
        CASE
            WHEN (source_sku IS NULL) THEN 'SOURCE_LINE_MISSING'::text
            ELSE NULL::text
        END AS source_gap
   FROM expanded;;
create or replace view public."v_active_source_product_task_context" as
 SELECT l.organization_id,
    l.source_order_no,
    l.process_code,
    l.source_line_id,
    l.source_sku,
    l.source_description,
    l.quantity,
    l.active_units,
    l.source_gap,
    t.source_task,
    t.queue,
    t.from_zone,
    t.process_code AS task_process_code,
    t.operation_code AS task_operation_code,
    t.resolution_status AS task_resolution_status,
    resolve_product_process_routing(l.organization_id, pm.product_id, t.process_code, NULL::uuid) AS resolved_routing_id
   FROM ((v_active_source_product_lines l
     LEFT JOIN LATERAL ( SELECT r.organization_id,
            r.source_dataset,
            r.source_record_key,
            r.order_no,
            r.source_task,
            r.queue,
            r.from_zone,
            r.to_zone,
            r.from_location,
            r.to_location,
            r.production_units,
            r.observed_at,
            r.mapping_id,
            r.production_process_id,
            r.process_code,
            r.operation_id,
            r.operation_code,
            r.resolution_status
           FROM v_source_task_resolution r
          WHERE ((r.organization_id = l.organization_id) AND (r.order_no = l.source_order_no) AND (r.source_dataset = 'WORKBANK'::text))
          ORDER BY r.observed_at DESC, r.source_record_key
         LIMIT 1) t ON (true))
     LEFT JOIN product_source_mappings pm ON (((pm.organization_id = l.organization_id) AND (pm.source_system = 'ORACLE_WMS'::text) AND (pm.source_product_code = l.source_sku) AND pm.active)));;
create or replace view public."v_active_wip_mo_coverage" as
 WITH canonical AS (
         SELECT v_manufacturing_order_current_operation.organization_id,
            v_manufacturing_order_current_operation.source_order_no,
                CASE
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'DTG_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DTG_PRINT'::text)) THEN 'DTG_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PUTWALL'::text)) THEN 'DTG_PUTWALL'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'DTG_DISPATCH'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'UP_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'UNDERPRINT'::text)) THEN 'UP_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'UP_DISPATCH'::text
                    ELSE NULL::text
                END AS stage_code,
            count(*) AS mo_count,
            (sum(v_manufacturing_order_current_operation.remaining_quantity))::numeric(14,3) AS units
           FROM v_manufacturing_order_current_operation
          GROUP BY v_manufacturing_order_current_operation.organization_id, v_manufacturing_order_current_operation.source_order_no,
                CASE
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'DTG_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DTG_PRINT'::text)) THEN 'DTG_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PUTWALL'::text)) THEN 'DTG_PUTWALL'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'DTG%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'DTG_DISPATCH'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'PICKING'::text)) THEN 'UP_PICKING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'UNDERPRINT'::text)) THEN 'UP_PRINTING'::text
                    WHEN ((v_manufacturing_order_current_operation.routing_code_snapshot ~~* 'UNDERPRINT%'::text) AND (v_manufacturing_order_current_operation.current_operation_code = 'DISPATCH'::text)) THEN 'UP_DISPATCH'::text
                    ELSE NULL::text
                END
        )
 SELECT l.organization_id,
    l.source_order_no,
    l.stage_code,
    l.product_lines,
    l.units,
    l.line_source_available,
    COALESCE(c.mo_count, (0)::bigint) AS canonical_mos,
    (COALESCE(c.units, (0)::numeric))::numeric(14,3) AS canonical_units,
    ((COALESCE(c.units, (0)::numeric) - l.units))::numeric(14,3) AS unit_difference,
        CASE
            WHEN (COALESCE(c.mo_count, (0)::bigint) > 0) THEN 100.0
            ELSE 0.0
        END AS order_coverage_percent,
    round(((LEAST(COALESCE(c.units, (0)::numeric), l.units) / NULLIF(l.units, (0)::numeric)) * (100)::numeric), 1) AS unit_coverage_percent,
    e.primary_cause,
    e.blocking_cause,
    e.status AS exception_status
   FROM ((v_active_legacy_wip_detail l
     LEFT JOIN canonical c USING (organization_id, source_order_no, stage_code))
     LEFT JOIN active_wip_coverage_exceptions e ON (((e.organization_id = l.organization_id) AND (e.source_system = 'ORACLE_WMS'::text) AND (e.source_order_no = l.source_order_no) AND (e.stage_code = l.stage_code))));;
create or replace view public."v_production_planning" as
 WITH queues AS (
         SELECT v_up_operational_orders.organization_id,
            v_up_operational_orders.order_no,
            'UP'::text AS line,
            v_up_operational_orders.customer_name,
            v_up_operational_orders.screen,
            v_up_operational_orders.status AS source_status,
            v_up_operational_orders.priority AS source_priority,
            v_up_operational_orders.age_days,
            v_up_operational_orders.remaining_units,
            v_up_operational_orders.total_prints
           FROM v_up_operational_orders
        UNION ALL
         SELECT v_dtg_operational_orders.organization_id,
            v_dtg_operational_orders.order_no,
            'DTG'::text,
            v_dtg_operational_orders.customer_name,
            v_dtg_operational_orders.screen,
            v_dtg_operational_orders.status,
            v_dtg_operational_orders.priority,
            v_dtg_operational_orders.age_days,
            v_dtg_operational_orders.remaining_units,
            v_dtg_operational_orders.total_prints
           FROM v_dtg_operational_orders
        )
 SELECT q.organization_id,
    q.order_no,
    q.line,
    q.customer_name,
    q.screen,
    q.source_status,
    q.source_priority,
    q.age_days,
    q.remaining_units,
    q.total_prints,
    p.id AS production_order_id,
    p.planner_priority,
    COALESCE(p.planner_priority, q.source_priority) AS effective_priority,
    p.planned_date,
    p.planned_shift_id,
    s.name AS planned_shift,
    p.planning_status,
    p.special_instruction,
    p.planner_note,
    p.blocked_reason,
    p.updated_at
   FROM ((queues q
     LEFT JOIN production_orders p ON (((p.organization_id = q.organization_id) AND (p.order_no = q.order_no) AND (p.source_routing_id IS NULL))))
     LEFT JOIN shift_templates s ON ((s.id = p.planned_shift_id)));;
create or replace view public."v_release_blockers" as
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'NOT_APPROVED'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.cost_centre, ''::text))) = 'NOTAPPRO'::text)
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'ROUTE_ID_NO'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.source_route_id, ''::text))) = 'NO'::text)
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'STOP_SHIP'::text AS blocker
   FROM v_sales_order_release_state
  WHERE (upper(TRIM(BOTH FROM COALESCE(v_sales_order_release_state.stop_ship_flag, ''::text))) = ANY (ARRAY['Y'::text, 'YES'::text, '1'::text, 'TRUE'::text]))
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    'NO_PRODUCTION_DEMAND'::text AS blocker
   FROM v_sales_order_release_state
  WHERE ((v_sales_order_release_state.product_lines > 0) AND (v_sales_order_release_state.production_units <= (0)::numeric))
UNION ALL
 SELECT v_sales_order_release_state.organization_id,
    v_sales_order_release_state.source_order_no,
    v_sales_order_release_state.release_status AS blocker
   FROM v_sales_order_release_state
  WHERE (v_sales_order_release_state.release_status = ANY (ARRAY['SOURCE_DATA_INVALID'::text, 'UNKNOWN_RELEASE_STATUS'::text]));;
create or replace view public."v_release_queue" as
 SELECT id,
    organization_id,
    sync_batch_id,
    order_no,
    date_received,
    date_due,
    date_released,
    source_status,
    source_sub_status,
    customer_code,
    customer_name,
    ship_to_name,
    customer_state,
    city,
    delivery_desc,
    client_so_number,
    source_priority,
    source_updated_at,
    created_at,
    site,
    route_id,
    cost_centre,
    stop_ship_flag,
    release_source_status,
    snapshot_completed_at,
    dtg_qty,
    underprint_qty,
    uv_qty,
    hats_qty,
    finished_qty,
    stickers_qty,
    visual_qty,
    production_qty,
    custom_emb_qty,
    eyewear_qty,
    total_process_qty,
    release_blockers,
    diagnostic_status,
    release_status
   FROM v_release_queue_all
  WHERE (total_process_qty > (0)::numeric);;
create or replace view public."v_sales_order_release_eligibility" as
 SELECT s.organization_id,
    s.source_order_no,
        CASE
            WHEN bool_or((b.blocker = 'NO_PRODUCTION_DEMAND'::text)) THEN 'NOT_APPLICABLE'::text
            WHEN (count(b.blocker) > 0) THEN 'BLOCKED'::text
            ELSE 'READY'::text
        END AS release_eligibility,
    COALESCE(array_agg(b.blocker ORDER BY b.blocker) FILTER (WHERE (b.blocker IS NOT NULL)), '{}'::text[]) AS release_blockers
   FROM (v_sales_order_release_state s
     LEFT JOIN v_release_blockers b USING (organization_id, source_order_no))
  GROUP BY s.organization_id, s.source_order_no;;
create or replace view public."v_capacity_load" as
 WITH demand AS (
         SELECT v_production_planning.organization_id,
            v_production_planning.line AS area_code,
            sum(v_production_planning.remaining_units) AS demand_units
           FROM v_production_planning
          WHERE (COALESCE(v_production_planning.planning_status, 'unplanned'::text) <> ALL (ARRAY['completed'::text, 'cancelled'::text]))
          GROUP BY v_production_planning.organization_id, v_production_planning.line
        ), profile_capacity AS (
         SELECT p.organization_id,
            a.code AS area_code,
            sum((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency)) AS daily_capacity,
            sum(((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency) * p.work_days)) AS weekly_capacity
           FROM (capacity_profiles p
             JOIN production_areas a ON ((a.id = p.production_area_id)))
          WHERE p.active
          GROUP BY p.organization_id, a.code
        ), legacy_capacity AS (
         SELECT o.organization_id,
            a.code AS area_code,
            sum(o.daily_capacity) AS daily_capacity,
            sum((o.daily_capacity * o.work_days)) AS weekly_capacity
           FROM (capacity_legacy_overrides o
             JOIN production_areas a ON ((a.id = o.production_area_id)))
          WHERE o.active
          GROUP BY o.organization_id, a.code
        ), capacity AS (
         SELECT profile_capacity.organization_id,
            profile_capacity.area_code,
            profile_capacity.daily_capacity,
            profile_capacity.weekly_capacity
           FROM profile_capacity
        UNION ALL
         SELECT l.organization_id,
            l.area_code,
            l.daily_capacity,
            l.weekly_capacity
           FROM legacy_capacity l
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM profile_capacity p
                  WHERE ((p.organization_id = l.organization_id) AND (p.area_code = l.area_code)))))
        )
 SELECT c.organization_id,
    c.area_code,
    COALESCE(d.demand_units, (0)::numeric) AS demand_units,
    c.daily_capacity,
    c.weekly_capacity,
        CASE
            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric
            ELSE round(((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity) * (100)::numeric), 2)
        END AS load_percent,
    (c.daily_capacity - COALESCE(d.demand_units, (0)::numeric)) AS capacity_gap,
        CASE
            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric
            ELSE round((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity), 2)
        END AS relative_lead_days
   FROM (capacity c
     LEFT JOIN demand d USING (organization_id, area_code));;
create or replace view public."v_machine_load_not_approved" as
 WITH order_process AS (
         SELECT l_1.organization_id,
            l_1.sync_batch_id,
            l_1.order_no,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))) AS has_dtg,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = 'UNDERPRINT'::text)) AS has_underprint,
            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) <> ALL (ARRAY['DTG_1'::text, 'DTG_2'::text, 'UNDERPRINT'::text]))) AS has_other
           FROM (v_current_release_order_lines l_1
             JOIN v_release_queue q_1 ON (((q_1.organization_id = l_1.organization_id) AND (q_1.sync_batch_id = l_1.sync_batch_id) AND (q_1.order_no = l_1.order_no) AND (q_1.release_status = 'NOT_APPROVED'::text))))
          WHERE (l_1.qty_lcd > (0)::numeric)
          GROUP BY l_1.organization_id, l_1.sync_batch_id, l_1.order_no
        )
 SELECT l.organization_id,
    l.sync_batch_id,
    l.order_no,
    l.line_number,
    l.product,
    l.client,
    l.product_name,
    l.group_code AS source_process_code,
    l.qty_lcd AS process_quantity,
    'PROCESS_QUANTITY'::text AS quantity_semantics,
    q.customer_name,
    q.date_due,
    q.source_priority,
    q.site,
    q.route_id AS release_route_evidence,
    NULL::uuid AS routing_id,
    NULL::text AS routing_code,
    NULL::integer AS routing_revision,
    NULL::text AS machine_group,
        CASE
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UV PRINT'::text) THEN 'UV'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'HATS'::text) THEN 'HATS'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'FINISHED'::text) THEN 'FINISHED'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'STICKERS'::text) THEN 'STICKERS'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'VISUAL'::text) THEN 'VISUAL'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'PROD'::text) THEN 'PRODUCTION'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'CUSTOM EMB'::text) THEN 'CUSTOM EMB'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'EYEWEAR'::text) THEN 'EYEWEAR'::text
            ELSE 'UNRESOLVED'::text
        END AS process,
        CASE
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text
            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text
            ELSE NULL::text
        END AS machine_load_bucket,
        CASE
            WHEN ((((op.has_dtg)::integer + (op.has_underprint)::integer) = 1) AND (NOT op.has_other)) THEN 'RESOLVED'::text
            WHEN ((op.has_dtg OR op.has_underprint) AND (op.has_other OR (op.has_dtg AND op.has_underprint))) THEN 'AMBIGUOUS'::text
            ELSE 'UNRESOLVED'::text
        END AS routing_resolution,
    'NOT_APPROVED'::text AS release_status,
    q.release_blockers,
    q.snapshot_completed_at
   FROM ((v_current_release_order_lines l
     JOIN v_release_queue q ON (((q.organization_id = l.organization_id) AND (q.sync_batch_id = l.sync_batch_id) AND (q.order_no = l.order_no) AND (q.release_status = 'NOT_APPROVED'::text))))
     JOIN order_process op ON (((op.organization_id = l.organization_id) AND (op.sync_batch_id = l.sync_batch_id) AND (op.order_no = l.order_no))))
  WHERE (l.qty_lcd > (0)::numeric);;
create or replace view public."v_released_production_demand" as
 SELECT (md5((((((l.organization_id)::text || '|'::text) || l.source_order_no) || '|'::text) || l.source_line_id)))::uuid AS id,
    l.organization_id,
    l.sync_batch_id,
    l.source_system,
    l.source_order_no,
    l.source_line_id,
    l.source_product_code,
    l.source_description,
    l.production_units,
    l.released,
    NULL::timestamp with time zone AS date_released,
    l.raw_release_value,
    l.source_updated_at AS created_at,
    l.source_line_status,
    l.quantity_processed,
    l.source_weight,
    l.stock_reserved_flag,
    l.source_updated_at,
    'SOURCE_CONFIRMED'::text AS release_provenance
   FROM (v_authoritative_release_lines l
     JOIN v_sales_order_release_eligibility e USING (organization_id, source_order_no))
  WHERE ((l.released = true) AND (l.raw_release_value = 'Y'::text) AND (e.release_eligibility <> 'NOT_APPLICABLE'::text));;
create or replace view public."v_released_demand_resolution" as
 WITH process_context AS (
         SELECT v_source_task_resolution.organization_id,
            v_source_task_resolution.order_no,
            count(DISTINCT v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_count,
            min(v_source_task_resolution.process_code) FILTER (WHERE (v_source_task_resolution.process_code IS NOT NULL)) AS process_code,
            string_agg(DISTINCT v_source_task_resolution.source_task, ', '::text ORDER BY v_source_task_resolution.source_task) AS source_tasks
           FROM v_source_task_resolution
          WHERE (v_source_task_resolution.source_dataset = 'WORKBANK'::text)
          GROUP BY v_source_task_resolution.organization_id, v_source_task_resolution.order_no
        ), product_context AS (
         SELECT product_source_mappings.organization_id,
            product_source_mappings.source_product_code,
            count(DISTINCT product_source_mappings.product_id) AS product_count,
            (min((product_source_mappings.product_id)::text))::uuid AS product_id
           FROM product_source_mappings
          WHERE ((product_source_mappings.source_system = 'ORACLE_WMS'::text) AND product_source_mappings.active)
          GROUP BY product_source_mappings.organization_id, product_source_mappings.source_product_code
        )
 SELECT l.organization_id,
    l.source_order_no,
    l.source_line_id,
    l.production_units AS source_quantity,
    l.released,
    l.raw_release_value,
    o.source_route_id,
    pc.product_id,
    pctx.process_code AS resolved_process,
        CASE
            WHEN (pctx.process_count = 1) THEN 'UNIQUE_WORKBANK_TASK_PROCESS'::text
            ELSE NULL::text
        END AS process_resolution_rule,
        CASE
            WHEN (pctx.process_count = 1) THEN 'SOURCE_CONFIRMED'::text
            ELSE 'NOT_RESOLVED'::text
        END AS process_provenance,
        CASE
            WHEN ((pc.product_count = 1) AND (pctx.process_count = 1)) THEN resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid)
            ELSE NULL::uuid
        END AS resolved_routing_id,
    e.release_eligibility,
    l.sync_batch_id,
    a.ingestion_run_id,
        CASE
            WHEN ((l.released IS DISTINCT FROM true) OR (l.raw_release_value <> 'Y'::text)) THEN 'RELEASE_NOT_CONFIRMED'::text
            WHEN (e.release_eligibility <> 'READY'::text) THEN 'ELIGIBILITY_BLOCKED'::text
            WHEN (COALESCE(pc.product_count, (0)::bigint) <> 1) THEN 'PRODUCT_UNRESOLVED'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) <> 1) THEN 'PROCESS_UNRESOLVED'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'ROUTING_UNRESOLVED'::text
            ELSE 'ELIGIBLE'::text
        END AS eligibility_status,
        CASE
            WHEN (COALESCE(pc.product_count, (0)::bigint) = 0) THEN 'No active canonical Product mapping'::text
            WHEN (pc.product_count > 1) THEN 'Multiple active canonical Product mappings'::text
            WHEN (COALESCE(pctx.process_count, (0)::bigint) = 0) THEN 'No mapped source Task process observed'::text
            WHEN (pctx.process_count > 1) THEN 'Multiple source Task processes observed for Sales Order'::text
            WHEN (resolve_product_process_routing(l.organization_id, pc.product_id, pctx.process_code, NULL::uuid) IS NULL) THEN 'No approved Product + Process Routing'::text
            ELSE NULL::text
        END AS blocker,
    pctx.source_tasks
   FROM (((((v_released_production_demand l
     JOIN v_authoritative_release_lines a ON (((a.organization_id = l.organization_id) AND (a.source_order_no = l.source_order_no) AND (a.source_line_id = l.source_line_id))))
     JOIN v_sales_order_release_eligibility e ON (((e.organization_id = l.organization_id) AND (e.source_order_no = l.source_order_no))))
     LEFT JOIN v_current_orders o ON (((o.organization_id = l.organization_id) AND (o.order_no = l.source_order_no))))
     LEFT JOIN product_context pc ON (((pc.organization_id = l.organization_id) AND (pc.source_product_code = l.source_product_code))))
     LEFT JOIN process_context pctx ON (((pctx.organization_id = l.organization_id) AND (pctx.order_no = l.source_order_no))));;
CREATE TRIGGER kpi_result_target_status BEFORE INSERT ON kpi_results FOR EACH ROW EXECUTE FUNCTION apply_kpi_target_status();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_assets FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_downtime_events FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_inventory_transactions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_preventive_plans FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_work_order_labor FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_work_orders FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER enforce_manufacturing_order_line_boundary_change BEFORE INSERT OR UPDATE ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION enforce_manufacturing_order_line_boundary();
CREATE TRIGGER manufacturing_order_lines_audit AFTER INSERT OR DELETE OR UPDATE ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER recalculate_manufacturing_order_actual_change AFTER UPDATE OF actual_quantity ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION recalculate_manufacturing_order_actual();
CREATE TRIGGER recalculate_manufacturing_order_quantity_change AFTER INSERT OR DELETE OR UPDATE OF planned_quantity ON manufacturing_order_lines FOR EACH ROW EXECUTE FUNCTION recalculate_manufacturing_order_quantity();
CREATE TRIGGER protect_active_operation_deactivation_change BEFORE UPDATE OF active ON operations FOR EACH ROW EXECUTE FUNCTION protect_active_operation_deactivation();
CREATE TRIGGER production_demand_exceptions_audit AFTER INSERT OR DELETE OR UPDATE ON production_demand_exceptions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER production_demand_lines_audit AFTER INSERT OR DELETE OR UPDATE ON production_demand_lines FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER production_event_units_trigger BEFORE INSERT OR UPDATE OF quantity, metric ON production_events FOR EACH ROW EXECUTE FUNCTION normalize_production_event_units();
CREATE TRIGGER production_order_operations_audit AFTER INSERT OR DELETE OR UPDATE ON production_order_operations FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER protect_production_operation_snapshot_change BEFORE DELETE OR UPDATE ON production_order_operations FOR EACH ROW EXECUTE FUNCTION protect_production_operation_snapshot();
CREATE TRIGGER copy_production_order_operations_change AFTER INSERT OR UPDATE OF product_id, source_routing_id ON production_orders FOR EACH ROW EXECUTE FUNCTION copy_production_order_operations();
CREATE TRIGGER prepare_production_order_snapshot_change BEFORE INSERT OR UPDATE OF product_id, source_routing_id ON production_orders FOR EACH ROW EXECUTE FUNCTION prepare_production_order_snapshot();
CREATE TRIGGER production_orders_execution_audit AFTER INSERT OR DELETE OR UPDATE ON production_orders FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER production_resource_asset_organization BEFORE INSERT OR UPDATE OF asset_id, organization_id ON production_resources FOR EACH ROW EXECUTE FUNCTION enforce_production_resource_asset_organization();
CREATE TRIGGER production_routing_exceptions_audit AFTER INSERT OR DELETE OR UPDATE ON production_routing_exceptions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER product_routing_assignment_audit_change AFTER UPDATE OF default_routing_id ON products FOR EACH ROW WHEN (old.default_routing_id IS DISTINCT FROM new.default_routing_id) EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER validate_product_default_routing_change BEFORE INSERT OR UPDATE OF default_routing_id, organization_id ON products FOR EACH ROW EXECUTE FUNCTION validate_product_default_routing();
CREATE TRIGGER protect_routing_operation_change BEFORE INSERT OR DELETE OR UPDATE ON routing_operations FOR EACH ROW EXECUTE FUNCTION protect_routing_operation_change();
CREATE TRIGGER routing_operations_audit_change AFTER INSERT OR DELETE OR UPDATE ON routing_operations FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER protect_routing_revision_change BEFORE DELETE OR UPDATE ON routings FOR EACH ROW EXECUTE FUNCTION protect_routing_revision();
CREATE TRIGGER routing_master_audit_change AFTER INSERT OR DELETE OR UPDATE ON routings FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER source_operation_mappings_audit AFTER INSERT OR DELETE OR UPDATE ON source_operation_mappings FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change();
CREATE TRIGGER source_orders_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_orders FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization();
CREATE TRIGGER source_stock_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_stock_items FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization();
CREATE TRIGGER source_workbank_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_workbank_items FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization();
alter table public."active_wip_backfill_runs" enable row level security;
alter table public."active_wip_coverage_exceptions" enable row level security;
alter table public."capacity_legacy_overrides" enable row level security;
alter table public."capacity_profiles" enable row level security;
alter table public."capacity_scenario_lines" enable row level security;
alter table public."capacity_scenarios" enable row level security;
alter table public."deputy_import_batches" enable row level security;
alter table public."deputy_raw_timesheets" enable row level security;
alter table public."kpi_definitions" enable row level security;
alter table public."kpi_rate_rules" enable row level security;
alter table public."kpi_results" enable row level security;
alter table public."kpi_targets" enable row level security;
alter table public."labour_segments" enable row level security;
alter table public."maintenance_asset_categories" enable row level security;
alter table public."maintenance_asset_code_sequences" enable row level security;
alter table public."maintenance_asset_installations" enable row level security;
alter table public."maintenance_asset_prefixes" enable row level security;
alter table public."maintenance_assets" enable row level security;
alter table public."maintenance_attachments" enable row level security;
alter table public."maintenance_audit_log" enable row level security;
alter table public."maintenance_component_code_sequences" enable row level security;
alter table public."maintenance_component_prefixes" enable row level security;
alter table public."maintenance_downtime_events" enable row level security;
alter table public."maintenance_import_batches" enable row level security;
alter table public."maintenance_import_staging" enable row level security;
alter table public."maintenance_inventory_locations" enable row level security;
alter table public."maintenance_inventory_transactions" enable row level security;
alter table public."maintenance_members" enable row level security;
alter table public."maintenance_parts" enable row level security;
alter table public."maintenance_preventive_plan_tasks" enable row level security;
alter table public."maintenance_preventive_plans" enable row level security;
alter table public."maintenance_work_order_checklist" enable row level security;
alter table public."maintenance_work_order_comments" enable row level security;
alter table public."maintenance_work_order_history" enable row level security;
alter table public."maintenance_work_order_labor" enable row level security;
alter table public."maintenance_work_orders" enable row level security;
alter table public."manufacturing_order_lines" enable row level security;
alter table public."operations" enable row level security;
alter table public."oracle_line_ingestion_runs" enable row level security;
alter table public."oracle_line_ingestion_staging" enable row level security;
alter table public."organizations" enable row level security;
alter table public."product_families" enable row level security;
alter table public."product_mapping_resolution_audit" enable row level security;
alter table public."product_routing_assignments" enable row level security;
alter table public."product_source_mappings" enable row level security;
alter table public."product_types" enable row level security;
alter table public."production_areas" enable row level security;
alter table public."production_demand_exceptions" enable row level security;
alter table public."production_demand_lines" enable row level security;
alter table public."production_demand_release_events" enable row level security;
alter table public."production_events" enable row level security;
alter table public."production_order_history" enable row level security;
alter table public."production_order_operation_evidence" enable row level security;
alter table public."production_order_operations" enable row level security;
alter table public."production_orders" enable row level security;
alter table public."production_plan_history" enable row level security;
alter table public."production_plan_items" enable row level security;
alter table public."production_plans" enable row level security;
alter table public."production_process_stages" enable row level security;
alter table public."production_processes" enable row level security;
alter table public."production_reconciliation_items" enable row level security;
alter table public."production_reconciliation_runs" enable row level security;
alter table public."production_resources" enable row level security;
alter table public."production_routing_exceptions" enable row level security;
alter table public."production_stage_mappings" enable row level security;
alter table public."production_stage_source_rules" enable row level security;
alter table public."products" enable row level security;
alter table public."quantity_conversion_rules" enable row level security;
alter table public."resource_capacity_rules" enable row level security;
alter table public."routing_operations" enable row level security;
alter table public."routings" enable row level security;
alter table public."sales_order_release_history" enable row level security;
alter table public."screen_print_jobs" enable row level security;
alter table public."shift_rules" enable row level security;
alter table public."shift_templates" enable row level security;
alter table public."source_audit_events" enable row level security;
alter table public."source_operation_mappings" enable row level security;
alter table public."source_operational_code_mappings" enable row level security;
alter table public."source_order_release_lines" enable row level security;
alter table public."source_orders" enable row level security;
alter table public."source_release_order_lines" enable row level security;
alter table public."source_stock_items" enable row level security;
alter table public."source_task_mappings" enable row level security;
alter table public."source_workbank_items" enable row level security;
alter table public."staffing_layout_lines" enable row level security;
alter table public."staffing_layouts" enable row level security;
alter table public."sync_agent_heartbeat" enable row level security;
alter table public."sync_batches" enable row level security;
alter table public."sync_refresh_requests" enable row level security;
alter table public."sync_runs" enable row level security;
alter table public."work_centers" enable row level security;
create policy "active_wip_backfill_runs_read" on public."active_wip_backfill_runs" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_backfill_runs.organization_id) AND m.active))));
create policy "active_wip_coverage_exceptions_read" on public."active_wip_coverage_exceptions" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_coverage_exceptions.organization_id) AND m.active))));
create policy "maintenance_members_self_read" on public."maintenance_members" as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));
create policy "manufacturing_order_lines_manage" on public."manufacturing_order_lines" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "manufacturing_order_lines_read" on public."manufacturing_order_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active))));
create policy "operations_manage" on public."operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "operations_read" on public."operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active))));
create policy "oracle_line_runs_read" on public."oracle_line_ingestion_runs" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = oracle_line_ingestion_runs.organization_id) AND m.active))));
create policy "product_families_manage" on public."product_families" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_families_read" on public."product_families" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active))));
create policy "product_mapping_resolution_audit_read" on public."product_mapping_resolution_audit" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_mapping_resolution_audit.organization_id) AND m.active))));
create policy "product_routing_assignments_manage" on public."product_routing_assignments" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_routing_assignments_read" on public."product_routing_assignments" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active))));
create policy "product_source_mappings_manage" on public."product_source_mappings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_source_mappings_read" on public."product_source_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active))));
create policy "product_types_manage" on public."product_types" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "product_types_read" on public."product_types" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active))));
create policy "production_demand_exceptions_manage" on public."production_demand_exceptions" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_demand_exceptions_read" on public."production_demand_exceptions" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active))));
create policy "production_demand_lines_manage" on public."production_demand_lines" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_demand_lines_read" on public."production_demand_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active))));
create policy "production_demand_release_events_read" on public."production_demand_release_events" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_release_events.organization_id) AND m.active))));
create policy "production_order_operation_evidence_read" on public."production_order_operation_evidence" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operation_evidence.organization_id) AND m.active))));
create policy "production_order_operations_execute" on public."production_order_operations" as PERMISSIVE for UPDATE to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text)))));
create policy "production_order_operations_manage" on public."production_order_operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_order_operations_read" on public."production_order_operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active))));
create policy "production_orders_execution_manage" on public."production_orders" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_orders_execution_read" on public."production_orders" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active))));
create policy "production_reconciliation_items_read" on public."production_reconciliation_items" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_reconciliation_items.organization_id) AND m.active))));
create policy "production_reconciliation_runs_read" on public."production_reconciliation_runs" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_reconciliation_runs.organization_id) AND m.active))));
create policy "production_resources_manage" on public."production_resources" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_resources_read" on public."production_resources" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active))));
create policy "production_routing_exceptions_manage" on public."production_routing_exceptions" as PERMISSIVE for UPDATE to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "production_routing_exceptions_read" on public."production_routing_exceptions" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active))));
create policy "products_manage" on public."products" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "products_read" on public."products" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active))));
create policy "routing_operations_manage" on public."routing_operations" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "routing_operations_read" on public."routing_operations" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active))));
create policy "routings_manage" on public."routings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "routings_read" on public."routings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active))));
create policy "sales_order_release_history_read" on public."sales_order_release_history" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = sales_order_release_history.organization_id) AND m.active))));
create policy "source_operation_mappings_manage" on public."source_operation_mappings" as PERMISSIVE for ALL to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "source_operation_mappings_read" on public."source_operation_mappings" as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active))));
create policy "source_operational_codes_read" on public."source_operational_code_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.organization_id = source_operational_code_mappings.organization_id) AND (m.user_id = auth.uid()) AND m.active))));
create policy "source_order_release_lines_read" on public."source_order_release_lines" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_order_release_lines.organization_id) AND m.active))));
create policy "source_task_mappings_manage" on public."source_task_mappings" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "source_task_mappings_read" on public."source_task_mappings" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active))));
create policy "work_centers_manage" on public."work_centers" as PERMISSIVE for ALL to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))) with check ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))));
create policy "work_centers_read" on public."work_centers" as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active))));
insert into storage.buckets(id,name,public) values('maintenance-private','maintenance-private',false) on conflict(id) do update set public=false;
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated, service_role;
grant select on all tables in schema public to authenticated;
grant insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant execute on all functions in schema public to authenticated, service_role;
grant usage, select on all sequences in schema public to service_role;
comment on schema public is 'TSD Canonical V2. Oracle is read-only; this schema contains canonical configuration and derived execution state.';
commit;

