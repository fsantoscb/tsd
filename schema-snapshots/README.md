# Supabase Schema Snapshots

Captured: 2026-09-18T15:13:10.4716592+10:00

## Project identity

| Environment | Project ref | Capture state |
|---|---|---|
| DEV | `tlflipdeahgwsueerkex` | Captured while temporarily active; returned to paused state |
| PRODUCTION | `gdajktoqmajipivpdude` | Captured read-only; remained active |
| CANONICAL V2 | `saecycamkyvzzppxudzq` | Not captured in this phase; restored active |

## Method

- Supabase CLI version: `2.117.0`
- Supabase Management API: `POST /v1/projects/{ref}/database/query/read-only`
- Database role confirmed: `supabase_read_only_user`
- Schemas: `public`, `storage`
- SCHEMA ONLY
- NO DATA MODIFICATION
- NO ORACLE ACCESS

## Counts

| Environment | Tables/views | Columns | Constraints | Indexes | Functions | Views | Triggers | RLS policies |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| DEV | 181 | 2456 | 591 | 281 | 290 | 71 | 36 | 62 |
| PROD | 94 | 1274 | 332 | 183 | 234 | 23 | 13 | 0 |

## Files

- `dev_metadata.json`, `prod_metadata.json`: complete catalog metadata used for contract comparison.
- `dev_schema.sql`, `prod_schema.sql`: human-readable relation, column, constraint, and index inventory.
- `dev_functions.sql`, `prod_functions.sql`: exact function definitions.
- `dev_views.sql`, `prod_views.sql`: exact view definitions.
- `dev_rls.sql`, `prod_rls.sql`: RLS state and policies.

> The initial CLI `db dump` path was not used because it required Docker. All final snapshots came from the official read-only Management API endpoint.
