# Canonical V2 Master Config Report

## Result

The production read-only export package is complete, but import is blocked before any V2 write. Production has no canonical Product Master, Routing Master, operations/work centres/resources, Product-to-Routing assignments, or reusable source task/operation mappings. The only populated source for those approved records is expected to be paused DEV; historical migration seeds and test fixtures are not authoritative replacements.

## Safety

- Target prepared: Canonical V2 `saecycamkyvzzppxudzq`
- Production source: `gdajktoqmajipivpdude` READ-ONLY
- DEV: `tlflipdeahgwsueerkex` PAUSED / UNTOUCHED
- Oracle: UNTOUCHED
- V2 database writes in C3: 0
- Operational/history rows exported: 0
- Credentials/auth records exported: 0

## Inventory outcome

- Master/config candidates evaluated: 40
- Production-safe datasets exported: 25
- Production-safe rows exported: 273
- Must-preserve datasets requiring DEV source: 13
- Review-required datasets excluded: 2 (`capacity_legacy_overrides`, `maintenance_members`)
- Operational/derived history domains excluded: 17

## DEV source required

`product_families`, `product_types`, `products`, `product_source_mappings`, `work_centers`, `operations`, `production_resources`, `routings`, `routing_operations`, `product_routing_assignments`, `source_task_mappings`, `source_operation_mappings`, `source_operational_code_mappings`.

These objects do not exist in production. Code contains historical seeds and synthetic fixtures, but they do not capture the approved current Product/Process/Routing assignments and therefore cannot be used as canonical data.

## Export reconciliation

| Dataset | Source | Exported | Natural key | Import status |
|---|---:|---:|---|---|
| `organizations` | 1 | 1 | `code` | BLOCKED |
| `production_processes` | 3 | 3 | `organization_id,code` | BLOCKED |
| `production_process_stages` | 10 | 10 | `production_process_id,sequence` | BLOCKED |
| `production_areas` | 6 | 6 | `organization_id,code` | BLOCKED |
| `production_stage_mappings` | 6 | 6 | `organization_id,stage_code` | BLOCKED |
| `production_stage_source_rules` | 7 | 7 | `organization_id,source_stage` | BLOCKED |
| `quantity_conversion_rules` | 1 | 1 | `organization_id,source_type` | BLOCKED |
| `shift_templates` | 3 | 3 | `organization_id,code` | BLOCKED |
| `shift_rules` | 21 | 21 | `organization_id,shift_code,day_of_week` | BLOCKED |
| `kpi_definitions` | 125 | 125 | `organization_id,code` | BLOCKED |
| `kpi_rate_rules` | 3 | 3 | `organization_id,process_code` | BLOCKED |
| `kpi_targets` | 0 | 0 | `organization_id,kpi_definition_id` | BLOCKED |
| `capacity_profiles` | 0 | 0 | `organization_id,name` | BLOCKED |
| `resource_capacity_rules` | 0 | 0 | `organization_id,resource_code` | BLOCKED |
| `staffing_layouts` | 1 | 1 | `organization_id,name` | BLOCKED |
| `staffing_layout_lines` | 12 | 12 | `staffing_layout_id,production_area_id,shift_template_id` | BLOCKED |
| `maintenance_asset_categories` | 14 | 14 | `organization_id,code` | BLOCKED |
| `maintenance_asset_prefixes` | 14 | 14 | `organization_id,category_id` | BLOCKED |
| `maintenance_component_prefixes` | 15 | 15 | `organization_id,component_type` | BLOCKED |
| `maintenance_assets` | 31 | 31 | `organization_id,asset_code` | BLOCKED |
| `maintenance_asset_installations` | 0 | 0 | `organization_id,movement_id` | BLOCKED |
| `maintenance_inventory_locations` | 0 | 0 | `organization_id,name` | BLOCKED |
| `maintenance_parts` | 0 | 0 | `organization_id,part_number` | BLOCKED |
| `maintenance_preventive_plans` | 0 | 0 | `organization_id,asset_id,title` | BLOCKED |
| `maintenance_preventive_plan_tasks` | 0 | 0 | `preventive_plan_id,sequence` | BLOCKED |

All exported files have SHA-256 checksums in `canonical-data/master-config/MASTER_CONFIG_MANIFEST.json`. Duplicate/FK validation and the two-run import were not executed because the mandatory Product/Routing source is unavailable; importing a partial configuration would violate the C3 pre-import gate.

## Intentionally excluded

- Oracle snapshots, sync state, release history, Production Demand, MOs and MO operations.
- Production events, KPI results, Machine Load, Release Queue and Product Mix projections.
- Production plans/history, downtime/work-order history, inventory transactions and attachments.
- Supabase Auth credentials, sessions, password hashes and secrets.
- `capacity_legacy_overrides` pending reusable-vs-temporary review.
- `maintenance_members` pending V2 identity mapping; production Auth IDs were not copied.

## Validation status

Baseline remains intact. C2.2 previously passed 176/176 application tests, lint, typecheck, database lifecycle/routing tests and build. C3 import/idempotency/post-import tests are BLOCKED because no V2 import was permitted.

## Required unblock action

Temporarily resume DEV for a read-only export of the 13 listed canonical Product/Routing datasets, then pause it again. After source counts, checksums, natural-key uniqueness and FKs pass, the combined package can be imported twice into V2.

**CANONICAL V2 MASTER CONFIG BLOCKED — DEV_SOURCE_REQUIRED**

## C3.1 DEV-only capture result

The approved project-slot rotation was completed on 18 September 2026. Canonical V2 was paused, DEV `tlflipdeahgwsueerkex` was restored, and production remained `ACTIVE_HEALTHY`. The DEV database was queried read-only through the Supabase Management API; no DEV DML, DDL or write RPC was executed.

All 13 required relations exist in DEV, but each contains zero rows:

| Dataset | DEV rows | Exported rows | Result |
| --- | ---: | ---: | --- |
| `product_families` | 0 | 0 | MISSING CONFIG |
| `product_types` | 0 | 0 | MISSING CONFIG |
| `products` | 0 | 0 | MISSING CONFIG |
| `product_source_mappings` | 0 | 0 | MISSING CONFIG |
| `work_centers` | 0 | 0 | MISSING CONFIG |
| `operations` | 0 | 0 | MISSING CONFIG |
| `production_resources` | 0 | 0 | MISSING CONFIG |
| `routings` | 0 | 0 | MISSING CONFIG |
| `routing_operations` | 0 | 0 | MISSING CONFIG |
| `product_routing_assignments` | 0 | 0 | MISSING CONFIG |
| `source_task_mappings` | 0 | 0 | MISSING CONFIG |
| `source_operation_mappings` | 0 | 0 | MISSING CONFIG |
| `source_operational_code_mappings` | 0 | 0 | MISSING CONFIG |

Package gate: MUST PRESERVE datasets `38`; complete exports `25`; missing exports `13`. Existing package remains `25` datasets / `273` rows. No empty DEV file was added as a false successful export. No V2 import was attempted, because the complete-package precondition failed.

The slot was restored safely after inspection: production `gdajktoqmajipivpdude` is `ACTIVE_HEALTHY`, V2 `saecycamkyvzzppxudzq` is `ACTIVE_HEALTHY`, and DEV `tlflipdeahgwsueerkex` is `INACTIVE`. Database writes to DEV, production and Oracle were all zero.

**CANONICAL V2 MASTER CONFIG BLOCKED — DEV_PRODUCT_ROUTING_CONFIG_EMPTY**

## C3.2 completion

### Reclassification of the 13 empty contracts

| Dataset | Readers | Writers/population | Empty valid | Production dependency | Classification |
| --- | --- | --- | --- | --- | --- |
| `product_families` | Product classification FK/RLS | Authorized admin/supervisor | Yes | None populated | `OPTIONAL_CONFIG` |
| `product_types` | Product classification FK/RLS | Authorized admin/supervisor | Yes | None populated | `OPTIONAL_CONFIG` |
| `products` | Demand bootstrap/routing resolver | Authorized admin/supervisor | Yes | Legacy operational pages use Oracle source views | `OPTIONAL_CONFIG` |
| `product_source_mappings` | Demand bootstrap and coverage views | Authorized admin/supervisor | Yes | Unmapped remains explicit | `OPTIONAL_CONFIG` |
| `work_centers` | Routing-operation projection | Authorized admin/supervisor | Yes | None populated | `OPTIONAL_CONFIG` |
| `operations` | Routing/source resolvers | Authorized admin/supervisor and isolated fixtures | Yes | None populated | `OPTIONAL_CONFIG` |
| `production_resources` | Resource/capacity references | Authorized admin/supervisor | Yes | None populated | `OPTIONAL_CONFIG` |
| `routings` | Routing resolver and production snapshots | Authorized admin/supervisor; revision clone function | Yes | No production canonical rows | `OPTIONAL_CONFIG` |
| `routing_operations` | Routing snapshot/resolver | Authorized admin/supervisor; revision clone/reorder functions | Yes | No production canonical rows | `OPTIONAL_CONFIG` |
| `product_routing_assignments` | Routing precedence resolver | Authorized admin/supervisor | Yes | Fallback remains unresolved when absent | `OPTIONAL_CONFIG` |
| `source_task_mappings` | Source-task process resolver | Authorized admin/supervisor | Yes | Unknown source task remains unresolved | `OPTIONAL_CONFIG` |
| `source_operation_mappings` | Source-evidence resolver | Explicit idempotent seed function/authorized management | Yes | Not needed before lifecycle execution | `RUNTIME_GENERATED` |
| `source_operational_code_mappings` | Operational-code resolution | Authorized canonical configuration | Yes | Unknown code remains unresolved | `OPTIONAL_CONFIG` |

No Oracle-sync path automatically invents Products or Routings. Routing rule definitions remain separate from routing resolution results. Product Mapping remains separate from Routing, blank Product remains distinct from finished Product, blank SKU alone cannot determine Routing, and unresolved inputs remain unresolved.

### Final package and import

- Total inventory: 40 datasets.
- `MUST_PRESERVE_WITH_ROWS`: 17 datasets / 273 rows.
- Required exports complete: 17/17; missing required exports: 0.
- Existing exported rows: 273; canonical import rows: 273; excluded exported rows: 0.
- Import run 1: 273 rows.
- Import run 2: 273 rows total; duplicates/inserts/deletes/updates: 0.
- Empty Product/Routing contracts after import: 0 rows, as required.
- Duplicate natural keys: 0; unresolved FKs: 0; unvalidated constraints: 0.
- Oracle rows imported: 0; fixture residue: 0.

### Validation

- Routing B-E: 26/26 PASS.
- Release lifecycle: 13/13 PASS.
- E6.8/E6.8.1: 26/26 PASS.
- Application tests: 176/176 PASS.
- Release Queue: 6/6 PASS; Machine Load: 14/14 PASS; Product Mix: 24/24 PASS.
- Lint: PASS; typecheck: PASS; production build: PASS.
- DEV and production: UNTOUCHED; Oracle: READ-ONLY / UNTOUCHED.

**CANONICAL V2 MASTER CONFIG COMPLETE — READY FOR ORACLE BOOTSTRAP**
