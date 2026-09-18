-- PROD schema metadata snapshot
-- Project ref: gdajktoqmajipivpdude
-- Read-only catalog export; no data rows included.

-- BASE TABLE: public.capacity_legacy_overrides
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. production_area_id uuid nullable=NO default=
--   4. source_name text nullable=NO default=
--   5. daily_capacity numeric nullable=NO default=
--   6. work_days numeric nullable=NO default=5
--   7. temporary boolean nullable=NO default=true
--   8. active boolean nullable=NO default=true
--   9. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT capacity_legacy_overrides_daily_capacity_check: CHECK (daily_capacity >= 0::numeric)
--   CONSTRAINT capacity_legacy_overrides_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT capacity_legacy_overrides_organization_id_production_area_i_key: UNIQUE (organization_id, production_area_id, source_name)
--   CONSTRAINT capacity_legacy_overrides_pkey: PRIMARY KEY (id)
--   CONSTRAINT capacity_legacy_overrides_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT capacity_legacy_overrides_work_days_check: CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
CREATE UNIQUE INDEX capacity_legacy_overrides_organization_id_production_area_i_key ON public.capacity_legacy_overrides USING btree (organization_id, production_area_id, source_name);
CREATE UNIQUE INDEX capacity_legacy_overrides_pkey ON public.capacity_legacy_overrides USING btree (id);

-- BASE TABLE: public.capacity_profiles
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. production_area_id uuid nullable=NO default=
--   5. shift_template_id uuid nullable=NO default=
--   6. resource_count numeric nullable=NO default=
--   7. machine_count numeric nullable=YES default=
--   8. scheduled_hours numeric nullable=NO default=
--   9. hourly_rate numeric nullable=NO default=
--   10. efficiency numeric nullable=NO default=
--   11. work_days numeric nullable=NO default=5
--   12. active boolean nullable=NO default=true
--   13. created_at timestamp with time zone nullable=NO default=now()
--   14. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT capacity_profiles_efficiency_check: CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)
--   CONSTRAINT capacity_profiles_hourly_rate_check: CHECK (hourly_rate >= 0::numeric)
--   CONSTRAINT capacity_profiles_machine_count_check: CHECK (machine_count >= 0::numeric)
--   CONSTRAINT capacity_profiles_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT capacity_profiles_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT capacity_profiles_pkey: PRIMARY KEY (id)
--   CONSTRAINT capacity_profiles_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT capacity_profiles_resource_count_check: CHECK (resource_count >= 0::numeric)
--   CONSTRAINT capacity_profiles_scheduled_hours_check: CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)
--   CONSTRAINT capacity_profiles_shift_template_id_fkey: FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)
--   CONSTRAINT capacity_profiles_work_days_check: CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
CREATE INDEX capacity_profiles_context_idx ON public.capacity_profiles USING btree (organization_id, production_area_id, shift_template_id) WHERE active;
CREATE UNIQUE INDEX capacity_profiles_organization_id_name_key ON public.capacity_profiles USING btree (organization_id, name);
CREATE UNIQUE INDEX capacity_profiles_pkey ON public.capacity_profiles USING btree (id);

-- BASE TABLE: public.capacity_scenario_lines
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. capacity_scenario_id uuid nullable=NO default=
--   3. production_area_id uuid nullable=NO default=
--   4. shift_template_id uuid nullable=NO default=
--   5. resource_count numeric nullable=NO default=
--   6. machine_count numeric nullable=YES default=
--   7. scheduled_hours numeric nullable=NO default=
--   8. hourly_rate numeric nullable=NO default=
--   9. efficiency numeric nullable=NO default=
--   10. work_days numeric nullable=NO default=5
--   11. calculated_capacity numeric nullable=YES default=
--   CONSTRAINT capacity_scenario_lines_capacity_scenario_id_fkey: FOREIGN KEY (capacity_scenario_id) REFERENCES capacity_scenarios(id) ON DELETE CASCADE
--   CONSTRAINT capacity_scenario_lines_efficiency_check: CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)
--   CONSTRAINT capacity_scenario_lines_hourly_rate_check: CHECK (hourly_rate >= 0::numeric)
--   CONSTRAINT capacity_scenario_lines_machine_count_check: CHECK (machine_count >= 0::numeric)
--   CONSTRAINT capacity_scenario_lines_pkey: PRIMARY KEY (id)
--   CONSTRAINT capacity_scenario_lines_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT capacity_scenario_lines_resource_count_check: CHECK (resource_count >= 0::numeric)
--   CONSTRAINT capacity_scenario_lines_scheduled_hours_check: CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)
--   CONSTRAINT capacity_scenario_lines_shift_template_id_fkey: FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)
--   CONSTRAINT capacity_scenario_lines_work_days_check: CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)
CREATE UNIQUE INDEX capacity_scenario_lines_pkey ON public.capacity_scenario_lines USING btree (id);
CREATE INDEX capacity_scenario_lines_scenario_idx ON public.capacity_scenario_lines USING btree (capacity_scenario_id);

-- BASE TABLE: public.capacity_scenarios
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. notes text nullable=YES default=
--   5. created_by uuid nullable=YES default=
--   6. created_by_email text nullable=YES default=
--   7. created_at timestamp with time zone nullable=NO default=now()
--   8. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT capacity_scenarios_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT capacity_scenarios_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT capacity_scenarios_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX capacity_scenarios_organization_id_name_key ON public.capacity_scenarios USING btree (organization_id, name);
CREATE UNIQUE INDEX capacity_scenarios_pkey ON public.capacity_scenarios USING btree (id);

-- BASE TABLE: public.deputy_area_mappings
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. raw_area text nullable=NO default=
--   4. normalized_area text nullable=NO default=
--   5. active boolean nullable=NO default=true
--   CONSTRAINT deputy_area_mappings_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT deputy_area_mappings_organization_id_raw_area_key: UNIQUE (organization_id, raw_area)
--   CONSTRAINT deputy_area_mappings_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX deputy_area_mappings_organization_id_raw_area_key ON public.deputy_area_mappings USING btree (organization_id, raw_area);
CREATE UNIQUE INDEX deputy_area_mappings_pkey ON public.deputy_area_mappings USING btree (id);

-- BASE TABLE: public.deputy_import_batches
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. filename text nullable=NO default=
--   4. source_type text nullable=NO default=
--   5. source_timezone text nullable=NO default=
--   6. target_timezone text nullable=NO default='Australia/Brisbane'::text
--   7. content_hash text nullable=NO default=
--   8. imported_at timestamp with time zone nullable=NO default=now()
--   9. covered_from date nullable=YES default=
--   10. covered_to date nullable=YES default=
--   11. raw_rows integer nullable=NO default=0
--   12. approved_rows integer nullable=NO default=0
--   13. provisional_rows integer nullable=NO default=0
--   14. quarantined_rows integer nullable=NO default=0
--   15. status text nullable=NO default=
--   16. imported_by uuid nullable=YES default=
--   17. imported_by_email text nullable=YES default=
--   18. error_message text nullable=YES default=
--   19. segmented_rows integer nullable=NO default=0
--   CONSTRAINT deputy_import_batches_organization_id_content_hash_key: UNIQUE (organization_id, content_hash)
--   CONSTRAINT deputy_import_batches_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT deputy_import_batches_pkey: PRIMARY KEY (id)
--   CONSTRAINT deputy_import_batches_source_type_check: CHECK (source_type = ANY (ARRAY['CSV'::text, 'XLSX'::text]))
--   CONSTRAINT deputy_import_batches_status_check: CHECK (status = ANY (ARRAY['PROCESSING'::text, 'COMPLETED'::text, 'FAILED'::text]))
CREATE INDEX deputy_batch_date_idx ON public.deputy_import_batches USING btree (organization_id, imported_at DESC);
CREATE UNIQUE INDEX deputy_import_batches_organization_id_content_hash_key ON public.deputy_import_batches USING btree (organization_id, content_hash);
CREATE UNIQUE INDEX deputy_import_batches_pkey ON public.deputy_import_batches USING btree (id);

-- BASE TABLE: public.deputy_raw_timesheets
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. import_batch_id uuid nullable=NO default=
--   4. source_row_key text nullable=NO default=
--   5. source_timesheet_id text nullable=YES default=
--   6. employee_id text nullable=YES default=
--   7. person_key text nullable=YES default=
--   8. display_name text nullable=YES default=
--   9. timesheet_date date nullable=YES default=
--   10. raw_area text nullable=YES default=
--   11. normalized_area text nullable=YES default=
--   12. start_at timestamp with time zone nullable=YES default=
--   13. end_at timestamp with time zone nullable=YES default=
--   14. total_hours numeric nullable=YES default=
--   15. meal_break_hours numeric nullable=YES default=
--   16. approval_status text nullable=NO default=
--   17. row_status text nullable=NO default=
--   18. quarantine_reasons ARRAY nullable=NO default='{}'::text[]
--   19. raw_data jsonb nullable=NO default=
--   20. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT deputy_raw_timesheets_approval_status_check: CHECK (approval_status = ANY (ARRAY['APPROVED'::text, 'PROVISIONAL'::text, 'INCOMPLETE'::text]))
--   CONSTRAINT deputy_raw_timesheets_import_batch_id_fkey: FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id)
--   CONSTRAINT deputy_raw_timesheets_import_batch_id_source_row_key_key: UNIQUE (import_batch_id, source_row_key)
--   CONSTRAINT deputy_raw_timesheets_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT deputy_raw_timesheets_pkey: PRIMARY KEY (id)
--   CONSTRAINT deputy_raw_timesheets_row_status_check: CHECK (row_status = ANY (ARRAY['ACCEPTED'::text, 'QUARANTINED'::text]))
CREATE INDEX deputy_period_idx ON public.deputy_raw_timesheets USING btree (organization_id, timesheet_date, normalized_area);
CREATE INDEX deputy_quarantine_idx ON public.deputy_raw_timesheets USING btree (organization_id, row_status) WHERE (row_status = 'QUARANTINED'::text);
CREATE UNIQUE INDEX deputy_raw_timesheets_import_batch_id_source_row_key_key ON public.deputy_raw_timesheets USING btree (import_batch_id, source_row_key);
CREATE UNIQUE INDEX deputy_raw_timesheets_pkey ON public.deputy_raw_timesheets USING btree (id);

-- BASE TABLE: public.kpi_definitions
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. code text nullable=NO default=
--   4. name text nullable=NO default=
--   5. category text nullable=NO default='OPERATIONS'::text
--   6. unit text nullable=NO default='UNITS'::text
--   7. direction text nullable=NO default='LOWER_IS_BETTER'::text
--   8. frequency text nullable=NO default='REALTIME'::text
--   9. data_source text nullable=YES default=
--   10. data_readiness_status text nullable=NO default=
--   11. is_active boolean nullable=NO default=false
--   12. dashboard_priority integer nullable=YES default=
--   13. owner_role text nullable=NO default='manager'::text
--   14. supports_area_dimension boolean nullable=NO default=false
--   15. created_at timestamp with time zone nullable=NO default=now()
--   16. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT kpi_definitions_data_readiness_status_check: CHECK (data_readiness_status = ANY (ARRAY['ACTIVE'::text, 'WAITING_FOR_DATA'::text, 'DISABLED'::text]))
--   CONSTRAINT kpi_definitions_direction_check: CHECK (direction = ANY (ARRAY['HIGHER_IS_BETTER'::text, 'LOWER_IS_BETTER'::text, 'TARGET_RANGE'::text]))
--   CONSTRAINT kpi_definitions_organization_id_code_key: UNIQUE (organization_id, code)
--   CONSTRAINT kpi_definitions_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT kpi_definitions_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX kpi_definitions_organization_id_code_key ON public.kpi_definitions USING btree (organization_id, code);
CREATE UNIQUE INDEX kpi_definitions_pkey ON public.kpi_definitions USING btree (id);

-- BASE TABLE: public.kpi_rate_rules
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. process text nullable=NO default=
--   4. rate_per_hour numeric nullable=NO default=
--   5. unit text nullable=NO default=
--   6. capacity_mode text nullable=NO default=
--   7. calculation_version text nullable=NO default=
--   8. effective_from date nullable=NO default=
--   9. effective_to date nullable=YES default=
--   10. active boolean nullable=NO default=true
--   CONSTRAINT kpi_rate_rules_check: CHECK (effective_to IS NULL OR effective_to >= effective_from)
--   CONSTRAINT kpi_rate_rules_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT kpi_rate_rules_organization_id_process_effective_from_key: UNIQUE (organization_id, process, effective_from)
--   CONSTRAINT kpi_rate_rules_pkey: PRIMARY KEY (id)
--   CONSTRAINT kpi_rate_rules_process_check: CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text]))
--   CONSTRAINT kpi_rate_rules_rate_per_hour_check: CHECK (rate_per_hour > 0::numeric)
CREATE UNIQUE INDEX kpi_rate_rules_organization_id_process_effective_from_key ON public.kpi_rate_rules USING btree (organization_id, process, effective_from);
CREATE UNIQUE INDEX kpi_rate_rules_pkey ON public.kpi_rate_rules USING btree (id);

-- BASE TABLE: public.kpi_results
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. kpi_definition_id uuid nullable=NO default=
--   4. period_start timestamp with time zone nullable=NO default=
--   5. period_end timestamp with time zone nullable=NO default=
--   6. production_date date nullable=NO default=
--   7. production_area_id uuid nullable=YES default=
--   8. shift_id uuid nullable=YES default=
--   9. machine_id text nullable=YES default=
--   10. operator_id text nullable=YES default=
--   11. order_no text nullable=YES default=
--   12. product_code text nullable=YES default=
--   13. numerator numeric nullable=YES default=
--   14. denominator numeric nullable=YES default=
--   15. value numeric nullable=YES default=
--   16. target_value numeric nullable=YES default=
--   17. status text nullable=NO default=
--   18. data_quality_status text nullable=NO default=
--   19. source_refresh_at timestamp with time zone nullable=YES default=
--   20. calculated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT kpi_results_data_quality_status_check: CHECK (data_quality_status = ANY (ARRAY['NO_DATA'::text, 'PARTIAL_DATA'::text, 'STALE_DATA'::text, 'VALID'::text]))
--   CONSTRAINT kpi_results_kpi_definition_id_fkey: FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id)
--   CONSTRAINT kpi_results_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT kpi_results_pkey: PRIMARY KEY (id)
--   CONSTRAINT kpi_results_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT kpi_results_shift_id_fkey: FOREIGN KEY (shift_id) REFERENCES shift_templates(id)
--   CONSTRAINT kpi_results_status_check: CHECK (status = ANY (ARRAY['GOOD'::text, 'WARNING'::text, 'CRITICAL'::text, 'NO_TARGET'::text, 'NO_DATA'::text]))
CREATE INDEX kpi_results_latest_idx ON public.kpi_results USING btree (organization_id, kpi_definition_id, calculated_at DESC);
CREATE UNIQUE INDEX kpi_results_pkey ON public.kpi_results USING btree (id);

-- BASE TABLE: public.kpi_targets
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. kpi_definition_id uuid nullable=NO default=
--   4. production_area_id uuid nullable=YES default=
--   5. shift_id uuid nullable=YES default=
--   6. effective_from date nullable=NO default=
--   7. effective_to date nullable=YES default=
--   8. target_value numeric nullable=NO default=
--   9. warning_value numeric nullable=YES default=
--   10. critical_value numeric nullable=YES default=
--   11. created_by uuid nullable=YES default=
--   12. created_at timestamp with time zone nullable=NO default=now()
--   13. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT kpi_targets_check: CHECK (effective_to IS NULL OR effective_to >= effective_from)
--   CONSTRAINT kpi_targets_kpi_definition_id_fkey: FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id)
--   CONSTRAINT kpi_targets_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT kpi_targets_pkey: PRIMARY KEY (id)
--   CONSTRAINT kpi_targets_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT kpi_targets_shift_id_fkey: FOREIGN KEY (shift_id) REFERENCES shift_templates(id)
CREATE INDEX kpi_targets_effective_idx ON public.kpi_targets USING btree (organization_id, kpi_definition_id, effective_from DESC);
CREATE UNIQUE INDEX kpi_targets_pkey ON public.kpi_targets USING btree (id);

-- BASE TABLE: public.labour_segments
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. import_batch_id uuid nullable=NO default=
--   4. source_timesheet_row_id uuid nullable=NO default=
--   5. person_key text nullable=NO default=
--   6. area_code text nullable=NO default=
--   7. segment_start timestamp with time zone nullable=NO default=
--   8. segment_end timestamp with time zone nullable=NO default=
--   9. calendar_date date nullable=NO default=
--   10. operational_date date nullable=NO default=
--   11. hour_bucket smallint nullable=NO default=
--   12. shift_code text nullable=NO default=
--   13. paid_hours numeric nullable=NO default=
--   14. regular_hours numeric nullable=NO default=
--   15. overtime_hours numeric nullable=NO default=
--   16. paid_break_hours numeric nullable=NO default=
--   17. productive_hours numeric nullable=NO default=
--   18. approval_status text nullable=NO default=
--   19. allocation_method text nullable=NO default='PRO_RATA_ELAPSED'::text
--   20. week_start date nullable=NO default=
--   21. calculation_version text nullable=NO default='V29_DAILY8_WEEKLY38_WEEKEND_OT_PAID_BREAK20'::text
--   22. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT labour_segments_hour_bucket_check: CHECK (hour_bucket >= 0 AND hour_bucket <= 23)
--   CONSTRAINT labour_segments_import_batch_id_fkey: FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id)
--   CONSTRAINT labour_segments_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT labour_segments_pkey: PRIMARY KEY (id)
--   CONSTRAINT labour_segments_source_timesheet_row_id_fkey: FOREIGN KEY (source_timesheet_row_id) REFERENCES deputy_raw_timesheets(id)
--   CONSTRAINT labour_segments_source_timesheet_row_id_segment_start_key: UNIQUE (source_timesheet_row_id, segment_start)
CREATE INDEX labour_segments_period_idx ON public.labour_segments USING btree (organization_id, operational_date, shift_code, area_code);
CREATE INDEX labour_segments_person_week_idx ON public.labour_segments USING btree (organization_id, person_key, week_start);
CREATE UNIQUE INDEX labour_segments_pkey ON public.labour_segments USING btree (id);
CREATE UNIQUE INDEX labour_segments_source_timesheet_row_id_segment_start_key ON public.labour_segments USING btree (source_timesheet_row_id, segment_start);

-- BASE TABLE: public.maintenance_asset_categories
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. description text nullable=YES default=
--   5. active boolean nullable=NO default=true
--   6. created_at timestamp with time zone nullable=NO default=now()
--   7. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_asset_categories_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_asset_categories_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT maintenance_asset_categories_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX maintenance_asset_categories_organization_id_name_key ON public.maintenance_asset_categories USING btree (organization_id, name);
CREATE UNIQUE INDEX maintenance_asset_categories_pkey ON public.maintenance_asset_categories USING btree (id);

-- VIEW: public.maintenance_asset_code_reconciliation
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. current_name text nullable=YES default=
--   4. current_code text nullable=YES default=
--   5. suggested_new_code text nullable=YES default=
--   6. conflict text nullable=YES default=

-- BASE TABLE: public.maintenance_asset_code_sequences
--   1. organization_id uuid nullable=NO default=
--   2. prefix character varying nullable=NO default=
--   3. last_number integer nullable=NO default=0
--   4. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_asset_code_sequences_last_number_check: CHECK (last_number >= 0)
--   CONSTRAINT maintenance_asset_code_sequences_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_asset_code_sequences_pkey: PRIMARY KEY (organization_id, prefix)
CREATE UNIQUE INDEX maintenance_asset_code_sequences_pkey ON public.maintenance_asset_code_sequences USING btree (organization_id, prefix);

-- VIEW: public.maintenance_asset_current_installations
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. movement_id text nullable=YES default=
--   4. movable_asset_id uuid nullable=YES default=
--   5. host_asset_id uuid nullable=YES default=
--   6. host_system_asset_id uuid nullable=YES default=
--   7. position text nullable=YES default=
--   8. channel text nullable=YES default=
--   9. installed_at timestamp with time zone nullable=YES default=
--   10. removed_at timestamp with time zone nullable=YES default=
--   11. movement_reason text nullable=YES default=
--   12. installed_by text nullable=YES default=
--   13. notes text nullable=YES default=
--   14. created_at timestamp with time zone nullable=YES default=
--   15. updated_at timestamp with time zone nullable=YES default=
--   16. movable_asset_code text nullable=YES default=
--   17. host_asset_code text nullable=YES default=
--   18. host_system_asset_code text nullable=YES default=

-- BASE TABLE: public.maintenance_asset_installations
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. movement_id text nullable=YES default=
--   4. movable_asset_id uuid nullable=NO default=
--   5. host_asset_id uuid nullable=NO default=
--   6. host_system_asset_id uuid nullable=YES default=
--   7. position text nullable=YES default=
--   8. channel text nullable=YES default=
--   9. installed_at timestamp with time zone nullable=NO default=
--   10. removed_at timestamp with time zone nullable=YES default=
--   11. movement_reason text nullable=YES default=
--   12. installed_by text nullable=YES default=
--   13. notes text nullable=YES default=
--   14. created_at timestamp with time zone nullable=NO default=now()
--   15. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_asset_installations_check: CHECK (movable_asset_id <> host_asset_id)
--   CONSTRAINT maintenance_asset_installations_check1: CHECK (removed_at IS NULL OR installed_at < removed_at)
--   CONSTRAINT maintenance_asset_installations_host_asset_id_fkey: FOREIGN KEY (host_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_asset_installations_host_system_asset_id_fkey: FOREIGN KEY (host_system_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_asset_installations_movable_asset_id_fkey: FOREIGN KEY (movable_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_asset_installations_movable_asset_id_tstzrange_excl: EXCLUDE USING gist (movable_asset_id WITH =, tstzrange(installed_at, COALESCE(removed_at, 'infinity'::timestamp with time zone), '[)'::text) WITH &&)
--   CONSTRAINT maintenance_asset_installations_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_asset_installations_organization_id_movement_id_key: UNIQUE (organization_id, movement_id)
--   CONSTRAINT maintenance_asset_installations_pkey: PRIMARY KEY (id)
CREATE INDEX maintenance_asset_installations_movable_asset_id_tstzrange_excl ON public.maintenance_asset_installations USING gist (movable_asset_id, tstzrange(installed_at, COALESCE(removed_at, 'infinity'::timestamp with time zone), '[)'::text));
CREATE UNIQUE INDEX maintenance_asset_installations_organization_id_movement_id_key ON public.maintenance_asset_installations USING btree (organization_id, movement_id);
CREATE UNIQUE INDEX maintenance_asset_installations_pkey ON public.maintenance_asset_installations USING btree (id);
CREATE INDEX maintenance_install_host_idx ON public.maintenance_asset_installations USING btree (organization_id, host_asset_id, installed_at DESC);
CREATE INDEX maintenance_install_movable_idx ON public.maintenance_asset_installations USING btree (organization_id, movable_asset_id, installed_at DESC);
CREATE UNIQUE INDEX maintenance_one_active_installation ON public.maintenance_asset_installations USING btree (movable_asset_id) WHERE (removed_at IS NULL);

-- BASE TABLE: public.maintenance_asset_prefixes
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. category_id uuid nullable=NO default=
--   4. prefix character varying nullable=NO default=
--   5. name text nullable=NO default=
--   6. description text nullable=YES default=
--   7. active boolean nullable=NO default=true
--   8. created_at timestamp with time zone nullable=NO default=now()
--   9. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_asset_prefixes_category_id_fkey: FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id)
--   CONSTRAINT maintenance_asset_prefixes_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_asset_prefixes_organization_id_prefix_key: UNIQUE (organization_id, prefix)
--   CONSTRAINT maintenance_asset_prefixes_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_asset_prefixes_prefix_check: CHECK (prefix::text ~ '^[A-Z]{2,5}$'::text)
CREATE UNIQUE INDEX maintenance_asset_prefixes_organization_id_prefix_key ON public.maintenance_asset_prefixes USING btree (organization_id, prefix);
CREATE UNIQUE INDEX maintenance_asset_prefixes_pkey ON public.maintenance_asset_prefixes USING btree (id);

-- BASE TABLE: public.maintenance_assets
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. asset_code text nullable=NO default=
--   4. name text nullable=NO default=
--   5. location text nullable=YES default=
--   6. criticality text nullable=NO default='medium'::text
--   7. status text nullable=NO default='operational'::text
--   8. active boolean nullable=NO default=true
--   9. created_by uuid nullable=YES default=
--   10. created_at timestamp with time zone nullable=NO default=now()
--   11. updated_at timestamp with time zone nullable=NO default=now()
--   12. public_qr_token uuid nullable=NO default=gen_random_uuid()
--   13. asset_name text nullable=YES default=
--   14. category_id uuid nullable=YES default=
--   15. prefix_id uuid nullable=YES default=
--   16. parent_asset_id uuid nullable=YES default=
--   17. manufacturer text nullable=YES default=
--   18. model text nullable=YES default=
--   19. serial_number text nullable=YES default=
--   20. description text nullable=YES default=
--   21. installation_date date nullable=YES default=
--   22. purchase_date date nullable=YES default=
--   23. purchase_cost numeric nullable=YES default=
--   24. warranty_expiry date nullable=YES default=
--   25. installed_at timestamp with time zone nullable=YES default=
--   26. removed_at timestamp with time zone nullable=YES default=
--   27. installed_work_order_id uuid nullable=YES default=
--   28. removed_work_order_id uuid nullable=YES default=
--   29. asset_kind text nullable=NO default='FIXED'::text
--   30. asset_type text nullable=YES default=
--   31. asset_category text nullable=YES default=
--   32. commission_date date nullable=YES default=
--   33. retire_date date nullable=YES default=
--   34. notes text nullable=YES default=
--   35. asset_level text nullable=NO default='EQUIPMENT'::text
--   36. operational_role text nullable=NO default='SUPPORT'::text
--   37. counts_in_availability boolean nullable=NO default=false
--   38. capacity_resource boolean nullable=NO default=false
--   CONSTRAINT maintenance_assets_asset_kind_check: CHECK (asset_kind = ANY (ARRAY['FIXED'::text, 'MOVABLE'::text]))
--   CONSTRAINT maintenance_assets_asset_level_check: CHECK (asset_level = ANY (ARRAY['SYSTEM'::text, 'EQUIPMENT'::text, 'SUBSYSTEM'::text, 'COMPONENT'::text]))
--   CONSTRAINT maintenance_assets_category_id_fkey: FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id)
--   CONSTRAINT maintenance_assets_criticality_check: CHECK (criticality = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))
--   CONSTRAINT maintenance_assets_installed_work_order_id_fkey: FOREIGN KEY (installed_work_order_id) REFERENCES maintenance_work_orders(id)
--   CONSTRAINT maintenance_assets_operational_role_check: CHECK (operational_role = ANY (ARRAY['PRODUCTION'::text, 'UTILITY'::text, 'SUPPORT'::text, 'MOVABLE'::text]))
--   CONSTRAINT maintenance_assets_organization_id_asset_code_key: UNIQUE (organization_id, asset_code)
--   CONSTRAINT maintenance_assets_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_assets_parent_asset_id_fkey: FOREIGN KEY (parent_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_assets_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_assets_prefix_id_fkey: FOREIGN KEY (prefix_id) REFERENCES maintenance_asset_prefixes(id)
--   CONSTRAINT maintenance_assets_removed_work_order_id_fkey: FOREIGN KEY (removed_work_order_id) REFERENCES maintenance_work_orders(id)
--   CONSTRAINT maintenance_assets_status_check: CHECK (status = ANY (ARRAY['operational'::text, 'down'::text, 'maintenance'::text, 'standby'::text, 'retired'::text, 'scrapped'::text]))
CREATE INDEX maintenance_asset_org_status_idx ON public.maintenance_assets USING btree (organization_id, status) WHERE active;
CREATE INDEX maintenance_asset_parent_idx ON public.maintenance_assets USING btree (organization_id, parent_asset_id);
CREATE UNIQUE INDEX maintenance_asset_qr_token_idx ON public.maintenance_assets USING btree (public_qr_token);
CREATE INDEX maintenance_asset_search_idx ON public.maintenance_assets USING btree (organization_id, asset_code, name, serial_number);
CREATE INDEX maintenance_assets_availability_idx ON public.maintenance_assets USING btree (organization_id, counts_in_availability) WHERE (active AND counts_in_availability);
CREATE UNIQUE INDEX maintenance_assets_organization_id_asset_code_key ON public.maintenance_assets USING btree (organization_id, asset_code);
CREATE UNIQUE INDEX maintenance_assets_pkey ON public.maintenance_assets USING btree (id);

-- BASE TABLE: public.maintenance_attachments
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_id uuid nullable=NO default=
--   4. file_name text nullable=NO default=
--   5. storage_path text nullable=NO default=
--   6. mime_type text nullable=YES default=
--   7. file_size bigint nullable=YES default=
--   8. uploaded_by uuid nullable=YES default=
--   9. uploaded_by_email text nullable=YES default=
--   10. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_attachments_file_size_check: CHECK (file_size >= 0)
--   CONSTRAINT maintenance_attachments_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_attachments_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_attachments_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE UNIQUE INDEX maintenance_attachments_pkey ON public.maintenance_attachments USING btree (id);
CREATE INDEX maintenance_attachments_wo_idx ON public.maintenance_attachments USING btree (work_order_id, created_at);

-- BASE TABLE: public.maintenance_audit_log
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. user_id uuid nullable=YES default=
--   4. entity_type text nullable=NO default=
--   5. entity_id uuid nullable=YES default=
--   6. action text nullable=NO default=
--   7. old_values jsonb nullable=YES default=
--   8. new_values jsonb nullable=YES default=
--   9. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_audit_log_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_audit_log_pkey: PRIMARY KEY (id)
CREATE INDEX maintenance_audit_entity_idx ON public.maintenance_audit_log USING btree (organization_id, entity_type, entity_id, created_at DESC);
CREATE UNIQUE INDEX maintenance_audit_log_pkey ON public.maintenance_audit_log USING btree (id);

-- BASE TABLE: public.maintenance_component_code_sequences
--   1. organization_id uuid nullable=NO default=
--   2. parent_asset_id uuid nullable=NO default=
--   3. component_prefix character varying nullable=NO default=
--   4. last_number integer nullable=NO default=0
--   5. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_component_code_sequences_last_number_check: CHECK (last_number >= 0)
--   CONSTRAINT maintenance_component_code_sequences_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_component_code_sequences_parent_asset_id_fkey: FOREIGN KEY (parent_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_component_code_sequences_pkey: PRIMARY KEY (organization_id, parent_asset_id, component_prefix)
CREATE UNIQUE INDEX maintenance_component_code_sequences_pkey ON public.maintenance_component_code_sequences USING btree (organization_id, parent_asset_id, component_prefix);

-- BASE TABLE: public.maintenance_component_prefixes
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. prefix character varying nullable=NO default=
--   4. name text nullable=NO default=
--   5. description text nullable=YES default=
--   6. active boolean nullable=NO default=true
--   7. created_at timestamp with time zone nullable=NO default=now()
--   8. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_component_prefixes_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_component_prefixes_organization_id_prefix_key: UNIQUE (organization_id, prefix)
--   CONSTRAINT maintenance_component_prefixes_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_component_prefixes_prefix_check: CHECK (prefix::text ~ '^[A-Z]{2,4}$'::text)
CREATE UNIQUE INDEX maintenance_component_prefixes_organization_id_prefix_key ON public.maintenance_component_prefixes USING btree (organization_id, prefix);
CREATE UNIQUE INDEX maintenance_component_prefixes_pkey ON public.maintenance_component_prefixes USING btree (id);

-- BASE TABLE: public.maintenance_downtime_events
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. asset_id uuid nullable=NO default=
--   4. work_order_id uuid nullable=YES default=
--   5. started_at timestamp with time zone nullable=NO default=now()
--   6. ended_at timestamp with time zone nullable=YES default=
--   7. reason text nullable=YES default=
--   8. started_by uuid nullable=YES default=
--   9. ended_by uuid nullable=YES default=
--   10. event_code text nullable=YES default=
--   11. event_date date nullable=YES default=
--   12. host_asset_id uuid nullable=YES default=
--   13. host_system_asset_id uuid nullable=YES default=
--   14. affected_asset_id uuid nullable=YES default=
--   15. downtime_minutes numeric nullable=YES default=
--   16. event_type text nullable=YES default=
--   17. maintenance_class text nullable=YES default=
--   18. failure_category text nullable=YES default=
--   19. failure_mode text nullable=YES default=
--   20. root_cause text nullable=YES default=
--   21. action_taken text nullable=YES default=
--   22. spare_parts_text text nullable=YES default=
--   23. description text nullable=YES default=
--   24. counts_as_failure boolean nullable=NO default=false
--   25. counts_as_downtime boolean nullable=NO default=true
--   26. event_status text nullable=YES default=
--   27. source_system text nullable=YES default=
--   28. source_key text nullable=YES default=
--   29. source_row integer nullable=YES default=
--   30. original_duration_minutes numeric nullable=YES default=
--   31. clock_duration_minutes numeric nullable=YES default=
--   32. correction_factor numeric nullable=YES default=
--   33. data_quality_status text nullable=YES default=
--   34. correction_confidence text nullable=YES default=
--   35. correction_method text nullable=YES default=
--   36. correction_note text nullable=YES default=
--   37. raw_reason text nullable=YES default=
--   38. historical_asset_reference text nullable=YES default=
--   39. created_at timestamp with time zone nullable=NO default=now()
--   40. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_downtime_events_affected_asset_id_fkey: FOREIGN KEY (affected_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_downtime_events_asset_id_fkey: FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_downtime_events_host_asset_id_fkey: FOREIGN KEY (host_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_downtime_events_host_system_asset_id_fkey: FOREIGN KEY (host_system_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_downtime_events_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_downtime_events_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_downtime_events_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE UNIQUE INDEX maintenance_downtime_events_pkey ON public.maintenance_downtime_events USING btree (id);
CREATE INDEX maintenance_downtime_org_started_idx ON public.maintenance_downtime_events USING btree (organization_id, started_at DESC);
CREATE INDEX maintenance_event_affected_idx ON public.maintenance_downtime_events USING btree (organization_id, affected_asset_id, event_date);
CREATE INDEX maintenance_event_date_idx ON public.maintenance_downtime_events USING btree (organization_id, event_date);
CREATE INDEX maintenance_event_host_idx ON public.maintenance_downtime_events USING btree (organization_id, host_asset_id, event_date);
CREATE UNIQUE INDEX maintenance_event_source_unique ON public.maintenance_downtime_events USING btree (organization_id, source_system, source_key) WHERE ((source_system IS NOT NULL) AND (source_key IS NOT NULL));
CREATE UNIQUE INDEX maintenance_one_active_down ON public.maintenance_downtime_events USING btree (asset_id) WHERE (ended_at IS NULL);

-- BASE TABLE: public.maintenance_import_batches
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. file_name text nullable=NO default=
--   4. file_hash text nullable=NO default=
--   5. source_system text nullable=NO default=
--   6. status text nullable=NO default=
--   7. uploaded_by uuid nullable=YES default=
--   8. started_at timestamp with time zone nullable=NO default=now()
--   9. completed_at timestamp with time zone nullable=YES default=
--   10. total_rows integer nullable=NO default=0
--   11. valid_rows integer nullable=NO default=0
--   12. warning_rows integer nullable=NO default=0
--   13. error_rows integer nullable=NO default=0
--   14. inserted_rows integer nullable=NO default=0
--   15. updated_rows integer nullable=NO default=0
--   16. skipped_rows integer nullable=NO default=0
--   17. import_report jsonb nullable=NO default='{}'::jsonb
--   18. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_import_batches_organization_id_file_hash_key: UNIQUE (organization_id, file_hash)
--   CONSTRAINT maintenance_import_batches_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_import_batches_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_import_batches_status_check: CHECK (status = ANY (ARRAY['VALIDATING'::text, 'READY'::text, 'IMPORTING'::text, 'COMPLETED'::text, 'FAILED'::text, 'ROLLED_BACK'::text]))
CREATE UNIQUE INDEX maintenance_import_batches_organization_id_file_hash_key ON public.maintenance_import_batches USING btree (organization_id, file_hash);
CREATE UNIQUE INDEX maintenance_import_batches_pkey ON public.maintenance_import_batches USING btree (id);

-- BASE TABLE: public.maintenance_import_staging
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. batch_id uuid nullable=NO default=
--   3. organization_id uuid nullable=NO default=
--   4. source_row integer nullable=YES default=
--   5. row_status text nullable=NO default=
--   6. source_key text nullable=YES default=
--   7. host_asset_code text nullable=YES default=
--   8. affected_asset_code text nullable=YES default=
--   9. historical_asset_reference text nullable=YES default=
--   10. errors ARRAY nullable=NO default='{}'::text[]
--   11. warnings ARRAY nullable=NO default='{}'::text[]
--   12. payload jsonb nullable=NO default=
--   13. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_import_staging_batch_id_fkey: FOREIGN KEY (batch_id) REFERENCES maintenance_import_batches(id) ON DELETE CASCADE
--   CONSTRAINT maintenance_import_staging_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_import_staging_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_import_staging_row_status_check: CHECK (row_status = ANY (ARRAY['VALID'::text, 'WARNING'::text, 'ERROR'::text, 'DUPLICATE'::text, 'UNRESOLVED_PH'::text]))
CREATE UNIQUE INDEX maintenance_import_staging_pkey ON public.maintenance_import_staging USING btree (id);
CREATE INDEX maintenance_staging_batch_idx ON public.maintenance_import_staging USING btree (batch_id, row_status);

-- BASE TABLE: public.maintenance_inventory_locations
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. code text nullable=YES default=
--   5. active boolean nullable=NO default=true
--   6. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_inventory_locations_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_inventory_locations_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT maintenance_inventory_locations_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX maintenance_inventory_locations_organization_id_name_key ON public.maintenance_inventory_locations USING btree (organization_id, name);
CREATE UNIQUE INDEX maintenance_inventory_locations_pkey ON public.maintenance_inventory_locations USING btree (id);

-- BASE TABLE: public.maintenance_inventory_transactions
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. part_id uuid nullable=NO default=
--   4. location_id uuid nullable=NO default=
--   5. work_order_id uuid nullable=YES default=
--   6. transaction_type text nullable=NO default=
--   7. quantity numeric nullable=NO default=
--   8. unit_cost_snapshot numeric nullable=NO default=0
--   9. notes text nullable=YES default=
--   10. created_by uuid nullable=YES default=
--   11. created_by_email text nullable=YES default=
--   12. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_inventory_transactions_check: CHECK ((transaction_type = ANY (ARRAY['receipt'::text, 'return'::text])) AND quantity > 0::numeric OR transaction_type = 'issue'::text AND quantity < 0::numeric OR transaction_type = 'adjustment'::text)
--   CONSTRAINT maintenance_inventory_transactions_location_id_fkey: FOREIGN KEY (location_id) REFERENCES maintenance_inventory_locations(id)
--   CONSTRAINT maintenance_inventory_transactions_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_inventory_transactions_part_id_fkey: FOREIGN KEY (part_id) REFERENCES maintenance_parts(id)
--   CONSTRAINT maintenance_inventory_transactions_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_inventory_transactions_quantity_check: CHECK (quantity <> 0::numeric)
--   CONSTRAINT maintenance_inventory_transactions_transaction_type_check: CHECK (transaction_type = ANY (ARRAY['receipt'::text, 'issue'::text, 'return'::text, 'adjustment'::text]))
--   CONSTRAINT maintenance_inventory_transactions_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE INDEX maintenance_inventory_part_location_idx ON public.maintenance_inventory_transactions USING btree (part_id, location_id, created_at);
CREATE UNIQUE INDEX maintenance_inventory_transactions_pkey ON public.maintenance_inventory_transactions USING btree (id);
CREATE INDEX maintenance_inventory_wo_idx ON public.maintenance_inventory_transactions USING btree (work_order_id) WHERE (work_order_id IS NOT NULL);

-- BASE TABLE: public.maintenance_members
--   1. user_id uuid nullable=NO default=
--   2. organization_id uuid nullable=NO default=
--   3. role text nullable=NO default=
--   4. active boolean nullable=NO default=true
--   5. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_members_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_members_pkey: PRIMARY KEY (user_id, organization_id)
--   CONSTRAINT maintenance_members_role_check: CHECK (role = ANY (ARRAY['admin'::text, 'maintenance'::text, 'supervisor'::text, 'operator'::text, 'viewer'::text]))
--   CONSTRAINT maintenance_members_user_id_fkey: FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
CREATE UNIQUE INDEX maintenance_members_pkey ON public.maintenance_members USING btree (user_id, organization_id);

-- VIEW: public.maintenance_part_stock_levels
--   1. organization_id uuid nullable=YES default=
--   2. part_id uuid nullable=YES default=
--   3. part_number text nullable=YES default=
--   4. description text nullable=YES default=
--   5. manufacturer text nullable=YES default=
--   6. unit_cost numeric nullable=YES default=
--   7. reorder_point numeric nullable=YES default=
--   8. location_id uuid nullable=YES default=
--   9. location text nullable=YES default=
--   10. stock_on_hand numeric nullable=YES default=

-- BASE TABLE: public.maintenance_parts
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. part_number text nullable=NO default=
--   4. description text nullable=NO default=
--   5. manufacturer text nullable=YES default=
--   6. unit_cost numeric nullable=NO default=0
--   7. reorder_point numeric nullable=NO default=0
--   8. active boolean nullable=NO default=true
--   9. created_at timestamp with time zone nullable=NO default=now()
--   10. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_parts_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_parts_organization_id_part_number_key: UNIQUE (organization_id, part_number)
--   CONSTRAINT maintenance_parts_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX maintenance_parts_organization_id_part_number_key ON public.maintenance_parts USING btree (organization_id, part_number);
CREATE UNIQUE INDEX maintenance_parts_pkey ON public.maintenance_parts USING btree (id);

-- BASE TABLE: public.maintenance_preventive_plan_tasks
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. preventive_plan_id uuid nullable=NO default=
--   4. sequence integer nullable=NO default=
--   5. task text nullable=NO default=
--   6. instructions text nullable=YES default=
--   7. required boolean nullable=NO default=true
--   8. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_preventive_plan_tasks_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_preventive_plan_tasks_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_preventive_plan_tasks_preventive_plan_id_fkey: FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id)
CREATE UNIQUE INDEX maintenance_preventive_plan_tasks_pkey ON public.maintenance_preventive_plan_tasks USING btree (id);

-- BASE TABLE: public.maintenance_preventive_plans
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. asset_id uuid nullable=NO default=
--   4. code text nullable=YES default=
--   5. name text nullable=NO default=
--   6. description text nullable=YES default=
--   7. priority text nullable=NO default='medium'::text
--   8. trigger_type text nullable=NO default='calendar'::text
--   9. frequency_value integer nullable=YES default=
--   10. frequency_unit text nullable=YES default=
--   11. next_due_at timestamp with time zone nullable=YES default=
--   12. lead_time_days integer nullable=NO default=0
--   13. estimated_minutes integer nullable=YES default=
--   14. active boolean nullable=NO default=true
--   15. created_at timestamp with time zone nullable=NO default=now()
--   16. updated_at timestamp with time zone nullable=NO default=now()
--   17. requires_downtime boolean nullable=NO default=false
--   CONSTRAINT maintenance_preventive_plans_asset_id_fkey: FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_preventive_plans_frequency_unit_check: CHECK (frequency_unit = ANY (ARRAY['day'::text, 'week'::text, 'month'::text, 'year'::text]))
--   CONSTRAINT maintenance_preventive_plans_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_preventive_plans_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_preventive_plans_priority_check: CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))
--   CONSTRAINT maintenance_preventive_plans_trigger_type_check: CHECK (trigger_type = ANY (ARRAY['calendar'::text, 'meter'::text]))
CREATE INDEX maintenance_pm_due_idx ON public.maintenance_preventive_plans USING btree (organization_id, next_due_at) WHERE active;
CREATE UNIQUE INDEX maintenance_preventive_plans_pkey ON public.maintenance_preventive_plans USING btree (id);

-- BASE TABLE: public.maintenance_work_order_checklist
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_id uuid nullable=NO default=
--   4. sequence integer nullable=NO default=
--   5. task text nullable=NO default=
--   6. instructions text nullable=YES default=
--   7. required boolean nullable=NO default=true
--   8. completed boolean nullable=NO default=false
--   9. completed_at timestamp with time zone nullable=YES default=
--   10. completed_by uuid nullable=YES default=
--   CONSTRAINT maintenance_work_order_checklist_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_work_order_checklist_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_work_order_checklist_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
--   CONSTRAINT maintenance_work_order_checklist_work_order_id_sequence_key: UNIQUE (work_order_id, sequence)
CREATE UNIQUE INDEX maintenance_work_order_checklist_pkey ON public.maintenance_work_order_checklist USING btree (id);
CREATE UNIQUE INDEX maintenance_work_order_checklist_work_order_id_sequence_key ON public.maintenance_work_order_checklist USING btree (work_order_id, sequence);

-- BASE TABLE: public.maintenance_work_order_comments
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_id uuid nullable=NO default=
--   4. user_id uuid nullable=YES default=
--   5. author_email text nullable=YES default=
--   6. comment text nullable=NO default=
--   7. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_work_order_comments_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_work_order_comments_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_work_order_comments_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE INDEX maintenance_comments_wo_idx ON public.maintenance_work_order_comments USING btree (work_order_id, created_at);
CREATE UNIQUE INDEX maintenance_work_order_comments_pkey ON public.maintenance_work_order_comments USING btree (id);

-- BASE TABLE: public.maintenance_work_order_history
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_id uuid nullable=NO default=
--   4. from_status text nullable=YES default=
--   5. to_status text nullable=NO default=
--   6. changed_by uuid nullable=YES default=
--   7. changed_by_email text nullable=YES default=
--   8. changed_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_work_order_history_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_work_order_history_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_work_order_history_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE UNIQUE INDEX maintenance_work_order_history_pkey ON public.maintenance_work_order_history USING btree (id);

-- BASE TABLE: public.maintenance_work_order_labor
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_id uuid nullable=NO default=
--   4. user_id uuid nullable=YES default=
--   5. technician_email text nullable=YES default=
--   6. minutes integer nullable=NO default=
--   7. hourly_rate_snapshot numeric nullable=YES default=
--   8. description text nullable=YES default=
--   9. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT maintenance_work_order_labor_minutes_check: CHECK (minutes > 0)
--   CONSTRAINT maintenance_work_order_labor_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_work_order_labor_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_work_order_labor_work_order_id_fkey: FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)
CREATE INDEX maintenance_labor_wo_idx ON public.maintenance_work_order_labor USING btree (work_order_id, created_at);
CREATE UNIQUE INDEX maintenance_work_order_labor_pkey ON public.maintenance_work_order_labor USING btree (id);

-- BASE TABLE: public.maintenance_work_orders
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. work_order_number text nullable=NO default=
--   4. asset_id uuid nullable=NO default=
--   5. status text nullable=NO default='open'::text
--   6. priority text nullable=NO default='medium'::text
--   7. title text nullable=NO default=
--   8. problem_description text nullable=YES default=
--   9. root_cause text nullable=YES default=
--   10. resolution text nullable=YES default=
--   11. requested_by uuid nullable=YES default=
--   12. requested_by_email text nullable=YES default=
--   13. requested_at timestamp with time zone nullable=NO default=now()
--   14. started_at timestamp with time zone nullable=YES default=
--   15. completed_at timestamp with time zone nullable=YES default=
--   16. updated_at timestamp with time zone nullable=NO default=now()
--   17. cancel_reason text nullable=YES default=
--   18. work_order_type text nullable=NO default='corrective'::text
--   19. preventive_plan_id uuid nullable=YES default=
--   20. due_at timestamp with time zone nullable=YES default=
--   21. component_asset_id uuid nullable=YES default=
--   22. no_parts_used_confirmed boolean nullable=NO default=false
--   23. no_parts_used_confirmed_at timestamp with time zone nullable=YES default=
--   24. no_parts_used_confirmed_by uuid nullable=YES default=
--   25. source_pm_work_order_id uuid nullable=YES default=
--   26. request_flow text nullable=YES default=
--   27. request_type text nullable=YES default=
--   28. maintenance_requested_at timestamp with time zone nullable=YES default=
--   29. counts_as_downtime boolean nullable=NO default=false
--   30. operator_request_key text nullable=YES default=
--   31. downtime_started_at timestamp with time zone nullable=YES default=
--   CONSTRAINT maintenance_wo_pm_fk: FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id)
--   CONSTRAINT maintenance_work_orders_asset_id_fkey: FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_work_orders_component_asset_id_fkey: FOREIGN KEY (component_asset_id) REFERENCES maintenance_assets(id)
--   CONSTRAINT maintenance_work_orders_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT maintenance_work_orders_pkey: PRIMARY KEY (id)
--   CONSTRAINT maintenance_work_orders_priority_check: CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))
--   CONSTRAINT maintenance_work_orders_request_flow_check: CHECK (request_flow = ANY (ARRAY['operator_fix'::text, 'maintenance_required'::text, 'maintenance_request'::text]))
--   CONSTRAINT maintenance_work_orders_source_pm_work_order_id_fkey: FOREIGN KEY (source_pm_work_order_id) REFERENCES maintenance_work_orders(id)
--   CONSTRAINT maintenance_work_orders_status_check: CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'waiting_parts'::text, 'waiting_external'::text, 'completed'::text, 'cancelled'::text, 'OPEN_OPERATOR'::text, 'WAITING_MAINTENANCE'::text, 'REQUESTED'::text]))
--   CONSTRAINT maintenance_work_orders_work_order_number_key: UNIQUE (work_order_number)
--   CONSTRAINT maintenance_work_orders_work_order_type_check: CHECK (work_order_type = ANY (ARRAY['corrective'::text, 'preventive'::text, 'inspection'::text]))
CREATE UNIQUE INDEX maintenance_one_open_pm ON public.maintenance_work_orders USING btree (preventive_plan_id) WHERE ((preventive_plan_id IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])));
CREATE UNIQUE INDEX maintenance_operator_request_key_uq ON public.maintenance_work_orders USING btree (organization_id, operator_request_key) WHERE (operator_request_key IS NOT NULL);
CREATE INDEX maintenance_wo_org_status_due_idx ON public.maintenance_work_orders USING btree (organization_id, status, due_at);
CREATE INDEX maintenance_wo_source_pm_idx ON public.maintenance_work_orders USING btree (source_pm_work_order_id) WHERE (source_pm_work_order_id IS NOT NULL);
CREATE UNIQUE INDEX maintenance_work_orders_pkey ON public.maintenance_work_orders USING btree (id);
CREATE UNIQUE INDEX maintenance_work_orders_work_order_number_key ON public.maintenance_work_orders USING btree (work_order_number);

-- BASE TABLE: public.organizations
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. name text nullable=NO default=
--   3. timezone text nullable=NO default='Australia/Brisbane'::text
--   4. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT organizations_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX organizations_pkey ON public.organizations USING btree (id);

-- BASE TABLE: public.production_areas
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. code text nullable=NO default=
--   4. name text nullable=NO default=
--   5. sequence integer nullable=NO default=0
--   6. active boolean nullable=NO default=true
--   7. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_areas_organization_id_code_key: UNIQUE (organization_id, code)
--   CONSTRAINT production_areas_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_areas_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX production_areas_organization_id_code_key ON public.production_areas USING btree (organization_id, code);
CREATE UNIQUE INDEX production_areas_pkey ON public.production_areas USING btree (id);

-- BASE TABLE: public.production_events
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. event_id text nullable=NO default=
--   4. event_ts_utc timestamp with time zone nullable=NO default=
--   5. event_ts_local timestamp without time zone nullable=NO default=
--   6. calendar_date date nullable=NO default=
--   7. operational_date date nullable=NO default=
--   8. hour_bucket smallint nullable=NO default=
--   9. shift_code text nullable=NO default=
--   10. area text nullable=NO default=
--   11. metric text nullable=NO default=
--   12. quantity numeric nullable=NO default=
--   13. unit text nullable=NO default=
--   14. source text nullable=NO default=
--   15. source_mode text nullable=NO default=
--   16. source_record_key text nullable=NO default=
--   17. quality_status text nullable=NO default=
--   18. import_batch_id uuid nullable=YES default=
--   19. calculation_version text nullable=NO default=
--   20. is_partial_period boolean nullable=NO default=false
--   21. operational_shift_overtime boolean nullable=NO default=false
--   22. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_events_hour_bucket_check: CHECK (hour_bucket >= 0 AND hour_bucket <= 23)
--   CONSTRAINT production_events_metric_check: CHECK (metric = ANY (ARRAY['DTG_PRINT'::text, 'DTG_PUTWALL_IN'::text, 'DTG_PUTWALL_OUT'::text, 'UP_IN'::text, 'UP_OUT'::text, 'SCREEN_PRINT'::text, 'SCREEN_MACHINE_HOURS'::text]))
--   CONSTRAINT production_events_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_events_organization_id_source_source_record_key__key: UNIQUE (organization_id, source, source_record_key, metric)
--   CONSTRAINT production_events_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_events_quality_status_check: CHECK (quality_status = ANY (ARRAY['COMPLETE'::text, 'PARTIAL'::text, 'PROVISIONAL'::text, 'MISSING_SOURCE'::text, 'NO_TARGET_HOURS'::text, 'OUT_OF_SHIFT'::text, 'REJECTED'::text]))
--   CONSTRAINT production_events_shift_code_check: CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OUT_OF_SHIFT'::text]))
CREATE UNIQUE INDEX production_events_organization_id_source_source_record_key__key ON public.production_events USING btree (organization_id, source, source_record_key, metric);
CREATE INDEX production_events_period_idx ON public.production_events USING btree (organization_id, operational_date, shift_code, metric);
CREATE UNIQUE INDEX production_events_pkey ON public.production_events USING btree (id);
CREATE INDEX production_events_timestamp_idx ON public.production_events USING btree (organization_id, event_ts_utc);

-- BASE TABLE: public.production_order_history
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. production_order_id uuid nullable=NO default=
--   3. organization_id uuid nullable=NO default=
--   4. order_no text nullable=NO default=
--   5. changed_by uuid nullable=YES default=
--   6. changed_by_email text nullable=YES default=
--   7. changed_at timestamp with time zone nullable=NO default=now()
--   8. before_state jsonb nullable=NO default=
--   9. after_state jsonb nullable=NO default=
--   CONSTRAINT production_order_history_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_order_history_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_order_history_production_order_id_fkey: FOREIGN KEY (production_order_id) REFERENCES production_orders(id)
CREATE INDEX production_order_history_order_idx ON public.production_order_history USING btree (organization_id, order_no, changed_at DESC);
CREATE UNIQUE INDEX production_order_history_pkey ON public.production_order_history USING btree (id);

-- BASE TABLE: public.production_orders
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. order_no text nullable=NO default=
--   4. planner_priority integer nullable=YES default=
--   5. planned_date date nullable=YES default=
--   6. planned_shift_id uuid nullable=YES default=
--   7. planning_status text nullable=NO default='unplanned'::text
--   8. special_instruction text nullable=YES default=
--   9. planner_note text nullable=YES default=
--   10. blocked_reason text nullable=YES default=
--   11. created_at timestamp with time zone nullable=NO default=now()
--   12. updated_at timestamp with time zone nullable=NO default=now()
--   13. updated_by uuid nullable=YES default=
--   CONSTRAINT production_orders_check: CHECK (planning_status = 'blocked'::text OR blocked_reason IS NULL)
--   CONSTRAINT production_orders_check1: CHECK (planning_status <> 'blocked'::text OR NULLIF(TRIM(BOTH FROM blocked_reason), ''::text) IS NOT NULL)
--   CONSTRAINT production_orders_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_orders_organization_id_order_no_key: UNIQUE (organization_id, order_no)
--   CONSTRAINT production_orders_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_orders_planned_shift_id_fkey: FOREIGN KEY (planned_shift_id) REFERENCES shift_templates(id)
--   CONSTRAINT production_orders_planner_priority_check: CHECK (planner_priority >= 0 AND planner_priority <= 999)
--   CONSTRAINT production_orders_planning_status_check: CHECK (planning_status = ANY (ARRAY['unplanned'::text, 'planned'::text, 'ready'::text, 'in_progress'::text, 'blocked'::text, 'waiting'::text, 'completed'::text, 'cancelled'::text]))
CREATE UNIQUE INDEX production_orders_organization_id_order_no_key ON public.production_orders USING btree (organization_id, order_no);
CREATE UNIQUE INDEX production_orders_pkey ON public.production_orders USING btree (id);

-- BASE TABLE: public.production_plan_history
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. production_plan_id uuid nullable=NO default=
--   3. action text nullable=NO default=
--   4. changed_by uuid nullable=YES default=
--   5. changed_by_email text nullable=YES default=
--   6. changed_at timestamp with time zone nullable=NO default=now()
--   7. snapshot jsonb nullable=NO default=
--   CONSTRAINT production_plan_history_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_plan_history_production_plan_id_fkey: FOREIGN KEY (production_plan_id) REFERENCES production_plans(id)
CREATE UNIQUE INDEX production_plan_history_pkey ON public.production_plan_history USING btree (id);

-- BASE TABLE: public.production_plan_items
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. production_plan_id uuid nullable=NO default=
--   3. production_order_id uuid nullable=NO default=
--   4. order_no text nullable=NO default=
--   5. sequence integer nullable=NO default=
--   6. planned_units numeric nullable=NO default=
--   7. responsible text nullable=YES default=
--   8. special_instruction text nullable=YES default=
--   9. created_at timestamp with time zone nullable=NO default=now()
--   10. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_plan_items_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_plan_items_planned_units_check: CHECK (planned_units > 0::numeric)
--   CONSTRAINT production_plan_items_production_order_id_fkey: FOREIGN KEY (production_order_id) REFERENCES production_orders(id)
--   CONSTRAINT production_plan_items_production_plan_id_fkey: FOREIGN KEY (production_plan_id) REFERENCES production_plans(id) ON DELETE CASCADE
--   CONSTRAINT production_plan_items_production_plan_id_production_order_i_key: UNIQUE (production_plan_id, production_order_id)
--   CONSTRAINT production_plan_items_production_plan_id_sequence_key: UNIQUE (production_plan_id, sequence)
CREATE UNIQUE INDEX production_plan_items_pkey ON public.production_plan_items USING btree (id);
CREATE UNIQUE INDEX production_plan_items_production_plan_id_production_order_i_key ON public.production_plan_items USING btree (production_plan_id, production_order_id);
CREATE UNIQUE INDEX production_plan_items_production_plan_id_sequence_key ON public.production_plan_items USING btree (production_plan_id, sequence);

-- BASE TABLE: public.production_plans
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. production_date date nullable=NO default=
--   4. shift_template_id uuid nullable=NO default=
--   5. production_area_id uuid nullable=NO default=
--   6. status text nullable=NO default='draft'::text
--   7. version integer nullable=NO default=1
--   8. created_by uuid nullable=YES default=
--   9. published_by uuid nullable=YES default=
--   10. published_at timestamp with time zone nullable=YES default=
--   11. closed_by uuid nullable=YES default=
--   12. closed_at timestamp with time zone nullable=YES default=
--   13. created_at timestamp with time zone nullable=NO default=now()
--   14. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_plans_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_plans_organization_id_production_date_shift_temp_key: UNIQUE (organization_id, production_date, shift_template_id, production_area_id)
--   CONSTRAINT production_plans_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_plans_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT production_plans_shift_template_id_fkey: FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)
--   CONSTRAINT production_plans_status_check: CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'closed'::text]))
CREATE UNIQUE INDEX production_plans_organization_id_production_date_shift_temp_key ON public.production_plans USING btree (organization_id, production_date, shift_template_id, production_area_id);
CREATE UNIQUE INDEX production_plans_pkey ON public.production_plans USING btree (id);

-- BASE TABLE: public.production_process_stages
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. production_process_id uuid nullable=NO default=
--   4. code text nullable=NO default=
--   5. name text nullable=NO default=
--   6. sequence integer nullable=NO default=
--   7. source_type text nullable=NO default=
--   8. capacity_area_code text nullable=YES default=
--   9. active boolean nullable=NO default=true
--   10. created_at timestamp with time zone nullable=NO default=now()
--   11. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_process_stages_organization_id_code_key: UNIQUE (organization_id, code)
--   CONSTRAINT production_process_stages_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_process_stages_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_process_stages_production_process_id_fkey: FOREIGN KEY (production_process_id) REFERENCES production_processes(id)
--   CONSTRAINT production_process_stages_source_type_check: CHECK (source_type = ANY (ARRAY['oracle_workbank'::text, 'oracle_stock'::text, 'oracle_location'::text, 'oracle_audit'::text, 'manual'::text]))
CREATE INDEX process_stage_org_idx ON public.production_process_stages USING btree (organization_id, production_process_id, sequence);
CREATE UNIQUE INDEX production_process_stages_organization_id_code_key ON public.production_process_stages USING btree (organization_id, code);
CREATE UNIQUE INDEX production_process_stages_pkey ON public.production_process_stages USING btree (id);

-- BASE TABLE: public.production_processes
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. code text nullable=NO default=
--   4. name text nullable=NO default=
--   5. sequence integer nullable=NO default=
--   6. active boolean nullable=NO default=true
--   7. created_at timestamp with time zone nullable=NO default=now()
--   8. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_processes_organization_id_code_key: UNIQUE (organization_id, code)
--   CONSTRAINT production_processes_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_processes_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX production_processes_organization_id_code_key ON public.production_processes USING btree (organization_id, code);
CREATE UNIQUE INDEX production_processes_pkey ON public.production_processes USING btree (id);

-- BASE TABLE: public.production_stage_mappings
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. production_area_id uuid nullable=NO default=
--   4. source_field text nullable=NO default=
--   5. match_pattern text nullable=NO default=
--   6. priority integer nullable=NO default=100
--   7. active boolean nullable=NO default=true
--   8. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_stage_mappings_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_stage_mappings_organization_id_source_field_matc_key: UNIQUE (organization_id, source_field, match_pattern)
--   CONSTRAINT production_stage_mappings_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_stage_mappings_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT production_stage_mappings_source_field_check: CHECK (source_field = ANY (ARRAY['from_zone'::text, 'from_location'::text]))
CREATE UNIQUE INDEX production_stage_mappings_organization_id_source_field_matc_key ON public.production_stage_mappings USING btree (organization_id, source_field, match_pattern);
CREATE UNIQUE INDEX production_stage_mappings_pkey ON public.production_stage_mappings USING btree (id);

-- BASE TABLE: public.production_stage_source_rules
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. production_stage_id uuid nullable=NO default=
--   4. source_dataset text nullable=NO default=
--   5. source_field text nullable=NO default=
--   6. match_type text nullable=NO default=
--   7. match_value text nullable=NO default=
--   8. priority integer nullable=NO default=100
--   9. validation_status text nullable=NO default='VALIDATED'::text
--   10. active boolean nullable=NO default=true
--   11. created_at timestamp with time zone nullable=NO default=now()
--   12. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT production_stage_source_rules_match_type_check: CHECK (match_type = ANY (ARRAY['exact'::text, 'contains'::text, 'starts_with'::text, 'ends_with'::text, 'regex'::text]))
--   CONSTRAINT production_stage_source_rules_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT production_stage_source_rules_pkey: PRIMARY KEY (id)
--   CONSTRAINT production_stage_source_rules_production_stage_id_fkey: FOREIGN KEY (production_stage_id) REFERENCES production_process_stages(id)
--   CONSTRAINT production_stage_source_rules_validation_status_check: CHECK (validation_status = ANY (ARRAY['VALIDATED'::text, 'REQUIRES_VALIDATION'::text]))
CREATE UNIQUE INDEX production_stage_source_rules_pkey ON public.production_stage_source_rules USING btree (id);

-- BASE TABLE: public.quantity_conversion_rules
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. product_group_pattern text nullable=NO default='%'::text
--   4. multiplier numeric nullable=NO default=1
--   5. priority integer nullable=NO default=100
--   6. active boolean nullable=NO default=true
--   7. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT quantity_conversion_rules_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT quantity_conversion_rules_organization_id_product_group_pat_key: UNIQUE (organization_id, product_group_pattern)
--   CONSTRAINT quantity_conversion_rules_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX quantity_conversion_rules_organization_id_product_group_pat_key ON public.quantity_conversion_rules USING btree (organization_id, product_group_pattern);
CREATE UNIQUE INDEX quantity_conversion_rules_pkey ON public.quantity_conversion_rules USING btree (id);

-- BASE TABLE: public.resource_capacity_rules
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. process text nullable=NO default=
--   4. resource_code text nullable=NO default=
--   5. shift_code text nullable=YES default=
--   6. max_resources numeric nullable=NO default=
--   7. condition_context jsonb nullable=NO default='{}'::jsonb
--   8. effective_from date nullable=NO default=
--   9. effective_to date nullable=YES default=
--   10. active boolean nullable=NO default=true
--   11. calculation_version text nullable=NO default='ERP_KPI_V1'::text
--   CONSTRAINT resource_capacity_rules_check: CHECK (effective_to IS NULL OR effective_to >= effective_from)
--   CONSTRAINT resource_capacity_rules_max_resources_check: CHECK (max_resources >= 0::numeric)
--   CONSTRAINT resource_capacity_rules_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT resource_capacity_rules_organization_id_resource_code_shift_key: UNIQUE (organization_id, resource_code, shift_code, effective_from)
--   CONSTRAINT resource_capacity_rules_pkey: PRIMARY KEY (id)
--   CONSTRAINT resource_capacity_rules_process_check: CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text]))
--   CONSTRAINT resource_capacity_rules_shift_code_check: CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text]))
CREATE INDEX resource_capacity_rules_lookup_idx ON public.resource_capacity_rules USING btree (organization_id, process, resource_code, effective_from, effective_to) WHERE active;
CREATE UNIQUE INDEX resource_capacity_rules_organization_id_resource_code_shift_key ON public.resource_capacity_rules USING btree (organization_id, resource_code, shift_code, effective_from);
CREATE UNIQUE INDEX resource_capacity_rules_pkey ON public.resource_capacity_rules USING btree (id);

-- BASE TABLE: public.screen_print_jobs
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. order_no text nullable=YES default=
--   4. job_name text nullable=NO default=
--   5. customer_name text nullable=YES default=
--   6. planned_quantity numeric nullable=NO default=
--   7. completed_quantity numeric nullable=NO default=0
--   8. status text nullable=NO default='todo'::text
--   9. planned_date date nullable=YES default=
--   10. shift_code text nullable=YES default=
--   11. line_name text nullable=YES default=
--   12. started_at timestamp with time zone nullable=YES default=
--   13. completed_at timestamp with time zone nullable=YES default=
--   14. priority integer nullable=YES default=
--   15. notes text nullable=YES default=
--   16. created_by uuid nullable=YES default=
--   17. updated_by uuid nullable=YES default=
--   18. created_at timestamp with time zone nullable=NO default=now()
--   19. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT screen_print_jobs_check: CHECK (completed_quantity <= planned_quantity)
--   CONSTRAINT screen_print_jobs_completed_quantity_check: CHECK (completed_quantity >= 0::numeric)
--   CONSTRAINT screen_print_jobs_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT screen_print_jobs_pkey: PRIMARY KEY (id)
--   CONSTRAINT screen_print_jobs_planned_quantity_check: CHECK (planned_quantity >= 0::numeric)
--   CONSTRAINT screen_print_jobs_status_check: CHECK (status = ANY (ARRAY['todo'::text, 'in_production'::text, 'completed'::text, 'cancelled'::text]))
CREATE INDEX screen_print_jobs_org_status_idx ON public.screen_print_jobs USING btree (organization_id, status, planned_date);
CREATE UNIQUE INDEX screen_print_jobs_pkey ON public.screen_print_jobs USING btree (id);

-- BASE TABLE: public.shift_rules
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. weekday smallint nullable=NO default=
--   4. shift_code text nullable=NO default=
--   5. display_name text nullable=NO default=
--   6. start_time time without time zone nullable=NO default=
--   7. end_time time without time zone nullable=NO default=
--   8. cross_midnight boolean nullable=NO default=false
--   9. tolerance_minutes integer nullable=NO default=20
--   10. activation_confirmation_minutes integer nullable=NO default=150
--   11. active boolean nullable=NO default=true
--   12. effective_from date nullable=NO default=
--   13. effective_to date nullable=YES default=
--   CONSTRAINT shift_rules_activation_confirmation_minutes_check: CHECK (activation_confirmation_minutes >= 0 AND activation_confirmation_minutes <= 720)
--   CONSTRAINT shift_rules_check: CHECK (effective_to IS NULL OR effective_to >= effective_from)
--   CONSTRAINT shift_rules_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT shift_rules_organization_id_weekday_shift_code_effective_fr_key: UNIQUE (organization_id, weekday, shift_code, effective_from)
--   CONSTRAINT shift_rules_pkey: PRIMARY KEY (id)
--   CONSTRAINT shift_rules_shift_code_check: CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text]))
--   CONSTRAINT shift_rules_tolerance_minutes_check: CHECK (tolerance_minutes >= 0 AND tolerance_minutes <= 180)
--   CONSTRAINT shift_rules_weekday_check: CHECK (weekday >= 1 AND weekday <= 7)
CREATE INDEX shift_rules_lookup_idx ON public.shift_rules USING btree (organization_id, weekday, effective_from, effective_to) WHERE active;
CREATE UNIQUE INDEX shift_rules_organization_id_weekday_shift_code_effective_fr_key ON public.shift_rules USING btree (organization_id, weekday, shift_code, effective_from);
CREATE UNIQUE INDEX shift_rules_pkey ON public.shift_rules USING btree (id);

-- BASE TABLE: public.shift_templates
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. starts_at time without time zone nullable=NO default=
--   5. ends_at time without time zone nullable=NO default=
--   6. active boolean nullable=NO default=true
--   7. created_at timestamp with time zone nullable=NO default=now()
--   8. day_group text nullable=NO default='all_days'::text
--   9. crosses_midnight boolean nullable=NO default=false
--   10. scheduled_hours numeric nullable=NO default=
--   CONSTRAINT shift_scheduled_hours_positive: CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)
--   CONSTRAINT shift_templates_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT shift_templates_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT shift_templates_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX shift_templates_organization_id_name_key ON public.shift_templates USING btree (organization_id, name);
CREATE UNIQUE INDEX shift_templates_pkey ON public.shift_templates USING btree (id);

-- BASE TABLE: public.source_audit_events
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. source_audit_id text nullable=YES default=
--   4. order_no text nullable=NO default=
--   5. username text nullable=YES default=
--   6. from_zone text nullable=YES default=
--   7. to_zone text nullable=YES default=
--   8. from_location text nullable=YES default=
--   9. to_location text nullable=YES default=
--   10. product text nullable=YES default=
--   11. from_pack_id text nullable=YES default=
--   12. to_pack_id text nullable=YES default=
--   13. source_qty numeric nullable=YES default=
--   14. source_weight numeric nullable=YES default=
--   15. production_units numeric nullable=NO default=
--   16. event_at timestamp with time zone nullable=NO default=
--   17. raw_hash text nullable=NO default=
--   18. imported_at timestamp with time zone nullable=NO default=now()
--   19. queue text nullable=YES default=
--   20. task text nullable=YES default=
--   CONSTRAINT source_audit_events_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT source_audit_events_organization_id_raw_hash_key: UNIQUE (organization_id, raw_hash)
--   CONSTRAINT source_audit_events_organization_id_source_audit_id_key: UNIQUE (organization_id, source_audit_id)
--   CONSTRAINT source_audit_events_pkey: PRIMARY KEY (id)
CREATE INDEX source_audit_event_idx ON public.source_audit_events USING btree (event_at);
CREATE INDEX source_audit_events_dtg_history_idx ON public.source_audit_events USING btree (order_no, from_zone, to_zone, event_at);
CREATE UNIQUE INDEX source_audit_events_organization_id_raw_hash_key ON public.source_audit_events USING btree (organization_id, raw_hash);
CREATE UNIQUE INDEX source_audit_events_organization_id_source_audit_id_key ON public.source_audit_events USING btree (organization_id, source_audit_id);
CREATE UNIQUE INDEX source_audit_events_pkey ON public.source_audit_events USING btree (id);
CREATE INDEX source_audit_from_location_idx ON public.source_audit_events USING btree (from_location);
CREATE INDEX source_audit_order_idx ON public.source_audit_events USING btree (order_no);
CREATE INDEX source_audit_to_location_idx ON public.source_audit_events USING btree (to_location);

-- BASE TABLE: public.source_orders
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. sync_batch_id uuid nullable=NO default=
--   4. order_no text nullable=NO default=
--   5. date_received timestamp with time zone nullable=YES default=
--   6. date_due timestamp with time zone nullable=YES default=
--   7. date_released timestamp with time zone nullable=YES default=
--   8. source_status text nullable=YES default=
--   9. source_sub_status text nullable=YES default=
--   10. customer_code text nullable=YES default=
--   11. customer_name text nullable=YES default=
--   12. ship_to_name text nullable=YES default=
--   13. customer_state text nullable=YES default=
--   14. city text nullable=YES default=
--   15. delivery_desc text nullable=YES default=
--   16. client_so_number text nullable=YES default=
--   17. source_priority integer nullable=YES default=
--   18. source_updated_at timestamp with time zone nullable=YES default=
--   19. created_at timestamp with time zone nullable=NO default=now()
--   20. site text nullable=YES default=
--   21. route_id text nullable=YES default=
--   22. cost_centre text nullable=YES default=
--   23. stop_ship_flag text nullable=YES default=
--   24. release_source_status text nullable=YES default=
--   CONSTRAINT source_orders_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT source_orders_pkey: PRIMARY KEY (id)
--   CONSTRAINT source_orders_sync_batch_id_fkey: FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)
--   CONSTRAINT source_orders_sync_batch_id_order_no_key: UNIQUE (sync_batch_id, order_no)
CREATE INDEX source_orders_order_no_idx ON public.source_orders USING btree (order_no);
CREATE UNIQUE INDEX source_orders_pkey ON public.source_orders USING btree (id);
CREATE INDEX source_orders_site_idx ON public.source_orders USING btree (site);
CREATE UNIQUE INDEX source_orders_sync_batch_id_order_no_key ON public.source_orders USING btree (sync_batch_id, order_no);

-- BASE TABLE: public.source_release_order_lines
--   1. id bigint nullable=NO default=
--   2. organization_id uuid nullable=NO default=
--   3. sync_batch_id uuid nullable=NO default=
--   4. order_no text nullable=NO default=
--   5. line_number text nullable=NO default=
--   6. product text nullable=YES default=
--   7. client text nullable=YES default=
--   8. qty_lcd numeric nullable=NO default=0
--   9. orig_ref3 text nullable=YES default=
--   10. group_code text nullable=YES default=
--   11. product_name text nullable=YES default=
--   12. source_updated_at timestamp with time zone nullable=YES default=
--   13. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT source_release_order_lines_pkey: PRIMARY KEY (id)
--   CONSTRAINT source_release_order_lines_sync_batch_id_fkey: FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id) ON DELETE CASCADE
--   CONSTRAINT source_release_order_lines_sync_batch_id_order_no_line_numb_key: UNIQUE (sync_batch_id, order_no, line_number)
CREATE INDEX source_release_lines_order_idx ON public.source_release_order_lines USING btree (organization_id, order_no);
CREATE UNIQUE INDEX source_release_order_lines_pkey ON public.source_release_order_lines USING btree (id);
CREATE UNIQUE INDEX source_release_order_lines_sync_batch_id_order_no_line_numb_key ON public.source_release_order_lines USING btree (sync_batch_id, order_no, line_number);

-- BASE TABLE: public.source_stock_items
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. sync_batch_id uuid nullable=NO default=
--   4. product text nullable=NO default=
--   5. pack_id text nullable=NO default=
--   6. location text nullable=NO default=
--   7. source_timestamp timestamp with time zone nullable=YES default=
--   8. source_qty numeric nullable=YES default=
--   9. source_weight numeric nullable=YES default=
--   10. production_units numeric nullable=NO default=
--   11. created_at timestamp with time zone nullable=NO default=now()
--   12. source_zone text nullable=YES default=
--   CONSTRAINT source_stock_items_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT source_stock_items_pkey: PRIMARY KEY (id)
--   CONSTRAINT source_stock_items_sync_batch_id_fkey: FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)
CREATE INDEX source_stock_batch_location_idx ON public.source_stock_items USING btree (sync_batch_id, location);
CREATE UNIQUE INDEX source_stock_items_pkey ON public.source_stock_items USING btree (id);
CREATE INDEX source_stock_location_idx ON public.source_stock_items USING btree (location);
CREATE INDEX source_stock_pack_idx ON public.source_stock_items USING btree (pack_id);
CREATE INDEX source_stock_product_idx ON public.source_stock_items USING btree (product);
CREATE INDEX source_stock_zone_idx ON public.source_stock_items USING btree (source_zone);

-- BASE TABLE: public.source_workbank_items
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. sync_batch_id uuid nullable=NO default=
--   4. source_row_id text nullable=YES default=
--   5. order_no text nullable=NO default=
--   6. customer_code text nullable=YES default=
--   7. customer_name text nullable=YES default=
--   8. source_due_at timestamp with time zone nullable=YES default=
--   9. from_location text nullable=YES default=
--   10. from_zone text nullable=YES default=
--   11. to_location text nullable=YES default=
--   12. from_pack_id text nullable=YES default=
--   13. to_pack_id text nullable=YES default=
--   14. source_priority integer nullable=YES default=
--   15. product_code text nullable=YES default=
--   16. product_description text nullable=YES default=
--   17. product_group text nullable=YES default=
--   18. source_qty numeric nullable=YES default=
--   19. source_weight numeric nullable=YES default=
--   20. production_units numeric nullable=NO default=
--   21. queue text nullable=NO default=
--   22. task text nullable=YES default=
--   23. created_at timestamp with time zone nullable=NO default=now()
--   24. prints_per_garment numeric nullable=YES default=
--   CONSTRAINT source_workbank_items_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT source_workbank_items_pkey: PRIMARY KEY (id)
--   CONSTRAINT source_workbank_items_sync_batch_id_fkey: FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)
CREATE INDEX source_workbank_batch_zone_idx ON public.source_workbank_items USING btree (sync_batch_id, from_zone);
CREATE UNIQUE INDEX source_workbank_items_pkey ON public.source_workbank_items USING btree (id);
CREATE INDEX source_workbank_location_idx ON public.source_workbank_items USING btree (from_location);
CREATE INDEX source_workbank_order_no_idx ON public.source_workbank_items USING btree (order_no);
CREATE INDEX source_workbank_zone_idx ON public.source_workbank_items USING btree (from_zone);

-- BASE TABLE: public.staffing_layout_lines
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. staffing_layout_id uuid nullable=NO default=
--   3. production_area_id uuid nullable=NO default=
--   4. shift_template_id uuid nullable=NO default=
--   5. day_of_week smallint nullable=YES default=
--   6. operator_count numeric nullable=NO default=
--   7. machine_count numeric nullable=YES default=
--   8. scheduled_hours numeric nullable=NO default=
--   9. hourly_rate numeric nullable=YES default=
--   10. efficiency numeric nullable=YES default=
--   11. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT staffing_layout_lines_day_of_week_check: CHECK (day_of_week >= 1 AND day_of_week <= 7)
--   CONSTRAINT staffing_layout_lines_efficiency_check: CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)
--   CONSTRAINT staffing_layout_lines_hourly_rate_check: CHECK (hourly_rate >= 0::numeric)
--   CONSTRAINT staffing_layout_lines_machine_count_check: CHECK (machine_count >= 0::numeric)
--   CONSTRAINT staffing_layout_lines_operator_count_check: CHECK (operator_count >= 0::numeric)
--   CONSTRAINT staffing_layout_lines_pkey: PRIMARY KEY (id)
--   CONSTRAINT staffing_layout_lines_production_area_id_fkey: FOREIGN KEY (production_area_id) REFERENCES production_areas(id)
--   CONSTRAINT staffing_layout_lines_scheduled_hours_check: CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)
--   CONSTRAINT staffing_layout_lines_shift_template_id_fkey: FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)
--   CONSTRAINT staffing_layout_lines_staffing_layout_id_fkey: FOREIGN KEY (staffing_layout_id) REFERENCES staffing_layouts(id) ON DELETE CASCADE
CREATE UNIQUE INDEX staffing_layout_line_context ON public.staffing_layout_lines USING btree (staffing_layout_id, production_area_id, shift_template_id, COALESCE((day_of_week)::integer, 0));
CREATE UNIQUE INDEX staffing_layout_lines_pkey ON public.staffing_layout_lines USING btree (id);

-- BASE TABLE: public.staffing_layouts
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. name text nullable=NO default=
--   4. effective_from date nullable=NO default=CURRENT_DATE
--   5. effective_to date nullable=YES default=
--   6. active boolean nullable=NO default=false
--   7. source text nullable=NO default='USER'::text
--   8. created_at timestamp with time zone nullable=NO default=now()
--   9. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT staffing_layouts_check: CHECK (effective_to IS NULL OR effective_to >= effective_from)
--   CONSTRAINT staffing_layouts_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT staffing_layouts_organization_id_name_key: UNIQUE (organization_id, name)
--   CONSTRAINT staffing_layouts_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX staffing_layouts_organization_id_name_key ON public.staffing_layouts USING btree (organization_id, name);
CREATE UNIQUE INDEX staffing_layouts_pkey ON public.staffing_layouts USING btree (id);

-- BASE TABLE: public.sync_agent_heartbeat
--   1. organization_id uuid nullable=NO default=
--   2. agent_id text nullable=NO default=
--   3. last_seen_at timestamp with time zone nullable=NO default=now()
--   4. version text nullable=NO default=
--   5. hostname text nullable=YES default=
--   6. status text nullable=NO default=
--   7. last_error text nullable=YES default=
--   8. last_sync_attempt_at timestamp with time zone nullable=YES default=
--   9. last_success_at timestamp with time zone nullable=YES default=
--   10. next_expected_sync_at timestamp with time zone nullable=YES default=
--   11. current_run_id uuid nullable=YES default=
--   CONSTRAINT sync_agent_heartbeat_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT sync_agent_heartbeat_pkey: PRIMARY KEY (organization_id, agent_id)
CREATE UNIQUE INDEX sync_agent_heartbeat_pkey ON public.sync_agent_heartbeat USING btree (organization_id, agent_id);

-- BASE TABLE: public.sync_batches
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. started_at timestamp with time zone nullable=NO default=now()
--   4. completed_at timestamp with time zone nullable=YES default=
--   5. status text nullable=NO default=
--   6. orders_count integer nullable=NO default=0
--   7. workbank_count integer nullable=NO default=0
--   8. stock_count integer nullable=NO default=0
--   9. audit_new_count integer nullable=NO default=0
--   10. error_message text nullable=YES default=
--   11. connector_version text nullable=YES default=
--   12. created_at timestamp with time zone nullable=NO default=now()
--   13. release_line_count integer nullable=NO default=0
--   CONSTRAINT sync_batches_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT sync_batches_pkey: PRIMARY KEY (id)
--   CONSTRAINT sync_batches_status_check: CHECK (status = ANY (ARRAY['running'::text, 'completed'::text, 'failed'::text]))
CREATE UNIQUE INDEX sync_batches_pkey ON public.sync_batches USING btree (id);

-- BASE TABLE: public.sync_refresh_requests
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. requested_by uuid nullable=YES default=
--   4. status text nullable=NO default='QUEUED'::text
--   5. requested_at timestamp with time zone nullable=NO default=now()
--   6. started_at timestamp with time zone nullable=YES default=
--   7. completed_at timestamp with time zone nullable=YES default=
--   8. sync_run_id uuid nullable=YES default=
--   9. failure_reason text nullable=YES default=
--   CONSTRAINT sync_refresh_requests_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT sync_refresh_requests_pkey: PRIMARY KEY (id)
--   CONSTRAINT sync_refresh_requests_status_check: CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text]))
--   CONSTRAINT sync_refresh_requests_sync_run_id_fkey: FOREIGN KEY (sync_run_id) REFERENCES sync_runs(id)
CREATE UNIQUE INDEX sync_refresh_one_active_idx ON public.sync_refresh_requests USING btree (organization_id) WHERE (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text]));
CREATE UNIQUE INDEX sync_refresh_requests_pkey ON public.sync_refresh_requests USING btree (id);

-- BASE TABLE: public.sync_runs
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. organization_id uuid nullable=NO default=
--   3. refresh_request_id uuid nullable=YES default=
--   4. trigger_type text nullable=NO default=
--   5. status text nullable=NO default=
--   6. requested_at timestamp with time zone nullable=NO default=now()
--   7. started_at timestamp with time zone nullable=YES default=
--   8. completed_at timestamp with time zone nullable=YES default=
--   9. duration_ms bigint nullable=YES default=
--   10. agent_id text nullable=YES default=
--   11. connector_version text nullable=YES default=
--   12. batch_id uuid nullable=YES default=
--   13. orders_count integer nullable=NO default=0
--   14. workbank_count integer nullable=NO default=0
--   15. stock_count integer nullable=NO default=0
--   16. audit_count integer nullable=NO default=0
--   17. failure_reason text nullable=YES default=
--   18. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT sync_runs_organization_id_fkey: FOREIGN KEY (organization_id) REFERENCES organizations(id)
--   CONSTRAINT sync_runs_pkey: PRIMARY KEY (id)
--   CONSTRAINT sync_runs_refresh_request_id_fkey: FOREIGN KEY (refresh_request_id) REFERENCES sync_refresh_requests(id)
--   CONSTRAINT sync_runs_status_check: CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text]))
--   CONSTRAINT sync_runs_trigger_type_check: CHECK (trigger_type = ANY (ARRAY['AUTOMATIC'::text, 'MANUAL'::text]))
CREATE UNIQUE INDEX sync_runs_pkey ON public.sync_runs USING btree (id);
CREATE INDEX sync_runs_recent_idx ON public.sync_runs USING btree (organization_id, requested_at DESC);

-- VIEW: public.v_capacity_load
--   1. organization_id uuid nullable=YES default=
--   2. area_code text nullable=YES default=
--   3. demand_units numeric nullable=YES default=
--   4. daily_capacity numeric nullable=YES default=
--   5. weekly_capacity numeric nullable=YES default=
--   6. load_percent numeric nullable=YES default=
--   7. capacity_gap numeric nullable=YES default=
--   8. relative_lead_days numeric nullable=YES default=

-- VIEW: public.v_current_labour_segments
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. import_batch_id uuid nullable=YES default=
--   4. source_timesheet_row_id uuid nullable=YES default=
--   5. person_key text nullable=YES default=
--   6. area_code text nullable=YES default=
--   7. segment_start timestamp with time zone nullable=YES default=
--   8. segment_end timestamp with time zone nullable=YES default=
--   9. calendar_date date nullable=YES default=
--   10. operational_date date nullable=YES default=
--   11. hour_bucket smallint nullable=YES default=
--   12. shift_code text nullable=YES default=
--   13. paid_hours numeric nullable=YES default=
--   14. regular_hours numeric nullable=YES default=
--   15. overtime_hours numeric nullable=YES default=
--   16. paid_break_hours numeric nullable=YES default=
--   17. productive_hours numeric nullable=YES default=
--   18. approval_status text nullable=YES default=
--   19. allocation_method text nullable=YES default=
--   20. week_start date nullable=YES default=
--   21. calculation_version text nullable=YES default=
--   22. created_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_current_orders
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. order_no text nullable=YES default=
--   5. date_received timestamp with time zone nullable=YES default=
--   6. date_due timestamp with time zone nullable=YES default=
--   7. date_released timestamp with time zone nullable=YES default=
--   8. source_status text nullable=YES default=
--   9. source_sub_status text nullable=YES default=
--   10. customer_code text nullable=YES default=
--   11. customer_name text nullable=YES default=
--   12. ship_to_name text nullable=YES default=
--   13. customer_state text nullable=YES default=
--   14. city text nullable=YES default=
--   15. delivery_desc text nullable=YES default=
--   16. client_so_number text nullable=YES default=
--   17. source_priority integer nullable=YES default=
--   18. source_updated_at timestamp with time zone nullable=YES default=
--   19. created_at timestamp with time zone nullable=YES default=
--   20. site text nullable=YES default=
--   21. route_id text nullable=YES default=
--   22. cost_centre text nullable=YES default=
--   23. stop_ship_flag text nullable=YES default=
--   24. release_source_status text nullable=YES default=

-- VIEW: public.v_current_release_order_lines
--   1. id bigint nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. order_no text nullable=YES default=
--   5. line_number text nullable=YES default=
--   6. product text nullable=YES default=
--   7. client text nullable=YES default=
--   8. qty_lcd numeric nullable=YES default=
--   9. orig_ref3 text nullable=YES default=
--   10. group_code text nullable=YES default=
--   11. product_name text nullable=YES default=
--   12. source_updated_at timestamp with time zone nullable=YES default=
--   13. created_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_current_stock
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. product text nullable=YES default=
--   5. pack_id text nullable=YES default=
--   6. location text nullable=YES default=
--   7. source_timestamp timestamp with time zone nullable=YES default=
--   8. source_qty numeric nullable=YES default=
--   9. source_weight numeric nullable=YES default=
--   10. production_units numeric nullable=YES default=
--   11. created_at timestamp with time zone nullable=YES default=
--   12. source_zone text nullable=YES default=

-- VIEW: public.v_current_workbank
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. source_row_id text nullable=YES default=
--   5. order_no text nullable=YES default=
--   6. customer_code text nullable=YES default=
--   7. customer_name text nullable=YES default=
--   8. source_due_at timestamp with time zone nullable=YES default=
--   9. from_location text nullable=YES default=
--   10. from_zone text nullable=YES default=
--   11. to_location text nullable=YES default=
--   12. from_pack_id text nullable=YES default=
--   13. to_pack_id text nullable=YES default=
--   14. source_priority integer nullable=YES default=
--   15. product_code text nullable=YES default=
--   16. product_description text nullable=YES default=
--   17. product_group text nullable=YES default=
--   18. source_qty numeric nullable=YES default=
--   19. source_weight numeric nullable=YES default=
--   20. production_units numeric nullable=YES default=
--   21. queue text nullable=YES default=
--   22. task text nullable=YES default=
--   23. created_at timestamp with time zone nullable=YES default=
--   24. prints_per_garment numeric nullable=YES default=

-- VIEW: public.v_daily_plans
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. production_date date nullable=YES default=
--   4. shift_template_id uuid nullable=YES default=
--   5. production_area_id uuid nullable=YES default=
--   6. status text nullable=YES default=
--   7. version integer nullable=YES default=
--   8. created_by uuid nullable=YES default=
--   9. published_by uuid nullable=YES default=
--   10. published_at timestamp with time zone nullable=YES default=
--   11. closed_by uuid nullable=YES default=
--   12. closed_at timestamp with time zone nullable=YES default=
--   13. created_at timestamp with time zone nullable=YES default=
--   14. updated_at timestamp with time zone nullable=YES default=
--   15. shift_name text nullable=YES default=
--   16. area_code text nullable=YES default=
--   17. area_name text nullable=YES default=
--   18. item_count bigint nullable=YES default=
--   19. planned_units numeric nullable=YES default=

-- VIEW: public.v_dtg_operational_orders
--   1. organization_id uuid nullable=YES default=
--   2. order_no text nullable=YES default=
--   3. customer_name text nullable=YES default=
--   4. screen text nullable=YES default=
--   5. status text nullable=YES default=
--   6. priority integer nullable=YES default=
--   7. date_due timestamp with time zone nullable=YES default=
--   8. age_days integer nullable=YES default=
--   9. item_count bigint nullable=YES default=
--   10. remaining_units numeric nullable=YES default=
--   11. last_movement timestamp with time zone nullable=YES default=
--   12. putwall_locations text nullable=YES default=
--   13. progress_label text nullable=YES default=
--   14. total_prints numeric nullable=YES default=
--   15. adult_prints numeric nullable=YES default=
--   16. kids_prints numeric nullable=YES default=
--   17. unclassified_prints numeric nullable=YES default=

-- VIEW: public.v_dtg_order_history
--   1. order_no text nullable=YES default=
--   2. printed bigint nullable=YES default=
--   3. first_pick timestamp with time zone nullable=YES default=
--   4. first_print timestamp with time zone nullable=YES default=
--   5. last_print timestamp with time zone nullable=YES default=

-- VIEW: public.v_kpi_dashboard
--   1. definition_id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. code text nullable=YES default=
--   4. name text nullable=YES default=
--   5. category text nullable=YES default=
--   6. unit text nullable=YES default=
--   7. data_readiness_status text nullable=YES default=
--   8. dashboard_priority integer nullable=YES default=
--   9. value numeric nullable=YES default=
--   10. numerator numeric nullable=YES default=
--   11. denominator numeric nullable=YES default=
--   12. status text nullable=YES default=
--   13. data_quality_status text nullable=YES default=
--   14. production_area_id uuid nullable=YES default=
--   15. area_code text nullable=YES default=
--   16. source_refresh_at timestamp with time zone nullable=YES default=
--   17. calculated_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_kpi_trends
--   1. organization_id uuid nullable=YES default=
--   2. kpi_definition_id uuid nullable=YES default=
--   3. production_area_id uuid nullable=YES default=
--   4. period_type text nullable=YES default=
--   5. period_start date nullable=YES default=
--   6. period_end date nullable=YES default=
--   7. points bigint nullable=YES default=
--   8. latest_value numeric nullable=YES default=
--   9. average_value numeric nullable=YES default=
--   10. minimum_value numeric nullable=YES default=
--   11. maximum_value numeric nullable=YES default=
--   12. previous_value numeric nullable=YES default=
--   13. absolute_change numeric nullable=YES default=
--   14. percentage_change numeric nullable=YES default=

-- VIEW: public.v_latest_completed_batch
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. started_at timestamp with time zone nullable=YES default=
--   4. completed_at timestamp with time zone nullable=YES default=
--   5. status text nullable=YES default=
--   6. orders_count integer nullable=YES default=
--   7. workbank_count integer nullable=YES default=
--   8. stock_count integer nullable=YES default=
--   9. audit_new_count integer nullable=YES default=
--   10. error_message text nullable=YES default=
--   11. connector_version text nullable=YES default=
--   12. created_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_machine_load_not_approved
--   1. organization_id uuid nullable=YES default=
--   2. sync_batch_id uuid nullable=YES default=
--   3. order_no text nullable=YES default=
--   4. line_number text nullable=YES default=
--   5. product text nullable=YES default=
--   6. client text nullable=YES default=
--   7. product_name text nullable=YES default=
--   8. source_process_code text nullable=YES default=
--   9. process_quantity numeric nullable=YES default=
--   10. quantity_semantics text nullable=YES default=
--   11. customer_name text nullable=YES default=
--   12. date_due timestamp with time zone nullable=YES default=
--   13. source_priority integer nullable=YES default=
--   14. site text nullable=YES default=
--   15. release_route_evidence text nullable=YES default=
--   16. routing_id uuid nullable=YES default=
--   17. routing_code text nullable=YES default=
--   18. routing_revision integer nullable=YES default=
--   19. machine_group text nullable=YES default=
--   20. process text nullable=YES default=
--   21. machine_load_bucket text nullable=YES default=
--   22. routing_resolution text nullable=YES default=
--   23. release_status text nullable=YES default=
--   24. release_blockers ARRAY nullable=YES default=
--   25. snapshot_completed_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_order_stage_summary
--   1. organization_id uuid nullable=YES default=
--   2. order_no text nullable=YES default=
--   3. customer_name text nullable=YES default=
--   4. due_at timestamp with time zone nullable=YES default=
--   5. stage_code text nullable=YES default=
--   6. stage_name text nullable=YES default=
--   7. item_count bigint nullable=YES default=
--   8. production_units numeric nullable=YES default=
--   9. age_days integer nullable=YES default=

-- VIEW: public.v_production_planning
--   1. organization_id uuid nullable=YES default=
--   2. order_no text nullable=YES default=
--   3. line text nullable=YES default=
--   4. customer_name text nullable=YES default=
--   5. screen text nullable=YES default=
--   6. source_status text nullable=YES default=
--   7. source_priority integer nullable=YES default=
--   8. age_days integer nullable=YES default=
--   9. remaining_units numeric nullable=YES default=
--   10. total_prints numeric nullable=YES default=
--   11. production_order_id uuid nullable=YES default=
--   12. planner_priority integer nullable=YES default=
--   13. effective_priority integer nullable=YES default=
--   14. planned_date date nullable=YES default=
--   15. planned_shift_id uuid nullable=YES default=
--   16. planned_shift text nullable=YES default=
--   17. planning_status text nullable=YES default=
--   18. special_instruction text nullable=YES default=
--   19. planner_note text nullable=YES default=
--   20. blocked_reason text nullable=YES default=
--   21. updated_at timestamp with time zone nullable=YES default=

-- VIEW: public.v_release_queue
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. order_no text nullable=YES default=
--   5. date_received timestamp with time zone nullable=YES default=
--   6. date_due timestamp with time zone nullable=YES default=
--   7. date_released timestamp with time zone nullable=YES default=
--   8. source_status text nullable=YES default=
--   9. source_sub_status text nullable=YES default=
--   10. customer_code text nullable=YES default=
--   11. customer_name text nullable=YES default=
--   12. ship_to_name text nullable=YES default=
--   13. customer_state text nullable=YES default=
--   14. city text nullable=YES default=
--   15. delivery_desc text nullable=YES default=
--   16. client_so_number text nullable=YES default=
--   17. source_priority integer nullable=YES default=
--   18. source_updated_at timestamp with time zone nullable=YES default=
--   19. created_at timestamp with time zone nullable=YES default=
--   20. site text nullable=YES default=
--   21. route_id text nullable=YES default=
--   22. cost_centre text nullable=YES default=
--   23. stop_ship_flag text nullable=YES default=
--   24. release_source_status text nullable=YES default=
--   25. snapshot_completed_at timestamp with time zone nullable=YES default=
--   26. dtg_qty numeric nullable=YES default=
--   27. underprint_qty numeric nullable=YES default=
--   28. uv_qty numeric nullable=YES default=
--   29. hats_qty numeric nullable=YES default=
--   30. finished_qty numeric nullable=YES default=
--   31. stickers_qty numeric nullable=YES default=
--   32. visual_qty numeric nullable=YES default=
--   33. production_qty numeric nullable=YES default=
--   34. custom_emb_qty numeric nullable=YES default=
--   35. eyewear_qty numeric nullable=YES default=
--   36. total_process_qty numeric nullable=YES default=
--   37. release_blockers ARRAY nullable=YES default=
--   38. diagnostic_status text nullable=YES default=
--   39. release_status text nullable=YES default=

-- VIEW: public.v_release_queue_all
--   1. id uuid nullable=YES default=
--   2. organization_id uuid nullable=YES default=
--   3. sync_batch_id uuid nullable=YES default=
--   4. order_no text nullable=YES default=
--   5. date_received timestamp with time zone nullable=YES default=
--   6. date_due timestamp with time zone nullable=YES default=
--   7. date_released timestamp with time zone nullable=YES default=
--   8. source_status text nullable=YES default=
--   9. source_sub_status text nullable=YES default=
--   10. customer_code text nullable=YES default=
--   11. customer_name text nullable=YES default=
--   12. ship_to_name text nullable=YES default=
--   13. customer_state text nullable=YES default=
--   14. city text nullable=YES default=
--   15. delivery_desc text nullable=YES default=
--   16. client_so_number text nullable=YES default=
--   17. source_priority integer nullable=YES default=
--   18. source_updated_at timestamp with time zone nullable=YES default=
--   19. created_at timestamp with time zone nullable=YES default=
--   20. site text nullable=YES default=
--   21. route_id text nullable=YES default=
--   22. cost_centre text nullable=YES default=
--   23. stop_ship_flag text nullable=YES default=
--   24. release_source_status text nullable=YES default=
--   25. snapshot_completed_at timestamp with time zone nullable=YES default=
--   26. dtg_qty numeric nullable=YES default=
--   27. underprint_qty numeric nullable=YES default=
--   28. uv_qty numeric nullable=YES default=
--   29. hats_qty numeric nullable=YES default=
--   30. finished_qty numeric nullable=YES default=
--   31. stickers_qty numeric nullable=YES default=
--   32. visual_qty numeric nullable=YES default=
--   33. production_qty numeric nullable=YES default=
--   34. custom_emb_qty numeric nullable=YES default=
--   35. eyewear_qty numeric nullable=YES default=
--   36. total_process_qty numeric nullable=YES default=
--   37. release_blockers ARRAY nullable=YES default=
--   38. diagnostic_status text nullable=YES default=
--   39. release_status text nullable=YES default=

-- VIEW: public.v_source_reconciliation
--   1. organization_id uuid nullable=YES default=
--   2. sync_batch_id uuid nullable=YES default=
--   3. completed_at timestamp with time zone nullable=YES default=
--   4. batch_orders integer nullable=YES default=
--   5. current_orders bigint nullable=YES default=
--   6. batch_workbank integer nullable=YES default=
--   7. current_workbank bigint nullable=YES default=
--   8. batch_stock integer nullable=YES default=
--   9. current_stock bigint nullable=YES default=
--   10. audit_new_count integer nullable=YES default=

-- VIEW: public.v_up_operational_orders
--   1. organization_id uuid nullable=YES default=
--   2. order_no text nullable=YES default=
--   3. customer_name text nullable=YES default=
--   4. screen text nullable=YES default=
--   5. status text nullable=YES default=
--   6. priority integer nullable=YES default=
--   7. date_due timestamp with time zone nullable=YES default=
--   8. age_days integer nullable=YES default=
--   9. item_count bigint nullable=YES default=
--   10. remaining_units numeric nullable=YES default=
--   11. last_movement timestamp with time zone nullable=YES default=
--   12. putwall_locations text nullable=YES default=
--   13. progress_label text nullable=YES default=
--   14. total_prints numeric nullable=YES default=
--   15. adult_prints numeric nullable=YES default=
--   16. kids_prints numeric nullable=YES default=
--   17. unclassified_prints numeric nullable=YES default=

-- VIEW: public.v_up_operator_daily_productivity
--   1. organization_id uuid nullable=YES default=
--   2. operational_date date nullable=YES default=
--   3. shift_code text nullable=YES default=
--   4. operator text nullable=YES default=
--   5. output numeric nullable=YES default=
--   6. pid bigint nullable=YES default=
--   7. hours numeric nullable=YES default=

-- BASE TABLE: storage.buckets
--   1. id text nullable=NO default=
--   2. name text nullable=NO default=
--   3. owner uuid nullable=YES default=
--   4. created_at timestamp with time zone nullable=YES default=now()
--   5. updated_at timestamp with time zone nullable=YES default=now()
--   6. public boolean nullable=YES default=false
--   7. avif_autodetection boolean nullable=YES default=false
--   8. file_size_limit bigint nullable=YES default=
--   9. allowed_mime_types ARRAY nullable=YES default=
--   10. owner_id text nullable=YES default=
--   11. type USER-DEFINED nullable=NO default='STANDARD'::storage.buckettype
--   12. versioning_status text nullable=NO default='DISABLED'::text
--   CONSTRAINT buckets_pkey: PRIMARY KEY (id)
--   CONSTRAINT buckets_versioning_dark_check: CHECK (versioning_status = 'DISABLED'::text)
--   CONSTRAINT buckets_versioning_standard_only_check: CHECK (type = 'STANDARD'::storage.buckettype OR versioning_status = 'DISABLED'::text)
--   CONSTRAINT buckets_versioning_status_check: CHECK (versioning_status = ANY (ARRAY['DISABLED'::text, 'ENABLED'::text, 'SUSPENDED'::text]))
CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);
CREATE UNIQUE INDEX buckets_pkey ON storage.buckets USING btree (id);

-- BASE TABLE: storage.buckets_analytics
--   1. name text nullable=NO default=
--   2. type USER-DEFINED nullable=NO default='ANALYTICS'::storage.buckettype
--   3. format text nullable=NO default='ICEBERG'::text
--   4. created_at timestamp with time zone nullable=NO default=now()
--   5. updated_at timestamp with time zone nullable=NO default=now()
--   6. id uuid nullable=NO default=gen_random_uuid()
--   7. deleted_at timestamp with time zone nullable=YES default=
--   CONSTRAINT buckets_analytics_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX buckets_analytics_pkey ON storage.buckets_analytics USING btree (id);
CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);

-- BASE TABLE: storage.buckets_vectors
--   1. id text nullable=NO default=
--   2. type USER-DEFINED nullable=NO default='VECTOR'::storage.buckettype
--   3. created_at timestamp with time zone nullable=NO default=now()
--   4. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT buckets_vectors_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX buckets_vectors_pkey ON storage.buckets_vectors USING btree (id);

-- BASE TABLE: storage.migrations
--   1. id integer nullable=NO default=
--   2. name character varying nullable=NO default=
--   3. hash character varying nullable=NO default=
--   4. executed_at timestamp without time zone nullable=YES default=CURRENT_TIMESTAMP
--   CONSTRAINT migrations_name_key: UNIQUE (name)
--   CONSTRAINT migrations_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX migrations_name_key ON storage.migrations USING btree (name);
CREATE UNIQUE INDEX migrations_pkey ON storage.migrations USING btree (id);

-- BASE TABLE: storage.objects
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. bucket_id text nullable=YES default=
--   3. name text nullable=YES default=
--   4. owner uuid nullable=YES default=
--   5. created_at timestamp with time zone nullable=YES default=now()
--   6. updated_at timestamp with time zone nullable=YES default=now()
--   7. last_accessed_at timestamp with time zone nullable=YES default=now()
--   8. metadata jsonb nullable=YES default=
--   9. path_tokens ARRAY nullable=YES default=
--   10. version text nullable=YES default=
--   11. owner_id text nullable=YES default=
--   12. user_metadata jsonb nullable=YES default=
--   13. archived_at timestamp with time zone nullable=YES default=
--   14. is_delete_marker boolean nullable=NO default=false
--   15. is_versioned boolean nullable=NO default=false
--   CONSTRAINT objects_bucketId_fkey: FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
--   CONSTRAINT objects_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);
CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");
CREATE INDEX idx_objects_bucket_id_name_lower ON storage.objects USING btree (bucket_id, lower(name) COLLATE "C");
CREATE UNIQUE INDEX idx_objects_current_version ON storage.objects USING btree (bucket_id, name COLLATE "C") WHERE (archived_at IS NULL);
CREATE UNIQUE INDEX idx_objects_null_version ON storage.objects USING btree (bucket_id, name COLLATE "C") WHERE (NOT is_versioned);
CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);
CREATE UNIQUE INDEX objects_bucket_id_name_version_key ON storage.objects USING btree (bucket_id, name COLLATE "C", version) NULLS NOT DISTINCT;
CREATE UNIQUE INDEX objects_pkey ON storage.objects USING btree (id);

-- BASE TABLE: storage.s3_multipart_uploads
--   1. id text nullable=NO default=
--   2. in_progress_size bigint nullable=NO default=0
--   3. upload_signature text nullable=NO default=
--   4. bucket_id text nullable=NO default=
--   5. key text nullable=NO default=
--   6. version text nullable=NO default=
--   7. owner_id text nullable=YES default=
--   8. created_at timestamp with time zone nullable=NO default=now()
--   9. user_metadata jsonb nullable=YES default=
--   10. metadata jsonb nullable=YES default=
--   CONSTRAINT s3_multipart_uploads_bucket_id_fkey: FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
--   CONSTRAINT s3_multipart_uploads_pkey: PRIMARY KEY (id)
CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);
CREATE UNIQUE INDEX s3_multipart_uploads_pkey ON storage.s3_multipart_uploads USING btree (id);

-- BASE TABLE: storage.s3_multipart_uploads_parts
--   1. id uuid nullable=NO default=gen_random_uuid()
--   2. upload_id text nullable=NO default=
--   3. size bigint nullable=NO default=0
--   4. part_number integer nullable=NO default=
--   5. bucket_id text nullable=NO default=
--   6. key text nullable=NO default=
--   7. etag text nullable=NO default=
--   8. owner_id text nullable=YES default=
--   9. version text nullable=NO default=
--   10. created_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey: FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
--   CONSTRAINT s3_multipart_uploads_parts_pkey: PRIMARY KEY (id)
--   CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey: FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE
CREATE UNIQUE INDEX s3_multipart_uploads_parts_pkey ON storage.s3_multipart_uploads_parts USING btree (id);

-- BASE TABLE: storage.vector_indexes
--   1. id text nullable=NO default=gen_random_uuid()
--   2. name text nullable=NO default=
--   3. bucket_id text nullable=NO default=
--   4. data_type text nullable=NO default=
--   5. dimension integer nullable=NO default=
--   6. distance_metric text nullable=NO default=
--   7. metadata_configuration jsonb nullable=YES default=
--   8. created_at timestamp with time zone nullable=NO default=now()
--   9. updated_at timestamp with time zone nullable=NO default=now()
--   CONSTRAINT vector_indexes_bucket_id_fkey: FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id)
--   CONSTRAINT vector_indexes_pkey: PRIMARY KEY (id)
CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);
CREATE UNIQUE INDEX vector_indexes_pkey ON storage.vector_indexes USING btree (id);

