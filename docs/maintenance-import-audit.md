# Maintenance historical import audit

## Current structure

The ERP uses maintenance_assets as its central asset registry. Asset codes are unique within an organization. Structural components currently use parent_asset_id. Operational maintenance uses maintenance_work_orders and maintenance_downtime_events.

## Conflict found

The component generator encoded the parent machine in every component code. That is valid for fixed subsystems, but invalid for interchangeable physical printheads. The existing downtime table did not distinguish where an event happened from which physical component failed.

## Implemented architecture

- maintenance_assets.asset_kind distinguishes FIXED and MOVABLE.
- Physical printheads use permanent global PH-### identities and no parent asset.
- maintenance_asset_installations records the temporal PH-to-DTG relationship.
- Database exclusion rules prevent overlapping installations and the partial unique index prevents two active hosts.
- Existing maintenance_downtime_events is extended rather than replaced.
- host_asset_id drives machine reliability.
- affected_asset_id drives physical printhead reliability.
- downtime_minutes from the approved workbook is authoritative.
- Original and corrected duration fields remain independently auditable.
- Unresolved historical PH labels remain in historical_asset_reference.

## Risks and controls

- Workbook example PH rows are excluded.
- Missing required host or structural assets block commit.
- Unresolved PH references are warnings and remain unassigned.
- The source-system/source-key unique index makes import idempotent.
- The database function executes staging and final writes in one transaction.

## Rollback

The migration is additive. A historical batch can be isolated by its source_system and source_key without changing existing IDs. No production history is truncated or deleted by the migration or importer.
