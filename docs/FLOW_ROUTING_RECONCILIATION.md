# Flow Routing Reconciliation

## Authority

Legacy Flow remains operationally authoritative. Phase F1 adds a parallel Routing Flow read model and does not remove or rewrite the legacy source rules.

## Source mapping

| Canonical process | Canonical operation | Oracle/WMS evidence |
|---|---|---|
| DTG | PICKING | WORKBANK queue SP11 |
| DTG | DTG_PRINT | WORKBANK queue PCOR |
| DTG | PUTWALL | WORKBANK from_zone PWL1 |
| DTG | DISPATCH | AUDIT to_location DTGMOVE |
| UNDERPRINT | PICKING | STOCK location UNDERPRINT |
| UNDERPRINT | UNDERPRINT | WORKBANK from_location suffix UP |
| UNDERPRINT | DISPATCH | AUDIT to_location UPMOVE |
| SCREEN_PRINT | Routing operations | Manual validation where no governed evidence exists |

These values remain source evidence and are not canonical operation identifiers.

## Snapshot reconciliation

The local Oracle snapshot contains 1,153 source orders. The local canonical execution tables contain no Production Orders, Operations, active source mappings or completed reconciliation run for the validation organization. Material differences therefore remain and cutover is blocked.

The live comparison is exposed by `v_production_flow_routing_reconciliation` and `/production/flow`. It reports units and orders for all seven required stages.

## Controls checked

- One canonical row per Production Order current operation prevents double counting.
- Current and next operations come from the immutable routing snapshot.
- Open deviations, orders without routing, products without routing and active mappings are surfaced.
- Unmapped source values are never guessed in React.
- Dispatch is throughput while upstream stages are WIP; its quantity/date parity remains an acceptance item.

## Cutover decision

**BLOCKED.** Legacy cards and drilldowns remain active pending canonical pilot data and signed reconciliation.

## Observed local comparison — 2026-09-13

| Stage | Legacy Units | Routing Units | Difference | Legacy Orders | Routing Orders | Difference |
|---|---:|---:|---:|---:|---:|---:|
| DTG Picking | 4,824 | 0 | -4,824 | 40 | 0 | -40 |
| DTG Printing | 8,614 | 0 | -8,614 | 121 | 0 | -121 |
| DTG Putwall | 2,227 | 0 | -2,227 | 18 | 0 | -18 |
| DTG Dispatch | 0 | 0 | 0 | 0 | 0 | 0 |
| UP Picking | 4,426 | 0 | -4,426 | 60 | 0 | -60 |
| UP Printing | 0 | 0 | 0 | 0 | 0 | 0 |
| UP Dispatch | 0 | 0 | 0 | 0 | 0 | 0 |

The zero Routing values are explained by the absence of canonical Production Orders in the local organization. Zero-versus-zero rows do not override the global blocked decision.

## Controlled continuation reconciliation

| Stage | Legacy units | Routing units | Difference | Legacy orders | Routing MOs | Difference | Category |
|---|---:|---:|---:|---:|---:|---:|---|
| DTG Picking | 4,824 | 0 | -4,824 | 40 | 0 | -40 | MISSING_MO |
| DTG Printing | 8,614 | 0 | -8,614 | 121 | 0 | -121 | MISSING_MO |
| DTG Putwall | 2,227 | 0 | -2,227 | 18 | 0 | -18 | MISSING_MO |
| DTG Dispatch | 0 | 0 | 0 | 0 | 0 | 0 | MATCH |
| UP Picking | 4,426 | 0 | -4,426 | 60 | 0 | -60 | MISSING_MO |
| UP Printing | 0 | 0 | 0 | 0 | 0 | 0 | MATCH |
| UP Dispatch | 0 | 0 | 0 | 0 | 0 | 0 | MATCH |

The same local source snapshot was used for both models. No double counting was detected because the canonical side contains no generated MOs. Zero/zero matches do not authorize cutover.
