-- public.active_wip_backfill_runs: enabled=True, forced=False
-- public.active_wip_coverage_exceptions: enabled=True, forced=False
-- public.capacity_legacy_overrides: enabled=True, forced=False
-- public.capacity_profiles: enabled=True, forced=False
-- public.capacity_scenario_lines: enabled=True, forced=False
-- public.capacity_scenarios: enabled=True, forced=False
-- public.deputy_area_mappings: enabled=True, forced=False
-- public.deputy_import_batches: enabled=True, forced=False
-- public.deputy_raw_timesheets: enabled=True, forced=False
-- public.e56_mo_pilot_exceptions: enabled=True, forced=False
-- public.e56_mo_pilot_orders: enabled=True, forced=False
-- public.e56_mo_pilot_runs: enabled=True, forced=False
-- public.e62_resolution_audit: enabled=True, forced=False
-- public.e63_process_resolution_audit: enabled=True, forced=False
-- public.e64_process_resolution_audit: enabled=True, forced=False
-- public.e6_backfill_batch_orders: enabled=True, forced=False
-- public.e6_backfill_batches: enabled=True, forced=False
-- public.e6_backfill_runs: enabled=True, forced=False
-- public.e6_scope_classifications: enabled=True, forced=False
-- public.kpi_definitions: enabled=True, forced=False
-- public.kpi_rate_rules: enabled=True, forced=False
-- public.kpi_results: enabled=True, forced=False
-- public.kpi_targets: enabled=True, forced=False
-- public.labour_segments: enabled=True, forced=False
-- public.maintenance_asset_categories: enabled=True, forced=False
-- public.maintenance_asset_code_sequences: enabled=True, forced=False
-- public.maintenance_asset_installations: enabled=True, forced=False
-- public.maintenance_asset_prefixes: enabled=True, forced=False
-- public.maintenance_assets: enabled=True, forced=False
-- public.maintenance_attachments: enabled=True, forced=False
-- public.maintenance_audit_log: enabled=True, forced=False
-- public.maintenance_component_code_sequences: enabled=True, forced=False
-- public.maintenance_component_prefixes: enabled=True, forced=False
-- public.maintenance_downtime_events: enabled=True, forced=False
-- public.maintenance_import_batches: enabled=True, forced=False
-- public.maintenance_import_staging: enabled=True, forced=False
-- public.maintenance_inventory_locations: enabled=True, forced=False
-- public.maintenance_inventory_transactions: enabled=True, forced=False
-- public.maintenance_members: enabled=True, forced=False
-- public.maintenance_parts: enabled=True, forced=False
-- public.maintenance_preventive_plan_tasks: enabled=True, forced=False
-- public.maintenance_preventive_plans: enabled=True, forced=False
-- public.maintenance_work_order_checklist: enabled=True, forced=False
-- public.maintenance_work_order_comments: enabled=True, forced=False
-- public.maintenance_work_order_history: enabled=True, forced=False
-- public.maintenance_work_order_labor: enabled=True, forced=False
-- public.maintenance_work_orders: enabled=True, forced=False
-- public.manufacturing_order_lines: enabled=True, forced=False
-- public.mo_backfill_pilot_orders: enabled=True, forced=False
-- public.operations: enabled=True, forced=False
-- public.oracle_line_ingestion_batches: enabled=True, forced=False
-- public.oracle_line_ingestion_runs: enabled=True, forced=False
-- public.oracle_line_ingestion_staging: enabled=True, forced=False
-- public.organizations: enabled=True, forced=False
-- public.product_families: enabled=True, forced=False
-- public.product_mapping_resolution_audit: enabled=True, forced=False
-- public.product_routing_assignments: enabled=True, forced=False
-- public.product_source_mappings: enabled=True, forced=False
-- public.product_types: enabled=True, forced=False
-- public.production_areas: enabled=True, forced=False
-- public.production_demand_exceptions: enabled=True, forced=False
-- public.production_demand_lines: enabled=True, forced=False
-- public.production_demand_release_events: enabled=True, forced=False
-- public.production_events: enabled=True, forced=False
-- public.production_order_history: enabled=True, forced=False
-- public.production_order_operation_evidence: enabled=True, forced=False
-- public.production_order_operations: enabled=True, forced=False
-- public.production_orders: enabled=True, forced=False
-- public.production_plan_history: enabled=True, forced=False
-- public.production_plan_items: enabled=True, forced=False
-- public.production_plans: enabled=True, forced=False
-- public.production_process_stages: enabled=True, forced=False
-- public.production_processes: enabled=True, forced=False
-- public.production_reconciliation_items: enabled=True, forced=False
-- public.production_reconciliation_runs: enabled=True, forced=False
-- public.production_resources: enabled=True, forced=False
-- public.production_routing_exceptions: enabled=True, forced=False
-- public.production_stage_mappings: enabled=True, forced=False
-- public.production_stage_source_rules: enabled=True, forced=False
-- public.products: enabled=True, forced=False
-- public.quantity_conversion_rules: enabled=True, forced=False
-- public.resource_capacity_rules: enabled=True, forced=False
-- public.routing_operations: enabled=True, forced=False
-- public.routings: enabled=True, forced=False
-- public.sales_order_release_history: enabled=True, forced=False
-- public.screen_print_jobs: enabled=True, forced=False
-- public.shift_rules: enabled=True, forced=False
-- public.shift_templates: enabled=True, forced=False
-- public.source_audit_events: enabled=True, forced=False
-- public.source_operation_mappings: enabled=True, forced=False
-- public.source_operational_code_mappings: enabled=True, forced=False
-- public.source_order_release_lines: enabled=True, forced=False
-- public.source_orders: enabled=True, forced=False
-- public.source_stock_items: enabled=True, forced=False
-- public.source_task_mappings: enabled=True, forced=False
-- public.source_workbank_items: enabled=True, forced=False
-- public.staffing_layout_lines: enabled=True, forced=False
-- public.staffing_layouts: enabled=True, forced=False
-- public.sync_agent_heartbeat: enabled=True, forced=False
-- public.sync_batches: enabled=True, forced=False
-- public.underprint_source_line_exceptions: enabled=True, forced=False
-- public.work_centers: enabled=True, forced=False
-- storage.buckets: enabled=True, forced=False
-- storage.buckets_analytics: enabled=True, forced=False
-- storage.buckets_vectors: enabled=True, forced=False
-- storage.migrations: enabled=True, forced=False
-- storage.objects: enabled=True, forced=False
-- storage.s3_multipart_uploads: enabled=True, forced=False
-- storage.s3_multipart_uploads_parts: enabled=True, forced=False
-- storage.vector_indexes: enabled=True, forced=False
-- POLICY public.active_wip_backfill_runs.active_wip_backfill_runs_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_backfill_runs.organization_id) AND m.active))), check=
-- POLICY public.active_wip_coverage_exceptions.active_wip_coverage_exceptions_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = active_wip_coverage_exceptions.organization_id) AND m.active))), check=
-- POLICY public.e56_mo_pilot_exceptions.e56_pilot_exceptions_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e56_mo_pilot_exceptions.organization_id) AND m.active))), check=
-- POLICY public.e56_mo_pilot_orders.e56_pilot_orders_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e56_mo_pilot_orders.organization_id) AND m.active))), check=
-- POLICY public.e56_mo_pilot_runs.e56_pilot_runs_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e56_mo_pilot_runs.organization_id) AND m.active))), check=
-- POLICY public.e62_resolution_audit.e62_resolution_audit_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e62_resolution_audit.organization_id) AND m.active))), check=
-- POLICY public.e63_process_resolution_audit.e63_resolution_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.organization_id = e63_process_resolution_audit.organization_id) AND (m.user_id = auth.uid()) AND m.active))), check=
-- POLICY public.e64_process_resolution_audit.e64_resolution_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.organization_id = e64_process_resolution_audit.organization_id) AND (m.user_id = auth.uid()) AND m.active))), check=
-- POLICY public.e6_backfill_batch_orders.e6_batch_orders_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM (e6_backfill_runs r
     JOIN maintenance_members m ON ((m.organization_id = r.organization_id)))
  WHERE ((r.id = e6_backfill_batch_orders.run_id) AND (m.user_id = auth.uid()) AND m.active))), check=
-- POLICY public.e6_backfill_batches.e6_batches_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM (e6_backfill_runs r
     JOIN maintenance_members m ON ((m.organization_id = r.organization_id)))
  WHERE ((r.id = e6_backfill_batches.run_id) AND (m.user_id = auth.uid()) AND m.active))), check=
-- POLICY public.e6_backfill_runs.e6_runs_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e6_backfill_runs.organization_id) AND m.active))), check=
-- POLICY public.e6_scope_classifications.e6_scope_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = e6_scope_classifications.organization_id) AND m.active))), check=
-- POLICY public.maintenance_members.maintenance_members_self_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(user_id = auth.uid()), check=
-- POLICY public.manufacturing_order_lines.manufacturing_order_lines_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.manufacturing_order_lines.manufacturing_order_lines_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = manufacturing_order_lines.organization_id) AND m.active))), check=
-- POLICY public.mo_backfill_pilot_orders.mo_backfill_pilot_orders_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = mo_backfill_pilot_orders.organization_id) AND m.active))), check=
-- POLICY public.operations.operations_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.operations.operations_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = operations.organization_id) AND m.active))), check=
-- POLICY public.oracle_line_ingestion_batches.oracle_line_batches_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = oracle_line_ingestion_batches.organization_id) AND m.active))), check=
-- POLICY public.oracle_line_ingestion_runs.oracle_line_runs_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = oracle_line_ingestion_runs.organization_id) AND m.active))), check=
-- POLICY public.product_families.product_families_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.product_families.product_families_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_families.organization_id) AND m.active))), check=
-- POLICY public.product_mapping_resolution_audit.product_mapping_resolution_audit_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_mapping_resolution_audit.organization_id) AND m.active))), check=
-- POLICY public.product_routing_assignments.product_routing_assignments_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.product_routing_assignments.product_routing_assignments_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_routing_assignments.organization_id) AND m.active))), check=
-- POLICY public.product_source_mappings.product_source_mappings_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.product_source_mappings.product_source_mappings_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_source_mappings.organization_id) AND m.active))), check=
-- POLICY public.product_types.product_types_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.product_types.product_types_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = product_types.organization_id) AND m.active))), check=
-- POLICY public.production_demand_exceptions.production_demand_exceptions_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_demand_exceptions.production_demand_exceptions_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_exceptions.organization_id) AND m.active))), check=
-- POLICY public.production_demand_lines.production_demand_lines_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_demand_lines.production_demand_lines_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_lines.organization_id) AND m.active))), check=
-- POLICY public.production_demand_release_events.production_demand_release_events_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_demand_release_events.organization_id) AND m.active))), check=
-- POLICY public.production_order_operation_evidence.production_order_operation_evidence_read: permissive=PERMISSIVE, roles={public}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operation_evidence.organization_id) AND m.active))), check=
-- POLICY public.production_order_operations.production_order_operations_execute: permissive=PERMISSIVE, roles={authenticated}, cmd=UPDATE, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text)))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = 'operator'::text))))
-- POLICY public.production_order_operations.production_order_operations_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_order_operations.production_order_operations_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_order_operations.organization_id) AND m.active))), check=
-- POLICY public.production_orders.production_orders_execution_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_orders.production_orders_execution_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_orders.organization_id) AND m.active))), check=
-- POLICY public.production_reconciliation_items.production_reconciliation_items_read: permissive=PERMISSIVE, roles={public}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_reconciliation_items.organization_id) AND m.active))), check=
-- POLICY public.production_reconciliation_runs.production_reconciliation_runs_read: permissive=PERMISSIVE, roles={public}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_reconciliation_runs.organization_id) AND m.active))), check=
-- POLICY public.production_resources.production_resources_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_resources.production_resources_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_resources.organization_id) AND m.active))), check=
-- POLICY public.production_routing_exceptions.production_routing_exceptions_manage: permissive=PERMISSIVE, roles={public}, cmd=UPDATE, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.production_routing_exceptions.production_routing_exceptions_read: permissive=PERMISSIVE, roles={public}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = production_routing_exceptions.organization_id) AND m.active))), check=
-- POLICY public.products.products_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.products.products_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = products.organization_id) AND m.active))), check=
-- POLICY public.routing_operations.routing_operations_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.routing_operations.routing_operations_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routing_operations.organization_id) AND m.active))), check=
-- POLICY public.routings.routings_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.routings.routings_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = routings.organization_id) AND m.active))), check=
-- POLICY public.sales_order_release_history.sales_order_release_history_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = sales_order_release_history.organization_id) AND m.active))), check=
-- POLICY public.source_operation_mappings.source_operation_mappings_manage: permissive=PERMISSIVE, roles={public}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.source_operation_mappings.source_operation_mappings_read: permissive=PERMISSIVE, roles={public}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_operation_mappings.organization_id) AND m.active))), check=
-- POLICY public.source_operational_code_mappings.source_operational_codes_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.organization_id = source_operational_code_mappings.organization_id) AND (m.user_id = auth.uid()) AND m.active))), check=
-- POLICY public.source_order_release_lines.source_order_release_lines_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_order_release_lines.organization_id) AND m.active))), check=
-- POLICY public.source_task_mappings.source_task_mappings_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.source_task_mappings.source_task_mappings_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = source_task_mappings.organization_id) AND m.active))), check=
-- POLICY public.underprint_source_line_exceptions.underprint_source_line_exceptions_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = underprint_source_line_exceptions.organization_id) AND m.active))), check=
-- POLICY public.work_centers.work_centers_manage: permissive=PERMISSIVE, roles={authenticated}, cmd=ALL, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text]))))), check=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active AND (m.role = ANY (ARRAY['admin'::text, 'supervisor'::text])))))
-- POLICY public.work_centers.work_centers_read: permissive=PERMISSIVE, roles={authenticated}, cmd=SELECT, using=(EXISTS ( SELECT 1
   FROM maintenance_members m
  WHERE ((m.user_id = auth.uid()) AND (m.organization_id = work_centers.organization_id) AND m.active))), check=
