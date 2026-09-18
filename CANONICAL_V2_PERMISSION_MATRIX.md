# Canonical V2 Permission Matrix

Canonical membership source: `maintenance_members`, scoped by `organization_id` and `user_id`.

Legacy roles `maintenance` and `viewer` remain accepted for compatibility but are not assigned to new production users. New assignments use `operator`, `supervisor`, `manager`, or `admin`.

| Capability | Operator | Supervisor | Manager | Admin |
| --- | --- | --- | --- | --- |
| DASHBOARD_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| ORDERS_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| PRODUCTION_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| PRODUCTION_OPERATE | ALLOW | ALLOW | ALLOW | ALLOW |
| MACHINE_LOAD_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| RELEASE_QUEUE_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| PERFORMANCE_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| SCREEN_PRINT_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| SCREEN_PRINT_OPERATE | ALLOW | ALLOW | ALLOW | ALLOW |
| MAINTENANCE_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| MAINTENANCE_CREATE | ALLOW | ALLOW | ALLOW | ALLOW |
| MAINTENANCE_OPERATE | ALLOW | ALLOW | ALLOW | ALLOW |
| MAINTENANCE_COMPLETE | DENY | ALLOW | ALLOW | ALLOW |
| MAINTENANCE_CANCEL | DENY | DENY | ALLOW | ALLOW |
| MAINTENANCE_DELETE | DENY | DENY | DENY | ALLOW |
| MAINTENANCE_REOPEN | DENY | ALLOW | ALLOW | ALLOW |
| ASSET_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| ASSET_EDIT | DENY | DENY | ALLOW | ALLOW |
| PREVENTIVE_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| PREVENTIVE_OPERATE | DENY | ALLOW | ALLOW | ALLOW |
| PREVENTIVE_CONFIGURE | DENY | DENY | ALLOW | ALLOW |
| CAPACITY_READ | ALLOW | ALLOW | ALLOW | ALLOW |
| CAPACITY_CONFIGURE | DENY | DENY | ALLOW | ALLOW |
| CANONICAL_CONFIGURE | DENY | DENY | ALLOW | ALLOW |
| USER_ADMIN | DENY | DENY | DENY | ALLOW |
| SYSTEM_ADMIN | DENY | DENY | DENY | ALLOW |
| SOURCE_DATA_MUTATE | DENY | DENY | DENY | DENY |
| SYNC_CONTROL | DENY | DENY | DENY | DENY |

Service-role ingestion is separate from human authorization. It may mutate source/snapshot/sync state through server-only paths and is never exposed to the browser.
