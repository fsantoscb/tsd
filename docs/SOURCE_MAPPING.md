# Production Flow Source Mapping
- DTG Picking: workbank `queue = SP11` (validated).
- DTG Printing: workbank `queue = PCOR` (validated).
- DTG Putwall: workbank `from_zone = PWL1` (validated).
- DTG Dispatch: audit `to_location = DTGMOVE` (requires validation).
- UP Picking: stock `location = UNDERPRINT` (validated against existing workbook logic).
- UP Printing: workbank `from_location ends_with UP` (requires validation; never uses broad contains matching).
- UP Dispatch: audit `to_location = UPMOVE` (requires validation).
- Screen Print: manual `screen_print_jobs`; no Oracle mapping is claimed.

## Canonical Phase D layer

Source values are now configuration in `source_operation_mappings`; they must not be copied into new frontend or KPI logic. `v_source_operation_evidence` applies the mappings to Audit, Workbank and Stock records. `resolve_production_order_actual_state` attaches evidence to the immutable Production Order routing snapshot and records deviations instead of changing the expected route.

DTGMOVE, UPMOVE and the UP location suffix remain provisional semantics pending Phase E reconciliation. The resolver records them deterministically but the legacy operational pages remain authoritative until parity is approved.
