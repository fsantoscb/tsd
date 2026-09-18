# Canonical V2 E5/E6 Support Objects

Direct runtime objects: 86
Transitive support objects: 87
Platform objects: 5
Legacy unused: 29
Unresolved SQL references: 0

## Dependency graph

| Object | Type | Parent(s) | Dependencies | SQL |
|---|---|---|---|---|
| `public.active_wip_backfill_runs` | TABLE | backfill_active_wip_manufacturing_orders | maintenance_members, organizations | `canonical-sql/support/active_wip_backfill_runs.sql` |
| `public.active_wip_coverage_exceptions` | TABLE | backfill_active_wip_manufacturing_orders, v_active_wip_mo_coverage | maintenance_members, organizations | `canonical-sql/support/active_wip_coverage_exceptions.sql` |
| `public.backfill_active_wip_manufacturing_orders` | FUNCTION | E5/E6_ROOT | active_wip_backfill_runs, active_wip_coverage_exceptions, create_manufacturing_orders, product_source_mappings, production_demand_exceptions, production_demand_lines, products, resolve_production_order_actual_state, routings, v_active_wip_mo_coverage, v_current_workbank | `canonical-sql/support/backfill_active_wip_manufacturing_orders.sql` |
| `public.canonical_mo_planned_quantity` | FUNCTION | E5/E6_ROOT, recalculate_manufacturing_order_quantity, reconcile_release_reactivations | manufacturing_order_lines, production_demand_lines | `canonical-sql/support/canonical_mo_planned_quantity.sql` |
| `public.capture_sales_order_release_transitions` | FUNCTION | E5/E6_ROOT | sales_order_release_history, v_release_queue | `canonical-sql/support/capture_sales_order_release_transitions.sql` |
| `public.copy_production_order_operations` | FUNCTION | E5/E6_ROOT, production_orders, TRIGGER:copy_production_order_operations_change | operations, production_order_operations, routing_operations, work_centers | `canonical-sql/support/copy_production_order_operations.sql` |
| `public.create_manufacturing_orders` | FUNCTION | backfill_active_wip_manufacturing_orders, E5/E6_ROOT | manufacturing_order_lines, production_demand_lines, production_orders, routings | `canonical-sql/support/create_manufacturing_orders.sql` |
| `public.enforce_manufacturing_order_line_boundary` | FUNCTION | E5/E6_ROOT, manufacturing_order_lines, TRIGGER:enforce_manufacturing_order_line_boundary_change | production_demand_lines, production_orders | `canonical-sql/support/enforce_manufacturing_order_line_boundary.sql` |
| `public.enforce_production_resource_asset_organization` | FUNCTION | production_resources, TRIGGER:production_resource_asset_organization | maintenance_assets | `canonical-sql/support/enforce_production_resource_asset_organization.sql` |
| `public.enforce_sync_batch_organization` | FUNCTION | source_orders, source_stock_items, source_workbank_items, TRIGGER:source_orders_batch_organization, TRIGGER:source_stock_batch_organization, TRIGGER:source_workbank_batch_organization | sync_batches | `canonical-sql/support/enforce_sync_batch_organization.sql` |
| `public.ingest_authoritative_release_lines` | FUNCTION | E5/E6_ROOT | source_order_release_lines, sync_batches | `canonical-sql/support/ingest_authoritative_release_lines.sql` |
| `public.maintenance_asset_categories` | TABLE | maintenance_asset_prefixes, maintenance_assets | organizations | `canonical-sql/support/maintenance_asset_categories.sql` |
| `public.maintenance_audit_change` | FUNCTION | maintenance_assets, maintenance_preventive_plans, maintenance_work_orders, manufacturing_order_lines, production_demand_exceptions, production_demand_lines, production_order_operations, production_orders, production_routing_exceptions, products, routing_operations, routings, source_operation_mappings, TRIGGER:audit_change, TRIGGER:manufacturing_order_lines_audit, TRIGGER:product_routing_assignment_audit_change, TRIGGER:production_demand_exceptions_audit, TRIGGER:production_demand_lines_audit, TRIGGER:production_order_operations_audit, TRIGGER:production_orders_execution_audit, TRIGGER:production_routing_exceptions_audit, TRIGGER:routing_master_audit_change, TRIGGER:routing_operations_audit_change, TRIGGER:source_operation_mappings_audit | maintenance_audit_log | `canonical-sql/support/maintenance_audit_change.sql` |
| `public.maintenance_audit_log` | TABLE | maintenance_audit_change | organizations | `canonical-sql/support/maintenance_audit_log.sql` |
| `public.manufacturing_order_lines` | TABLE | canonical_mo_planned_quantity, create_manufacturing_orders, E5/E6_ROOT, production_demand_release_events, recalculate_manufacturing_order_actual, reconcile_release_revocations, update_manufacturing_order_line_quantity, v_manufacturing_order_product_mix, v_release_reactivation_candidates, v_release_revocation_candidates | enforce_manufacturing_order_line_boundary, maintenance_audit_change, maintenance_members, organizations, production_demand_lines, production_orders, products, recalculate_manufacturing_order_actual, recalculate_manufacturing_order_quantity, routings | `canonical-sql/support/manufacturing_order_lines.sql` |
| `public.operations` | TABLE | copy_production_order_operations, E5/E6_ROOT, prepare_production_order_snapshot, protect_routing_operation_change, resolve_source_task_context, routing_operations, seed_source_operation_mappings, source_operation_mappings, source_task_mappings | maintenance_members, organizations, protect_active_operation_deactivation | `canonical-sql/support/operations.sql` |
| `public.oracle_line_ingestion_runs` | TABLE | oracle_line_ingestion_staging, product_mapping_resolution_audit, product_source_mappings, production_demand_release_events, reconcile_release_reactivations, reconcile_release_revocations, source_order_release_lines, v_authoritative_release_lines, v_release_reactivation_candidates, v_release_revocation_candidates | maintenance_members, organizations, sync_batches | `canonical-sql/support/oracle_line_ingestion_runs.sql` |
| `public.oracle_line_ingestion_staging` | TABLE | v_authoritative_release_lines, v_release_reactivation_candidates, v_release_revocation_candidates | oracle_line_ingestion_runs, organizations | `canonical-sql/support/oracle_line_ingestion_staging.sql` |
| `public.prepare_production_order_snapshot` | FUNCTION | E5/E6_ROOT, production_orders, TRIGGER:prepare_production_order_snapshot_change | operations, products, routing_operations, routings | `canonical-sql/support/prepare_production_order_snapshot.sql` |
| `public.product_families` | TABLE | E5/E6_ROOT, products | maintenance_members, organizations | `canonical-sql/support/product_families.sql` |
| `public.product_mapping_resolution_audit` | TABLE | E5/E6_ROOT | maintenance_members, oracle_line_ingestion_runs, organizations | `canonical-sql/support/product_mapping_resolution_audit.sql` |
| `public.product_routing_assignments` | TABLE | E5/E6_ROOT, resolve_product_process_routing | maintenance_members, organizations, products, routings | `canonical-sql/support/product_routing_assignments.sql` |
| `public.product_source_mappings` | TABLE | backfill_active_wip_manufacturing_orders, E5/E6_ROOT, v_active_source_product_task_context, v_released_demand_resolution | maintenance_members, oracle_line_ingestion_runs, organizations, products | `canonical-sql/support/product_source_mappings.sql` |
| `public.product_types` | TABLE | E5/E6_ROOT, products | maintenance_members, organizations | `canonical-sql/support/product_types.sql` |
| `public.production_demand_exceptions` | TABLE | backfill_active_wip_manufacturing_orders, E5/E6_ROOT | maintenance_audit_change, maintenance_members, organizations, production_demand_lines | `canonical-sql/support/production_demand_exceptions.sql` |
| `public.production_demand_lines` | TABLE | backfill_active_wip_manufacturing_orders, canonical_mo_planned_quantity, create_manufacturing_orders, E5/E6_ROOT, enforce_manufacturing_order_line_boundary, manufacturing_order_lines, production_demand_exceptions, production_demand_release_events, reconcile_release_reactivations, reconcile_release_revocations, update_manufacturing_order_line_quantity, v_release_reactivation_candidates, v_release_revocation_candidates | maintenance_audit_change, maintenance_members, organizations, products, routings | `canonical-sql/support/production_demand_lines.sql` |
| `public.production_demand_release_events` | TABLE | E5/E6_ROOT, reconcile_release_reactivations, reconcile_release_revocations, v_release_reactivation_candidates | maintenance_members, manufacturing_order_lines, oracle_line_ingestion_runs, organizations, production_demand_lines, production_orders | `canonical-sql/support/production_demand_release_events.sql` |
| `public.production_order_history` | TABLE | E5/E6_ROOT | organizations, production_orders | `canonical-sql/support/production_order_history.sql` |
| `public.production_order_operation_evidence` | TABLE | E5/E6_ROOT, resolve_production_order_actual_state_unambiguous, v_production_order_routing_status | maintenance_members, organizations, production_order_operations, production_orders, source_audit_events, source_operation_mappings | `canonical-sql/support/production_order_operation_evidence.sql` |
| `public.production_order_operations` | TABLE | copy_production_order_operations, E5/E6_ROOT, production_order_operation_evidence, production_routing_exceptions, recalculate_manufacturing_order_quantity, reconcile_release_reactivations, reconcile_release_revocations, resolve_production_order_actual_state, resolve_production_order_actual_state_unambiguous, v_manufacturing_order_progress, v_production_order_execution, v_production_order_routing_status | maintenance_audit_change, maintenance_members, organizations, production_orders, protect_production_operation_snapshot, shift_templates | `canonical-sql/support/production_order_operations.sql` |
| `public.production_orders` | TABLE | create_manufacturing_orders, E5/E6_ROOT, enforce_manufacturing_order_line_boundary, manufacturing_order_lines, production_demand_release_events, production_order_history, production_order_operation_evidence, production_order_operations, production_routing_exceptions, recalculate_manufacturing_order_actual, recalculate_manufacturing_order_quantity, reconcile_release_reactivations, reconcile_release_revocations, resolve_production_order_actual_state, resolve_production_order_actual_state_unambiguous, update_manufacturing_order_line_quantity, v_manufacturing_order_current_operation, v_manufacturing_order_product_mix, v_production_order_execution, v_production_order_routing_status, v_release_queue, v_release_reactivation_candidates, v_release_revocation_candidates | copy_production_order_operations, maintenance_audit_change, maintenance_members, organizations, prepare_production_order_snapshot, products, shift_templates | `canonical-sql/support/production_orders.sql` |
| `public.production_process_stages` | TABLE | E5/E6_ROOT | organizations, production_processes | `canonical-sql/support/production_process_stages.sql` |
| `public.production_processes` | TABLE | E5/E6_ROOT, production_process_stages, resolve_source_task_context, source_task_mappings | organizations | `canonical-sql/support/production_processes.sql` |
| `public.production_resources` | TABLE | E5/E6_ROOT | enforce_production_resource_asset_organization, maintenance_assets, maintenance_members, organizations, work_centers | `canonical-sql/support/production_resources.sql` |
| `public.production_routing_exceptions` | TABLE | resolve_production_order_actual_state, resolve_production_order_actual_state_unambiguous, update_manufacturing_order_line_quantity, v_production_order_routing_status | maintenance_audit_change, maintenance_members, organizations, production_order_operations, production_orders | `canonical-sql/support/production_routing_exceptions.sql` |
| `public.products` | TABLE | backfill_active_wip_manufacturing_orders, E5/E6_ROOT, manufacturing_order_lines, prepare_production_order_snapshot, product_routing_assignments, product_source_mappings, production_demand_lines, production_orders, resolve_product_process_routing, v_manufacturing_order_product_mix | maintenance_audit_change, maintenance_members, organizations, product_families, product_types, routings, validate_product_default_routing | `canonical-sql/support/products.sql` |
| `public.protect_active_operation_deactivation` | FUNCTION | operations, TRIGGER:protect_active_operation_deactivation_change | routing_operations, routings | `canonical-sql/support/protect_active_operation_deactivation.sql` |
| `public.protect_production_operation_snapshot` | FUNCTION | E5/E6_ROOT, production_order_operations, TRIGGER:protect_production_operation_snapshot_change |  | `canonical-sql/support/protect_production_operation_snapshot.sql` |
| `public.protect_routing_operation_change` | FUNCTION | E5/E6_ROOT, routing_operations, TRIGGER:protect_routing_operation_change | operations, routings | `canonical-sql/support/protect_routing_operation_change.sql` |
| `public.protect_routing_revision` | FUNCTION | E5/E6_ROOT, routings, TRIGGER:protect_routing_revision_change |  | `canonical-sql/support/protect_routing_revision.sql` |
| `public.recalculate_manufacturing_order_actual` | FUNCTION | manufacturing_order_lines, TRIGGER:recalculate_manufacturing_order_actual_change | manufacturing_order_lines, production_orders | `canonical-sql/support/recalculate_manufacturing_order_actual.sql` |
| `public.recalculate_manufacturing_order_quantity` | FUNCTION | E5/E6_ROOT, manufacturing_order_lines, TRIGGER:recalculate_manufacturing_order_quantity_change | canonical_mo_planned_quantity, production_order_operations, production_orders | `canonical-sql/support/recalculate_manufacturing_order_quantity.sql` |
| `public.reconcile_release_reactivations` | FUNCTION | E5/E6_ROOT | canonical_mo_planned_quantity, oracle_line_ingestion_runs, production_demand_lines, production_demand_release_events, production_order_operations, production_orders, v_release_reactivation_candidates | `canonical-sql/support/reconcile_release_reactivations.sql` |
| `public.reconcile_release_revocations` | FUNCTION | E5/E6_ROOT | manufacturing_order_lines, oracle_line_ingestion_runs, production_demand_lines, production_demand_release_events, production_order_operations, production_orders, v_release_revocation_candidates | `canonical-sql/support/reconcile_release_revocations.sql` |
| `public.release_reactivation_action` | FUNCTION | E5/E6_ROOT, v_release_reactivation_candidates |  | `canonical-sql/support/release_reactivation_action.sql` |
| `public.release_revocation_action` | FUNCTION | E5/E6_ROOT, v_release_revocation_candidates |  | `canonical-sql/support/release_revocation_action.sql` |
| `public.resolve_product_process_routing` | FUNCTION | E5/E6_ROOT, resolve_product_routing_from_source_task, v_active_source_product_task_context, v_released_demand_resolution | product_routing_assignments, products, routings | `canonical-sql/support/resolve_product_process_routing.sql` |
| `public.resolve_product_routing_from_source_task` | FUNCTION | E5/E6_ROOT | resolve_product_process_routing, resolve_source_task_context | `canonical-sql/support/resolve_product_routing_from_source_task.sql` |
| `public.resolve_production_order_actual_state` | FUNCTION | backfill_active_wip_manufacturing_orders | production_order_operations, production_orders, production_routing_exceptions, resolve_production_order_actual_state_unambiguous, v_source_operation_evidence | `canonical-sql/support/resolve_production_order_actual_state.sql` |
| `public.resolve_production_order_actual_state_unambiguous` | FUNCTION | resolve_production_order_actual_state | production_order_operation_evidence, production_order_operations, production_orders, production_routing_exceptions, seed_source_operation_mappings, v_source_operation_evidence | `canonical-sql/support/resolve_production_order_actual_state_unambiguous.sql` |
| `public.resolve_source_task_context` | FUNCTION | resolve_product_routing_from_source_task, v_source_task_resolution | operations, production_processes, source_task_mappings, source_value_matches | `canonical-sql/support/resolve_source_task_context.sql` |
| `public.routing_operations` | TABLE | copy_production_order_operations, E5/E6_ROOT, prepare_production_order_snapshot, protect_active_operation_deactivation | maintenance_audit_change, maintenance_members, operations, organizations, protect_routing_operation_change, routings, work_centers | `canonical-sql/support/routing_operations.sql` |
| `public.routings` | TABLE | backfill_active_wip_manufacturing_orders, create_manufacturing_orders, E5/E6_ROOT, manufacturing_order_lines, prepare_production_order_snapshot, product_routing_assignments, production_demand_lines, products, protect_active_operation_deactivation, protect_routing_operation_change, resolve_product_process_routing, routing_operations, v_release_queue, validate_product_default_routing | maintenance_audit_change, maintenance_members, organizations, protect_routing_revision | `canonical-sql/support/routings.sql` |
| `public.sales_order_release_history` | TABLE | capture_sales_order_release_transitions, E5/E6_ROOT | maintenance_members, organizations, sync_batches | `canonical-sql/support/sales_order_release_history.sql` |
| `public.seed_source_operation_mappings` | FUNCTION | resolve_production_order_actual_state_unambiguous | operations, source_operation_mappings | `canonical-sql/support/seed_source_operation_mappings.sql` |
| `public.source_operation_mappings` | TABLE | E5/E6_ROOT, production_order_operation_evidence, seed_source_operation_mappings, v_source_operation_evidence | maintenance_audit_change, maintenance_members, operations, organizations | `canonical-sql/support/source_operation_mappings.sql` |
| `public.source_operational_code_mappings` | TABLE | E5/E6_ROOT | maintenance_members, organizations | `canonical-sql/support/source_operational_code_mappings.sql` |
| `public.source_order_release_lines` | TABLE | E5/E6_ROOT, ingest_authoritative_release_lines, v_authoritative_release_lines | maintenance_members, oracle_line_ingestion_runs, organizations, sync_batches | `canonical-sql/support/source_order_release_lines.sql` |
| `public.source_orders` | TABLE | v_current_orders | enforce_sync_batch_organization, organizations, sync_batches | `canonical-sql/support/source_orders.sql` |
| `public.source_task_mappings` | TABLE | E5/E6_ROOT, resolve_source_task_context | maintenance_members, operations, organizations, production_processes | `canonical-sql/support/source_task_mappings.sql` |
| `public.source_value_matches` | FUNCTION | resolve_source_task_context, v_source_operation_evidence |  | `canonical-sql/support/source_value_matches.sql` |
| `public.update_manufacturing_order_line_quantity` | FUNCTION | E5/E6_ROOT | manufacturing_order_lines, production_demand_lines, production_orders, production_routing_exceptions | `canonical-sql/support/update_manufacturing_order_line_quantity.sql` |
| `public.v_active_legacy_wip_detail` | VIEW | v_active_wip_mo_coverage | source_audit_events, v_current_stock, v_current_workbank | `canonical-sql/support/v_active_legacy_wip_detail.sql` |
| `public.v_active_source_product_lines` | VIEW | v_active_source_product_task_context | screen_print_jobs, source_workbank_items, v_current_stock, v_current_workbank | `canonical-sql/support/v_active_source_product_lines.sql` |
| `public.v_active_source_product_task_context` | VIEW | v_release_queue | product_source_mappings, resolve_product_process_routing, v_active_source_product_lines, v_source_task_resolution | `canonical-sql/support/v_active_source_product_task_context.sql` |
| `public.v_active_wip_mo_coverage` | VIEW | backfill_active_wip_manufacturing_orders | active_wip_coverage_exceptions, v_active_legacy_wip_detail, v_manufacturing_order_current_operation | `canonical-sql/support/v_active_wip_mo_coverage.sql` |
| `public.v_authoritative_release_lines` | VIEW | E5/E6_ROOT, v_released_demand_resolution, v_released_production_demand, v_sales_order_release_state | oracle_line_ingestion_runs, oracle_line_ingestion_staging, source_order_release_lines | `canonical-sql/support/v_authoritative_release_lines.sql` |
| `public.v_manufacturing_order_current_operation` | VIEW | E5/E6_ROOT, v_active_wip_mo_coverage, v_manufacturing_order_progress | production_orders, v_production_order_execution | `canonical-sql/support/v_manufacturing_order_current_operation.sql` |
| `public.v_manufacturing_order_product_mix` | VIEW | E5/E6_ROOT | manufacturing_order_lines, production_orders, products | `canonical-sql/support/v_manufacturing_order_product_mix.sql` |
| `public.v_manufacturing_order_progress` | VIEW | E5/E6_ROOT, v_manufacturing_order_routing_status | production_order_operations, v_manufacturing_order_current_operation | `canonical-sql/support/v_manufacturing_order_progress.sql` |
| `public.v_manufacturing_order_routing_status` | VIEW | E5/E6_ROOT | v_manufacturing_order_progress, v_production_order_routing_status | `canonical-sql/support/v_manufacturing_order_routing_status.sql` |
| `public.v_production_order_current_operation` | VIEW | E5/E6_ROOT, v_production_order_progress | v_production_order_execution | `canonical-sql/support/v_production_order_current_operation.sql` |
| `public.v_production_order_execution` | VIEW | v_manufacturing_order_current_operation, v_production_order_current_operation | production_order_operations, production_orders | `canonical-sql/support/v_production_order_execution.sql` |
| `public.v_production_order_progress` | VIEW | E5/E6_ROOT | v_production_order_current_operation, v_production_order_routing_status | `canonical-sql/support/v_production_order_progress.sql` |
| `public.v_production_order_routing_status` | VIEW | E5/E6_ROOT, v_manufacturing_order_routing_status, v_production_order_progress | production_order_operation_evidence, production_order_operations, production_orders, production_routing_exceptions | `canonical-sql/support/v_production_order_routing_status.sql` |
| `public.v_release_blockers` | VIEW | v_sales_order_release_eligibility | v_sales_order_release_state | `canonical-sql/support/v_release_blockers.sql` |
| `public.v_release_reactivation_candidates` | VIEW | E5/E6_ROOT, reconcile_release_reactivations | manufacturing_order_lines, oracle_line_ingestion_runs, oracle_line_ingestion_staging, production_demand_lines, production_demand_release_events, production_orders, release_reactivation_action | `canonical-sql/support/v_release_reactivation_candidates.sql` |
| `public.v_release_revocation_candidates` | VIEW | E5/E6_ROOT, reconcile_release_revocations | manufacturing_order_lines, oracle_line_ingestion_runs, oracle_line_ingestion_staging, production_demand_lines, production_orders, release_revocation_action | `canonical-sql/support/v_release_revocation_candidates.sql` |
| `public.v_released_demand_resolution` | VIEW | E5/E6_ROOT | product_source_mappings, resolve_product_process_routing, v_authoritative_release_lines, v_current_orders, v_released_production_demand, v_sales_order_release_eligibility, v_source_task_resolution | `canonical-sql/support/v_released_demand_resolution.sql` |
| `public.v_released_production_demand` | VIEW | E5/E6_ROOT, v_released_demand_resolution | v_authoritative_release_lines, v_sales_order_release_eligibility | `canonical-sql/support/v_released_production_demand.sql` |
| `public.v_sales_order_release_eligibility` | VIEW | E5/E6_ROOT, v_release_queue, v_released_demand_resolution, v_released_production_demand | v_release_blockers, v_sales_order_release_state | `canonical-sql/support/v_sales_order_release_eligibility.sql` |
| `public.v_sales_order_release_state` | VIEW | E5/E6_ROOT, v_release_blockers, v_release_queue, v_sales_order_release_eligibility | v_authoritative_release_lines, v_current_orders | `canonical-sql/support/v_sales_order_release_state.sql` |
| `public.v_source_operation_evidence` | VIEW | resolve_production_order_actual_state, resolve_production_order_actual_state_unambiguous | source_audit_events, source_operation_mappings, source_value_matches, v_current_stock, v_current_workbank | `canonical-sql/support/v_source_operation_evidence.sql` |
| `public.v_source_task_observations` | VIEW | v_source_task_resolution | source_audit_events, v_current_workbank | `canonical-sql/support/v_source_task_observations.sql` |
| `public.v_source_task_resolution` | VIEW | v_active_source_product_task_context, v_released_demand_resolution | resolve_source_task_context, v_source_task_observations | `canonical-sql/support/v_source_task_resolution.sql` |
| `public.validate_product_default_routing` | FUNCTION | products, TRIGGER:validate_product_default_routing_change | routings | `canonical-sql/support/validate_product_default_routing.sql` |
| `public.work_centers` | TABLE | copy_production_order_operations, E5/E6_ROOT, production_resources, routing_operations | maintenance_members, organizations | `canonical-sql/support/work_centers.sql` |

## Platform objects
- `auth.users`
- `auth.uid`
- `storage.objects`
- `storage.buckets`
- `pgcrypto.gen_random_uuid`

## Legacy unused
- `public.assign_source_product_routing`
- `public.clone_routing_revision`
- `public.ingest_release_header_context`
- `public.move_routing_operation`
- `public.normalize_production_event_units`
- `public.production_reconciliation_items`
- `public.production_reconciliation_runs`
- `public.production_stage_mappings`
- `public.rebuild_production_events`
- `public.reconcile_planned_mo_quantity_cache`
- `public.resolve_production_date`
- `public.resolve_source_operational_context`
- `public.run_production_reconciliation`
- `public.v_flow_operation_detail`
- `public.v_flow_operation_summary`
- `public.v_latest_production_reconciliation`
- `public.v_latest_production_reconciliation_items`
- `public.v_product_mix_classification`
- `public.v_product_routing_mapping_gaps`
- `public.v_production_flow_canonical`
- `public.v_production_flow_legacy_snapshot`
- `public.v_production_flow_routing_reconciliation`
- `public.v_production_reconciliation_gate`
- `public.v_release_revocation_mo_dry_run`
- `public.v_routing_coverage_metrics`
- `public.v_routing_master`
- `public.v_routing_product_coverage`
- `public.v_source_operational_code_observations`
- `public.v_up_operator_daily_productivity`
