# Routing Architecture Phase F1 Result

## Delivered

- Parallel canonical current-operation and progress views.
- Canonical Flow aggregation based on Production Order Operations.
- Same-snapshot legacy-versus-routing reconciliation for seven stages.
- Flow reconciliation strip with cutover status and diagnostics.
- Database coverage for sequence, no double counting, WIP quantity and stage completeness.

## Views

- `v_production_order_current_operation`
- `v_production_order_progress`
- `v_production_flow_canonical`
- `v_production_flow_legacy_snapshot`
- `v_production_flow_routing_reconciliation`

## UI and boundaries

`/production/flow` continues to render legacy cards and drilldowns. The parallel reconciliation is displayed below them. Planning, Capacity and KPIs were not migrated. Legacy logic was not removed. Production was not changed. Phase F2 was not started.

## Unresolved

- Canonical execution data is empty locally.
- Product/routing assignment and source mappings require a governed pilot.
- Dispatch throughput semantics require date and actual-quantity acceptance.
- Screen Print remains manual without authoritative evidence.

## Validation

- Local migration: PASS.
- Database/RLS tests: PASS, 31 tests.
- Lint: PASS.
- Typecheck: PASS.
- Unit tests: PASS, 133 tests.
- Production build: PASS, 46 routes.
- Authenticated Flow smoke test: PASS.
- Cutover gate: BLOCKED by explained missing canonical pilot data.

## Controlled continuation update

Created v_manufacturing_order_current_operation, v_manufacturing_order_progress, v_manufacturing_order_routing_status, v_flow_operation_summary and v_flow_operation_detail. Operation drilldown preserves MO, SO, customer, Routing revision and Product Mix. Flow cards aggregate remaining units while counting MOs and distinct Sales Orders separately. Quantity progress and Routing progress remain separate.

Validation: lint PASS; typecheck PASS; web tests 71 PASS; database tests 52 PASS; production build PASS with 47 routes.

## Final verdict

FLOW ROUTING MODEL NOT READY FOR CUTOVER

Blocking differences:

- DTG Picking: 40 legacy orders / 4,824 units have no canonical MO.
- DTG Printing: 121 legacy orders / 8,614 units have no canonical MO.
- DTG Putwall: 18 legacy orders / 2,227 units have no canonical MO.
- UP Picking: 60 legacy orders / 4,426 units have no canonical MO.

Legacy Flow remains available and authoritative. Phase F2 was not started.
