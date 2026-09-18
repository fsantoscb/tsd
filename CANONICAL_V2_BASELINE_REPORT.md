# Canonical V2 Baseline Report

## Target identity

| Environment | Project ref | State | Action |
| --- | --- | --- | --- |
| DEV | `tlflipdeahgwsueerkex` | Paused / preserved | None |
| Production | `gdajktoqmajipivpdude` | Active | None |
| Canonical V2 | `saecycamkyvzzppxudzq` | Active, linked to V2 worktree | Schema target only |

`TARGET = CANONICAL_V2`

## Baseline scope

The new `001_canonical_baseline.sql` defines the clean foundation for:

- tenancy and role-aware RLS;
- immutable source snapshot evidence;
- Product Master, operations, work centres and resources;
- Routing Master and immutable revisions;
- source task/process resolution;
- line-level release lifecycle and audit;
- Production Demand;
- Manufacturing Orders grouped by one Sales Order plus one Routing;
- immutable Manufacturing Order operation snapshots;
- canonical quantity and progress read models.

No data is seeded or imported. The migration does not contain legacy migration history.

## Canonical invariants encoded

- One Sales Order plus one Routing identifies at most one Manufacturing Order.
- Different Sales Orders cannot share a Manufacturing Order.
- Routing operations are copied to immutable MO operation snapshots.
- Only active `READY` or `GROUPED` demand contributes to canonical MO quantity.
- Revoked/inactive demand contributes zero.
- Source evidence retains snapshot/run provenance.
- Oracle is not addressed by the database migration.

## Known incomplete application contracts

The baseline is not yet a complete replacement for the current production schema. These domains remain to be modelled before an application cutover or empty-state UI validation can pass:

- current operational workbank/reconciliation projections;
- sync control RPCs and heartbeat;
- planning and daily plans;
- capacity/staffing configuration;
- KPI and Deputy labour domains;
- Release Queue and Machine Load projections;
- maintenance master, transactions, history and secure storage;
- explicit E6 lifecycle functions and transactional fixtures A-G.

These are blockers, not silently omitted approvals.

## Master/config migration plan

1. Export approved master/config datasets read-only with source counts and checksums.
2. Load organization and membership identity mappings.
3. Load Product Families, Product Types and Products.
4. Load source-product mappings with confidence/provenance.
5. Load work centres, operations and production resources.
6. Load Routings, released revisions and ordered operations.
7. Load Product-to-Routing and source-task mappings.
8. Load shift, capacity, KPI and maintenance configuration only after their canonical tables are approved.
9. Reconcile natural keys, duplicates and references before any Oracle bootstrap.

No import is authorized in this phase.

## Oracle safety audit

The application Oracle connector must remain limited to connection/session setup and `SELECT` queries. Any Oracle DML or DDL path is a hard stop. The audit is separate from SQL migrations because Oracle is not contacted by the V2 baseline.

## Gate

The V2 project exists and is isolated, but the canonical baseline is incomplete until all application contracts and E6 fixtures are represented and validated. It must not be used for deployment or source bootstrap yet.

**CANONICAL V2 BASELINE BLOCKED**

## Baseline blocker

### BASELINE BLOCKER

- `C. MISSING CANONICAL OBJECT`: the applied baseline does not yet define the documented operational, sync, planning, capacity, KPI/labour, Release Queue, Machine Load and maintenance contracts required by the current application.
- `D. APPLICATION DEPENDENCY`: a production build succeeds, but dynamic pages cannot be certified in a database-backed empty state until those relations, views and RPCs exist with approved semantics.
- `F. TEST / BUILD FAILURE`: resolved. The initial build failure was caused only by missing V2-local Supabase environment variables.

### ROOT CAUSE

The first baseline intentionally implemented only tenancy, source evidence, Product/Routing Master, release demand and Manufacturing Order foundations. The repository branch does not contain the validated E5/E6 lifecycle functions or fixtures A-G, and the approved task explicitly prohibits starting a new architecture investigation or copying legacy migrations. Creating placeholder relations/RPCs would produce a false-positive baseline and could encode unapproved business behaviour.

### FIX

- Positively verified target `saecycamkyvzzppxudzq` as Canonical V2, distinct from DEV and production.
- Applied `001_canonical_baseline.sql` successfully to Canonical V2 only.
- Added ignored V2-local web environment configuration using the V2 URL and API keys.
- Preserved all legacy migrations as non-executable reference; none were applied.
- Did not add speculative compatibility stubs or unapproved E6 behaviour.

### VALIDATION

| Check | Result |
| --- | --- |
| Baseline migration | PASS |
| Target identity | PASS (`saecycamkyvzzppxudzq`) |
| Lint | PASS |
| Typecheck | PASS |
| Application tests | 176/176 PASS |
| Production build | PASS |
| Full database-backed application empty state | BLOCKED by missing canonical contracts listed above |
| DEV | UNTOUCHED |
| Production | UNTOUCHED |
| Oracle | READ-ONLY / UNTOUCHED |

### Required unblock input

Provide the already validated E5/E6 canonical SQL contracts/fixtures and approve canonical definitions for the documented current-application domains. Without those contracts, resolving the remaining blocker would require a new architecture phase, which is outside this task.

## Phase C2 safety gate

The definitive-baseline attempt stopped before editing `001` or resetting V2.

### Evidence

- Worktree: `C:\Projects\tsd-canonical-v2`
- Branch: `canonical-v2`
- Target: `CANONICAL_V2`
- Project ref: `saecycamkyvzzppxudzq` (different from DEV and production)
- Direct application database/storage/RPC names detected: 65
- Current baseline names detected from that surface: 5
- Individually named contracts detected in `CANONICAL_V2_CONTRACTS.md`: 2

The C1 document describes many domains at family level but does not specify the required per-object columns, primary keys, foreign keys, unique rules, function signatures, view outputs and RLS policies. The missing exact contracts include sync/freshness, planning, capacity, KPI/labour, Release Queue, Machine Load projections and the full maintenance domain.

### Decision

No speculative SQL was generated. V2 was not reset and no database operation was performed. The existing applied baseline remains intact pending a complete per-object contract.

## Phase C2 definitive baseline attempt

### Static validation result

`FAIL` before database write.

The target identity was proven as:

- worktree: `C:\Projects\tsd-canonical-v2`;
- branch: `canonical-v2`;
- linked project: `saecycamkyvzzppxudzq`;
- DEV: `tlflipdeahgwsueerkex`;
- production: `gdajktoqmajipivpdude`.

The linked target is distinct from DEV and production. No reset or SQL apply was attempted.

### Exact technical blockers

1. `public.ingest_sync_batch` is marked `MERGED_CANONICAL`, but its `canonical_v2_contract` contains a signature and prose body contract rather than an executable function definition. The approved contract requires behavior from both DEV and PROD, so copying either function would violate C1.3.
2. `public.v_current_orders` is marked `MERGED_CANONICAL`, but its `canonical_v2_contract` contains output columns and a prose definition contract rather than executable view SQL.
3. `public.source_workbank_items` has a merged table/index contract, but the approved E5/E6 functions and views require supporting source and mapping objects that are not represented as exact canonical objects in the 86-object manifest.
4. The 86 objects are direct application dependencies. Required E5/E6 support objects such as `production_demand_lines`, `production_demand_release_events`, `manufacturing_order_lines`, `production_orders`, Routing/Process relations, lifecycle functions, triggers and reconciliation views are not included as exact object-level canonical contracts in `canonical-v2-object-contracts.json`.
5. Snapshot column metadata does not contain PostgreSQL `format_type(atttypid, atttypmod)`, character length, numeric precision/scale, collation, or complete grants. It therefore cannot reconstruct every table type and privilege exactly without inference.

### Safety decision

- `001_canonical_baseline.sql` was not modified.
- V2 was not reset.
- No migration was applied.
- No fixture was executed.
- DEV and production were not accessed or modified.
- Oracle was not accessed and remains read-only.

Generating SQL despite these gaps would violate the C2 requirements that contracts be authoritative, that no speculative design be introduced, and that contract collisions stop execution before reset.

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

