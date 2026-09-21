# Legacy Failover Reconciliation

## Scope

ERP-owned state was compared read-only between legacy Production `gdajktoqmajipivpdude` and replacement Canonical V2 `eziirebccovlvhaonsgw`. Only missing maintenance history was copied from legacy to replacement. Legacy remained unchanged.

## Reconciliation

| Domain | Legacy | Replacement result | Resolution |
| --- | ---: | ---: | --- |
| Maintenance assets | 31 | 31 | Same identities; replacement retained newer operational state |
| Maintenance work orders | 4 | 6 | Original four preserved; two legitimate V2 work orders retained |
| Work-order history | 6 | 11 | Original six preserved; five V2 lifecycle events retained |
| Work-order comments | 4 | 4 | Exact identity/state parity |
| Downtime events | 3,243 | 3,244 | All legacy events preserved; one legitimate V2 event retained |
| Maintenance audit log | 3,318 | 4,221 | All legacy audit records preserved; 903 V2 audit records retained |
| Maintenance members | 1 | 3 | Legacy auth identity not copied; approved replacement identities retained |
| Screen Print jobs | 6 | 0 | Six duplicate manual test jobs remain classified OBSOLETE and were not migrated |
| Capacity overrides | 3 | 3 | Same identities and business values retained |

## Integrity

- Missing legacy downtime IDs after merge: 0
- Missing legacy audit IDs after merge: 0
- Duplicate downtime source keys: 0
- Orphan downtime assets: 0
- Orphan downtime work orders: 0
- Maintenance audit trigger: enabled
- Screen Print current Workbank (`PAK7`): 0
- Screen Print legacy test jobs migrated: 0
- Second merge execution pending inserts: 0

## Authority decisions

- Replacement state wins where it is newer and is supported by V2 lifecycle records.
- Historical ERP-owned maintenance records are additive and were preserved with original IDs.
- Authentication memberships are environment-specific and are not copied across Supabase Auth projects by user ID.
- Screen Print current load remains Workbank-only; obsolete order `123` test jobs are not production state.

## Gate

Legacy failover reconciliation: PASS.
