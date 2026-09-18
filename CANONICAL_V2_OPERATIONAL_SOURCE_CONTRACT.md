# Canonical V2 Operational Source Contract

## Decision

Canonical V2 uses two independent operational authorities. They describe different business events and must not be joined or summed unless a future, explicit source key is proven.

| Domain | Authoritative source | Grain | Quantity meaning |
| --- | --- | --- | --- |
| Release Queue | Oracle Sales Order Lines | `ORDER_NO + LINE_NUMBER` | Released/not-approved line process quantity and release blockers |
| Current production workload | Oracle/WMS Workbank | `WB_ROWID` exposed as `source_row_id` | Current open process quantity |
| Screen Print production | Oracle/WMS Workbank `PAK7` | `WB_ROWID` exposed as `source_row_id` | Make-to-stock current operational load |

## Oracle Sales Order Line authority

Oracle Sales Order Lines are authoritative for:

- release state;
- Sales Order Line identity;
- line-level routing/process evidence;
- release blockers and diagnostic state;
- the Release Queue and Not Approved population.

The canonical read models are `v_release_queue` and `v_machine_load_not_approved`. Workbank presence must never be interpreted as release approval.

This release authority applies to order-driven processes such as DTG. Screen Print is MAKE TO STOCK: Oracle Sales Order release is not applicable, Screen Print must never enter Release Queue, and absence of a Sales Order release must never classify a Screen Print Workbank row as Not Approved.

## Workbank authority

Workbank is authoritative for:

- current workload;
- current queue/location/task evidence;
- current process quantity;
- DTG and Underprint operational queues;
- Screen Print production identified by Workbank queue/task `PAK7`;
- Machine Load and Product Mix demand currently visible to operations.

The source is Oracle `IS_WORKBANK_V`, ingested into `source_workbank_items` and exposed through `v_current_workbank`. The immutable source identity is `source_row_id` (`WB_ROWID`). The canonical quantity is `production_units`, with semantics `CURRENT_OPEN_PROCESS_QUANTITY`.

## Non-additivity rule

Release Queue quantity and Workbank quantity must never be added. They are neither alternate copies of one fact nor successive snapshots at a shared grain. Release Queue represents line-level release state; Workbank represents current open operational work.

No authoritative Sales Order Line-to-Workbank row join is currently proven. `ORDER_NO + SKU`, order-only matching, description matching, and aggregate reconciliation are not canonical identity keys.

## Derived operational modules

| Module | Canonical source/read model |
| --- | --- |
| Production / DTG / Underprint | `v_current_orders`, `v_current_workbank`, `v_current_stock`, `v_dtg_operational_orders`, `v_up_operational_orders` |
| Release Queue | `v_release_queue` |
| Machine Load | `v_current_workbank`, `v_current_stock`, `v_current_orders`, `v_machine_load_not_approved`; Screen Print comes only from Workbank `PAK7` |
| Product Mix | Workbank-derived operational records and deterministic product-mix rules |
| Performance | DTG/Underprint operational views, audit history, Workbank `PAK7` Screen Print load and capacity |
| Maintenance | Maintenance domain tables; independent from Oracle release and Workbank authority |

## Demand and Manufacturing Orders

The current live operational modules contain no runtime dependency on Production Demand or Manufacturing Orders. These objects remain preserved as a `DEFERRED_CANONICAL_LAYER` and are not a cutover prerequisite for the current operational UI.

They must not be populated by joining Release Queue to Workbank without a proven line-level identity. Their future activation requires an explicit contract for finished product, blank product, operational code, routing and manufacturing process.

## Snapshot semantics

`v_current_orders`, `v_current_workbank` and `v_current_stock` expose the latest completed snapshot. A completed sync is a full replacement snapshot for those three datasets, not an append-only operational history.

`source_audit_events` is append-only history. `screen_print_jobs`, capacity configuration and maintenance transactions are application-owned data and are not replaced by an Oracle snapshot.

`screen_print_jobs` is not a Screen Print demand authority. If retained, it may hold execution/history state only and must reconcile to Workbank without adding quantity. Current Screen Print load is exactly the current `PAK7` Workbank population.

An empty completed snapshot is materially different from a failed sync and must not be silently substituted for the last non-empty snapshot. Scheduled V2 ingestion must not be activated until the V2 endpoint exists, three consecutive complete runs preserve expected counts, and all non-Oracle live data required by parity has been migrated.

## Safety boundaries

- Oracle is permanently read-only.
- DEV and production are not migration targets for Canonical V2 work.
- Production credentials must not be accepted by V2 development scripts.
- Operational parity is measured per source domain; totals across independent authorities are prohibited.
