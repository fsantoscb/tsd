# Post-MO Grouping Regression Audit

## Verdict

REMEDIATED FOR CONTROLLED CONTINUATION

The critical findings below are retained as the audit record. Their remediation is documented in MO_POST_AUDIT_REMEDIATION_RESULT.md. The parallel Flow read model remains non-authoritative and legacy Flow remains active.

## P0 Critical

### MO-AUD-001

- Severity: P0 Critical
- Module: Oracle/WMS validation and Routing deviations
- Current Behaviour: Evidence is joined to production orders by organization and source_order_no, then matched to every snapshot operation with the same canonical operation.
- Expected Behaviour: One source event must update only the intended MO.
- Root Cause: Multiple MOs from one SO may share PICKING or DISPATCH, while source evidence has no source-line, product or Routing discriminator.
- Affected Files: supabase/migrations/202609130009_routing_phase_d_source_validation.sql:158, supabase/migrations/202609130009_routing_phase_d_source_validation.sql:211
- Recommended Fix: Extend source ingestion with a stable string source_order_line_id or another authoritative MO discriminator. Quarantine ambiguous evidence instead of applying it to multiple MOs.

## P1 High

### MO-AUD-002

- Severity: P1 High
- Module: Oracle sync and MO generation
- Current Behaviour: Oracle sync imports order, workbank, stock and audit datasets but no stable Sales Order line feed. No production adapter populates production_demand_lines.
- Expected Behaviour: Repeated source synchronization resolves products/routings per line and creates the same intended MO set.
- Root Cause: The source query and payload do not expose a stable source_order_line_id.
- Affected Files: apps/oracle-sync/src/source-reader.ts, apps/oracle-sync/src/sync.ts, supabase/migrations/202609130012_mo_grouping_correction.sql
- Recommended Fix: Define the authoritative Oracle Sales Order line key, ingest it as text and add an idempotent line upsert before enabling MO generation.

### MO-AUD-003

- Severity: P1 High
- Module: Planning and daily plans
- Current Behaviour: Planning selects and updates production_orders by order_no as if it were a unique Sales Order execution record.
- Expected Behaviour: One SO can expose and plan multiple MOs independently.
- Root Cause: Legacy Planning predates the MO boundary and conflates SO identity with execution identity.
- Affected Files: supabase/migrations/202609090005_phase5_planning.sql:39, supabase/migrations/202609090005_phase5_planning.sql:40, supabase/migrations/202609090005_phase5_planning.sql:67, supabase/migrations/202609090006_phase6_daily_plans.sql:6, apps/web/lib/planning.ts
- Recommended Fix: Keep the legacy compatibility path until Planning migration; then select by MO UUID/mo_number and group display by source_order_no.

### MO-AUD-004

- Severity: P1 High
- Module: Production Execution UI
- Current Behaviour: List and detail read one product from production_orders.product_id. A valid multiproduct MO has a null header product, displays Unmapped and does not show its lines.
- Expected Behaviour: MO detail shows MO, parent SO, all SO lines/products and product mix.
- Root Cause: Phase C UI retained the one-product header assumption.
- Affected Files: apps/web/lib/execution-control.ts:3, apps/web/lib/execution-control.ts:4, apps/web/app/production/execution/page.tsx:1, apps/web/app/production/execution/[id]/page.tsx:1
- Recommended Fix: Query manufacturing_order_lines and display MO/SO identities separately.

### MO-AUD-005

- Severity: P1 High
- Module: Quantity and Product Mix
- Current Behaviour: Planned header quantity is recalculated from lines, but actual_quantity has no equivalent line-to-header invariant.
- Expected Behaviour: Governed MO actual equals the accepted actual line grain, or is explicitly unavailable.
- Root Cause: Only planned_quantity has a roll-up trigger; execution actual remains operation/header based.
- Affected Files: supabase/migrations/202609130012_mo_grouping_correction.sql:102, supabase/migrations/202609130009_routing_phase_d_source_validation.sql:219
- Recommended Fix: Define actual attribution and enforce one canonical calculation before using MO actuals in Flow/KPIs.

### MO-AUD-006

- Severity: P1 High
- Module: Database integrity
- Current Behaviour: production_demand_lines stores routing_id and routing_revision_id but does not prove they represent the same Routing lineage.
- Expected Behaviour: Every line and its parent MO share one valid organization-owned effective Routing revision.
- Root Cause: Both fields reference routings independently and no lineage constraint/function exists.
- Affected Files: supabase/migrations/202609130012_mo_grouping_correction.sql:23
- Recommended Fix: Clarify whether routing_id is master identity or remove it; otherwise add a canonical Routing master key and enforce revision ownership.

### MO-AUD-007

- Severity: P1 High
- Module: RLS/security validation
- Current Behaviour: RLS policies exist on all new tables, but automated tests do not exercise cross-organization reads/writes for demand and MO lines.
- Expected Behaviour: Organization isolation and unauthorized mutations are proven by tests.
- Root Cause: New regression tests focus on grouping integrity, not authenticated RLS roles.
- Affected Files: supabase/migrations/202609130012_mo_grouping_correction.sql:180, supabase/tests/mo_grouping_correction.sql
- Recommended Fix: Add explicit admin/viewer/operator cross-organization pgTAP coverage before promotion.

## P2 Medium

### MO-AUD-008

- Severity: P2 Medium
- Module: Demand exceptions
- Current Behaviour: Exception types and table exist, but unmapped/inactive/invalid demand does not automatically create a production_demand_exceptions record.
- Expected Behaviour: Valid Routing groups create MOs and every rejected line creates a setup exception.
- Root Cause: No canonical line-ingestion function exists yet.
- Affected Files: supabase/migrations/202609130012_mo_grouping_correction.sql
- Recommended Fix: Implement exception creation in the future source-line adapter.

### MO-AUD-009

- Severity: P2 Medium
- Module: MO identity
- Current Behaviour: Compatibility permits historical routed records without mo_number; only the creation function guarantees a number for new MOs.
- Expected Behaviour: New Manufacturing Orders always have a stable MO number, while historical exceptions are classified.
- Root Cause: A strict global constraint would break Phase C/E/F1 fixtures and existing headers.
- Affected Files: supabase/migrations/202609130013_mo_grouping_compatibility.sql:2
- Recommended Fix: Add a lifecycle marker or partial constraint distinguishing canonical MOs from compatibility records.

### MO-AUD-010

- Severity: P2 Medium
- Module: Cancellation and source changes
- Current Behaviour: Post-start quantity changes are quarantined, but Sales Order cancellation is not implemented in the MO line ingestion path.
- Expected Behaviour: Pre-start MOs may cancel; in-progress MOs preserve history and raise an exception.
- Root Cause: Source-line/cancellation adapter is pending.
- Affected Files: supabase/migrations/202609130012_mo_grouping_correction.sql
- Recommended Fix: Add cancellation handling only after authoritative source status mapping is agreed.

## P3 Low

### MO-AUD-011

- Severity: P3 Low
- Module: Terminology and search
- Current Behaviour: Execution pages say Order/Production Order and search only order_no.
- Expected Behaviour: Preferred UI terminology is Manufacturing Order/MO, searchable by mo_number and source_order_no.
- Root Cause: Transitional table/UI naming.
- Affected Files: apps/web/app/production/execution/page.tsx:1, apps/web/lib/execution-control.ts:3
- Recommended Fix: Update terminology during the controlled Execution UI migration.

## Confirmed compatible controls

- Database uniqueness prevents duplicate SO + Routing revision + split MOs.
- MO line trigger rejects cross-SO and cross-Routing ownership.
- Source-line identity is unique per organization, source system, SO and source line.
- Negative quantities are rejected.
- Routing operation snapshots remain immutable.
- Product composition is preserved in manufacturing_order_lines and v_manufacturing_order_product_mix.
- Oracle events for a different Sales Order do not match another SO because the resolver includes source_order_no.
- Legacy Dashboard, Flow, KPIs, Aged Orders, Ready To Lift, DTG and UP workbanks remain isolated from the new line tables.

## Automated coverage

Existing focused database tests cover:

- one SO with multiple Routings;
- two SOs using the same Routing;
- MO planned line totals;
- planned Product Mix preservation;
- immutable Routing snapshot;
- pre/post-start quantity changes;
- cross-SO line protection;
- idempotent repeated grouping.

Missing blocking coverage:

- same-SO, multiple-MO source-event disambiguation;
- new-table RLS by role and organization;
- live idempotent Oracle line ingestion, because no authoritative source-line feed exists.

## Blocking issues

1. MO-AUD-001: ambiguous same-SO evidence can update multiple MOs.
2. MO-AUD-002: no authoritative Sales Order line ingestion.
3. MO-AUD-003: Planning cannot yet use multiple MOs per SO.
4. MO-AUD-004: Execution detail does not preserve MO to SO to lines/products drilldown.
5. MO-AUD-005: actual quantity grain and roll-up are not governed.
6. MO-AUD-006: Routing master/revision lineage is not enforced on demand lines.
7. MO-AUD-007: new-table RLS regression coverage is incomplete.
