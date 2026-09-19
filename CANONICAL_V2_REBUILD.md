# TSD Production Control - Canonical V2 Rebuild

## Workstream identity

| Item | Value |
| --- | --- |
| Branch | `canonical-v2` |
| Worktree | `C:\Projects\tsd-canonical-v2` |
| Starting commit | `55db6cfbdb476b21f31045fbd282fa7bfb93da68` (`origin/main`) |
| Repository | Existing TSD application repository |
| Supabase link | `saecycamkyvzzppxudzq` |
| V2 project | `tsd-production-control-v2` (`ap-southeast-2`) |

The prior DEV/production migration-reconciliation workstream is closed. Historical migrations are reference material only and will not become the V2 migration history.

## Non-negotiable safety rules

- Oracle is permanently read-only.
- Current production is read-only and remains the rollback environment.
- Current DEV is read-only canonical E5/E6 reference material.
- V2 must use a distinct Supabase project and a clean migration history.
- No legacy migration will be replayed, repaired, squashed or renumbered into V2.
- Production environment variables will not be changed during construction.
- Secrets will not be committed.

## Infrastructure Constraint — NO DOCKER

Docker, Docker Desktop, Docker Compose, and Docker-based Supabase local are not supported for this ERP environment.

Do not use Docker as a development, validation, migration, or recovery dependency unless Felipe explicitly re-authorizes it. Validation requiring database isolation must use a proven non-Docker target and must retain the existing production, legacy rollback, DEV, and Oracle protections.

## Phase status

| Phase | Status | Evidence/result |
| --- | --- | --- |
| 0 - V2 workstream | COMPLETE | Dedicated clean worktree and branch created from `origin/main`. |
| 1 - Current system inventory | COMPLETE for application code | Actual Supabase relation/RPC/storage references traced from source. |
| 2 - Data classification | INITIAL CLASSIFICATION COMPLETE | See `CANONICAL_V2_DATA_CLASSIFICATION.md`; row-level export counts remain pending. |
| 3 - Canonical business model | PENDING | Requires consolidation of validated E5/E6 contracts, not legacy SQL replay. |
| 4 - Clean baseline | NOT STARTED | Must follow approved canonical model and complete master/config inventory. |
| 5 - New Supabase V2 | COMPLETE | New empty project created and linked only to this worktree. DEV is paused; production remains active. |
| 6 - Canonical baseline | BLOCKED | C2 static validation found non-executable merged contracts, incomplete PostgreSQL type/grant metadata, and missing exact E5/E6 support-object contracts. V2 was not reset. |
| 7-20 | NOT STARTED | Blocked until the baseline contract is complete and validated. |

## Current application dependency map

This map reflects direct source-code dependencies on `origin/main` at the starting commit.

### Authentication and tenancy

```text
Login / middleware / server Supabase client
  -> Supabase Auth
  -> organizations
  -> maintenance_members
  -> source of truth: Supabase Auth + ERP membership/config
```

### Oracle sync and freshness

```text
OracleSourceReader (READ ONLY)
  -> ingest API
  -> ingest_sync_batch / ingest_audit_backfill
  -> source_orders, source_workbank_items, source_stock_items, source_audit_events
  -> sync_batches, sync_agent_heartbeat, sync_runs, sync_refresh_requests
  -> v_latest_completed_batch, v_source_reconciliation
  -> source of truth: Oracle for source facts; Supabase for ingestion provenance/status
```

Scheduling/control uses `claim_sync_work` and `finish_sync_work`. Manual refresh and the five-minute agent depend on the same control domain.

### Operational production

```text
Production pages / source-data services
  -> v_current_orders, v_current_workbank, v_current_stock
  -> v_order_stage_summary, v_dtg_order_history
  -> source facts from Oracle snapshots
```

Flow and workload services also read `source_audit_events`, `v_dtg_operational_orders`, `v_up_operational_orders`, `screen_print_jobs` and `production_stage_source_rules`.

### Release Queue

```text
/production/release-queue
  -> release-queue service
  -> v_release_queue
  -> source of truth: Oracle release/header/line evidence interpreted by canonical ERP rules
```

The current UI expects process quantities, blockers, route evidence and statuses including ELIGIBLE, NOT_APPROVED, BLOCKED, FUTURE_DUE and UNKNOWN.

### Product Mapping, Routing, Production Demand and Manufacturing Orders

These E5/E6 domains are canonical requirements but are not directly represented by the checked-in `origin/main` application data-access surface. Their V2 contracts must be derived from validated E5/E6 rules/tests and current DEV read-only inspection, then expressed directly in the clean baseline.

Required concepts:

- product families/types/products/source mappings;
- operations/work centres/resources;
- routings/revisions/operations/product assignments;
- source task/operational-code mappings;
- line-level release lifecycle and audit;
- canonical Production Demand and demand mappings;
- Manufacturing Orders and immutable operation snapshots;
- quantity authority and revocation/rerelease protections.

### Machine Load

```text
/production/machine-load
  -> machine-load service
  -> v_current_workbank, v_current_stock, v_current_orders
  -> v_capacity_load, screen_print_jobs
  -> v_machine_load_not_approved (only when Show Not Approved is enabled)
  -> source of truth: operational source evidence + ERP capacity/config
```

`v_machine_load_not_approved` is service-role-only and informational. Its quantities must not alter active load, backlog, capacity, utilisation, productivity, targets or scheduling.

### Product Mix

```text
Machine Load source rows
  -> production-mix classifiers/rules
  -> WAITING_FOR_PICKING / READY_TO_PRINT
  -> optional NOT_APPROVED_INFORMATIONAL projection
```

The application preserves record identity, SO/SKU overlap protection, physical/process quantity distinction and unclassified visibility.

### Performance and labour

```text
Performance/KPI services
  -> production_events
  -> v_current_labour_segments, deputy_raw_timesheets
  -> kpi_rate_rules, resource_capacity_rules
  -> v_latest_completed_batch
  -> source of truth: Oracle audit-derived events + Deputy labour + ERP rate/config rules
```

Screen Print manual events write to `production_events`. Deputy import writes import batches, raw rows and derived labour segments.

### Planning, capacity and KPI configuration

```text
Planning
  -> v_production_planning, production_plans/items/history
  -> apply_production_planning, daily-plan RPCs

Capacity
  -> production_areas, capacity_profiles/scenarios/lines
  -> staffing_layouts/lines, capacity_legacy_overrides
  -> v_capacity_load

KPI configuration
  -> kpi_definitions, kpi_targets, kpi_results
  -> v_kpi_dashboard, v_kpi_trends
```

### Maintenance

```text
Maintenance UI/actions
  -> assets/categories/prefixes/installations
  -> work orders/history/comments/labour/checklists/attachments
  -> preventive plans/tasks/downtime
  -> parts/locations/inventory transactions/stock views
  -> maintenance lifecycle/operator/import RPCs
  -> maintenance-private storage bucket
  -> source of truth: ERP master/config + ERP operational maintenance records
```

## Direct database surface inventory

### Relations and views

The current code directly references these groups:

- Source/sync: `organizations`, `source_audit_events`, `source_stock_items`, `source_workbank_items`, `sync_batches`, `sync_agent_heartbeat`, `sync_runs`, `sync_refresh_requests`, `v_current_orders`, `v_current_stock`, `v_current_workbank`, `v_latest_completed_batch`, `v_source_reconciliation`.
- Production: `production_events`, `screen_print_jobs`, `production_stage_source_rules`, `v_order_stage_summary`, `v_dtg_operational_orders`, `v_up_operational_orders`, `v_dtg_order_history`.
- Release/load: `v_release_queue`, `v_machine_load_not_approved`, `v_capacity_load`.
- Labour: `deputy_import_batches`, `deputy_raw_timesheets`, `labour_segments`, `v_current_labour_segments`.
- Planning/capacity: `production_areas`, `production_plans`, `production_plan_items`, `production_plan_history`, `v_daily_plans`, `v_production_planning`, `capacity_profiles`, `capacity_scenarios`, `capacity_scenario_lines`, `capacity_legacy_overrides`, `staffing_layouts`, `staffing_layout_lines`, `shift_templates`, `resource_capacity_rules`.
- KPIs: `kpi_definitions`, `kpi_targets`, `kpi_results`, `kpi_rate_rules`, `v_kpi_dashboard`, `v_kpi_trends`.
- Maintenance: all `maintenance_*` relations listed in the source inventory plus `maintenance_asset_current_installations` and `maintenance_part_stock_levels`.

### RPCs

- Sync: `ingest_sync_batch`, `ingest_audit_backfill`, `claim_sync_work`, `finish_sync_work`.
- Planning: `apply_production_planning`, `create_daily_plan`, `add_daily_plan_items`, `update_daily_plan_item`, `transition_daily_plan`.
- Maintenance: `maintenance_create_asset`, `maintenance_create_component`, `maintenance_generate_due_pm`, `maintenance_import_history`, `maintenance_operator_classify`, `maintenance_operator_escalate`, `maintenance_operator_pm_action`, `maintenance_operator_resolve`, `maintenance_operator_start_request`, `maintenance_post_inventory`, `maintenance_report_problem`, `maintenance_transition_work_order`.

### Storage

- `maintenance-private`.

## V2 baseline design rule

The future `001_canonical_baseline.sql` will describe the approved end-state schema directly. It will not be assembled by concatenating or replaying old migrations. It cannot be authored safely until:

1. all E5/E6 canonical objects and invariants are captured;
2. all ERP master/config datasets and natural keys are approved;
3. RLS/role matrix is defined for every domain;
4. Release Queue and Machine Load contracts are unified;
5. a separate V2 project is available for empty-database validation.

## Supabase V2 identity

Authenticated project inventory at V2 creation:

- DEV: `tlflipdeahgwsueerkex` (`INACTIVE`, preserved);
- production/rollback: `gdajktoqmajipivpdude` (`ACTIVE_HEALTHY`, untouched);
- canonical V2: `saecycamkyvzzppxudzq` (`ACTIVE_HEALTHY`).

The three refs are distinct. Only `C:\Projects\tsd-canonical-v2` is linked to canonical V2.

**TARGET = CANONICAL_V2**

Required next state:

- a third, empty Supabase project;
- exact project ref and database host visible to the authenticated CLI account;
- explicit identity distinct from DEV and production;
- dedicated V2 credentials kept outside Git.

No source data, master data or Oracle bootstrap has been applied.

## C2.2 final baseline result

- Target project: `saecycamkyvzzppxudzq` (Canonical V2 only)
- Direct runtime contract coverage: 86/86
- Approved support contract coverage: 87/87
- Additional transitive contracts discovered by executable replay: 22
- Unique executable objects: 195
- Static validation: PASS
- Unresolved SQL references after clean replay: 0
- Duplicate executable definitions: 0
- V2 clean reset: PASS
- Clean `001_canonical_baseline.sql` apply: PASS
- Remote migration history: `001` only
- Missing approved objects: 0
- Unexpected objects: 22, all explained transitive dependencies required by direct contracts/tests
- Release lifecycle tests: 13/13 PASS
- Routing tests: 26/26 PASS
- E6 lifecycle/transactional tests: 26/26 PASS
- Release Queue application tests: 6/6 PASS
- Machine Load application tests: 14/14 PASS
- Product Mix application tests: 21/21 PASS
- RLS/isolation checks: PASS within Routing B-D suites
- Application tests: 176/176 PASS
- Lint: PASS
- Typecheck: PASS
- Production build: PASS
- Fixture residue: 0
- Legacy application migrations: 0
- Master data imported: 0
- Oracle data imported: 0
- DEV: UNTOUCHED
- Production: UNTOUCHED
- Oracle: READ-ONLY / UNTOUCHED

### Executable replay corrections

The initial C2.1A manifest omitted 22 true transitive dependencies used by direct views/functions and validation suites. Clean replay identified and added them without importing legacy migration history. The canonical release-transition function was bound directly to `v_sales_order_release_state` plus `v_sales_order_release_eligibility`, avoiding the UI `v_release_queue` name collision. Platform extensions required by exact contracts/tests are `pgcrypto`, `pg_trgm`, `btree_gist`, and `pgtap`.

## C3 master config migration

Production-safe master config export completed: 25 datasets / 273 rows. No V2 import was performed because 13 mandatory Product/Routing datasets require a read-only export from paused DEV. See `CANONICAL_V2_MASTER_CONFIG_REPORT.md` and `canonical-data/master-config/MASTER_CONFIG_MANIFEST.json`.

**C3 gate: BLOCKED — DEV_SOURCE_REQUIRED**

### C3.1 DEV-only Product/Routing capture

The controlled project-slot rotation completed successfully. Read-only inspection proved that all 13 required Product/Routing relations exist in DEV `tlflipdeahgwsueerkex`, but every relation has zero rows. Consequently, no DEV-only dataset could be exported and the complete master-config package remains 25/38 datasets and 273 rows. The package was not imported into V2.

Final project state was restored: production and V2 are `ACTIVE_HEALTHY`; DEV is `INACTIVE`. No data or schema writes occurred in DEV or production, and Oracle remained disconnected/read-only.

**C3.1 gate: BLOCKED — DEV_PRODUCT_ROUTING_CONFIG_EMPTY**

### C3.2 master-config completion

Runtime analysis proved the 13 empty Product/Routing relations are valid empty canonical infrastructure rather than missing required seed data. The 40-dataset inventory now reconciles to 17 `MUST_PRESERVE_WITH_ROWS`, 2 `RUNTIME_GENERATED`, and 21 `OPTIONAL_CONFIG`; no true config is missing.

The 17 required datasets and 273 approved rows were imported into V2 twice. The second run produced zero duplicates, inserts, deletes or unexplained updates. Product/Routing runtime/config tables remained empty. Post-import checks found zero duplicate natural keys, unresolved FKs, unvalidated constraints, Oracle rows or fixture residue.

Routing tests passed 26/26, release lifecycle passed 13/13, E6.8/E6.8.1 passed 26/26, application tests passed 176/176, and lint, typecheck and production build passed. DEV and production were not modified; Oracle remained disconnected/read-only.

**C3.2 gate: COMPLETE — READY FOR ORACLE BOOTSTRAP**

### C4 Oracle source bootstrap preflight

C4 stopped before connecting to Oracle. The Oracle execution surface contains only SELECT statements and no Oracle write path, but the current source contract omits the authoritative `IS_ORDER_LINE.RELEASED` field. The connector maps line identity and quantity into `source_release_order_lines`; it neither supplies nor invokes the canonical path for `source_order_release_lines`.

The V2 pre-bootstrap snapshot remains zero for all Oracle source tables, Production Demand, Production Orders/MOs, MO lines and sync batches. No Oracle credential was loaded, no Oracle connection was attempted, and no V2 ingestion was run. Production and DEV were untouched.

See `CANONICAL_V2_ORACLE_BOOTSTRAP_REPORT.md`.

**C4 gate: BLOCKED — AUTHORITATIVE_RELEASE_FIELD_MISSING_FROM_SYNC_CONTRACT**


## C4.1 completed - authoritative release ingestion

Canonical V2 now ingests `IS_ORDER_LINE.RELEASED` at `ORDER_NO + LINE_NUMBER` grain. Three controlled passes reconciled 23,477/23,477 lines with zero missing keys, duplicates, release mismatches, quantity mismatches, or derived Production Demand/MO contamination. Validation passed (177 application tests, 75 SQL assertions, lint, typecheck, build). The next permitted phase is the explicitly approved canonical derived rebuild; it has not been started.
## C5 blocked at Product and Routing coverage gate

The source baseline remains stable at 23,477 Sales Order Lines: 5,768 released and 17,709 unreleased. C5 performed no derived writes because Product Master, Product Source Mapping, Operations, Routings, Routing Operations, Product-to-Routing assignments, and source mappings are empty. All released lines therefore remain Product and Routing unresolved. See `CANONICAL_V2_DERIVED_REBUILD_REPORT.md`. Production, DEV, and Oracle were untouched.
## C5.1 completed - Product and Routing reference recovery

The working production system was proven to use Oracle-derived `GROUP_CODE` and Workbank evidence rather than populated canonical Product/Route tables. A deterministic 10-dataset package was created under `canonical-data/product-routing/` and imported twice into V2 with zero second-run delta. All 5,768 released lines now map to a Product; 4,438 DTG/Underprint lines resolve an approved Routing and 1,330 unsupported-process lines remain explicitly unresolved. Production Demand, MOs, and MO lines remain zero. See `CANONICAL_V2_PRODUCT_ROUTING_REFERENCE_REPORT.md`.

## Phase C5.2 - Derived state from resolved Routing

The C5.2 frozen baseline confirmed 5,768 released lines, 5,768 Product-mapped lines, 4,438 Routing-resolved lines, and 1,330 Routing-unresolved lines. The complete unresolved population was exported as controlled exceptions.

Derived creation is blocked before writes because every supported Routing-resolved DTG/Underprint line has authoritative `production_units = 0` and source `qty_lcd = 0`. The canonical Demand contract requires positive quantity, and no alternate approved line-level quantity is present. Production Demand, mappings, MOs, and MO lines remain zero. DEV, production, and Oracle were untouched.

Gate: **CANONICAL V2 DERIVED REBUILD BLOCKED — authoritative positive quantity is absent for all 4,438 Routing-resolved released lines**.

## Phase C5.2A - Authoritative production quantity diagnostic

C5.2A completed read-only with result `E. NO_AUTHORITATIVE_QUANTITY_PROVEN`. Oracle `QTY_LCD`, `QUANTITY`, `QTY_PROCESSED`, and `WEIGHT` are zero for all 4,438 supported Routing-resolved lines. `QTY_UNITS=1` was rejected because the Oracle data dictionary defines it as the pack-description level number, not physical quantity. Workbank quantity is mutable operational evidence at a different grain and cannot create original Demand. Derived state remains zero.

Gate: **C5.2A BLOCKED — NO AUTHORITATIVE PRODUCTION QUANTITY PROVEN**.

## Phase C5.2B - Business quantity contract

C5.2B completed read-only. Oracle's semantic quantity fields are zero for all 4,438 Routing-resolved DTG/Underprint lines. `QTY_UNITS=1` was conclusively rejected as commercial quantity because Oracle defines it as a pack-description level number. The current ERP displays operational Workbank/Stock/Audit quantities rather than original Sales Order Line quantity. No deterministic physical-quantity relation was proven.

Gate: **B. NO ORACLE LINE QUANTITY CAN BE PROVEN**. Technical investigation stops pending an explicit business-owner quantity rule.

## Phase C5.2C - Workbank operational authority

Part A confirmed exact Workbank ingestion and current-state semantics, with V2/PROD aggregate parity at 8,323 rows and 13,296 units. Authority was not proven because Workbank has no Sales Order line number, none of the 4,438 Routing-resolved release lines joins to current Workbank by the available `ORDER_NO + SKU` key, collapsed operational keys contain 1,425 duplicate groups, process alignment is unavailable, and only one of three completed snapshots contains Workbank rows. Parts B/C were not executed and derived state remains zero.

Gate: **CANONICAL V2 OPERATIONAL DEMAND BLOCKED — WORKBANK AUTHORITY NOT PROVEN**.
# Phase C5.3 - Dual-source operational model and cutover readiness

Canonical V2 formally separates Oracle Sales Order Line release authority from Workbank current-load authority. Release Queue and Workbank quantities are non-additive and no inferred line-to-Workbank join is permitted.

Current live application code has no runtime dependency on Production Demand or Manufacturing Orders. Demand/MO is retained as a `DEFERRED_CANONICAL_LAYER`.

Read-only parity on 18 September 2026 passed for Orders, Workbank, Stock, DTG, Underprint, Release Queue and Not Approved. Cutover remains blocked because V2 lacks 76,092 audit events, 826 DTG history rows, three capacity rows, six Screen Print jobs and four maintenance work orders. Three consecutive non-empty V2 full snapshots are also not yet proven.

See `CANONICAL_V2_OPERATIONAL_SOURCE_CONTRACT.md` and `CANONICAL_V2_OPERATIONAL_PARITY_REPORT.md`. No preview deployment or V2 recurring scheduler was activated.

## Phase C5.5 - Audit and DTG history authority

Oracle/WMS `source_audit_events` is the authoritative movement history. All 76,092 events were classified and preserved in V2; unknown and test/obsolete counts are zero. Re-application inserted zero rows.

`v_dtg_order_history` is a derived order-level view over DTG Pick and Print movements. It reconciles at 826/826 rows. Canonical `production_events` were rebuilt from the source events and were not copied from the legacy transformation output.

See `AUDIT_EVENT_CLASSIFICATION.md` and `CANONICAL_V2_C5_5_AUDIT_DTG_HISTORY.md`.
