# Canonical V2 Baseline Static Validation

## Identity

| Item | Value |
|---|---|
| Worktree | `C:\Projects\tsd-canonical-v2` |
| Branch | `canonical-v2` |
| Target | `CANONICAL_V2` |
| Project ref | `saecycamkyvzzppxudzq` |
| DEV ref | `tlflipdeahgwsueerkex` |
| Production ref | `gdajktoqmajipivpdude` |

The three project refs are distinct.

## Contract inventory

| Check | Result |
|---|---:|
| Direct runtime dependencies | 86 |
| Direct contracts marked complete | 86 |
| Current `001` direct-name coverage | 5 / 86 |
| Executable merged contracts missing | 2 |
| E5/E6 support-object manifest | Incomplete |
| Exact PostgreSQL typmod/grant metadata | Incomplete |

## Blocking contracts

### `public.ingest_sync_batch`

The canonical contract is a merge of DEV transaction/idempotency behavior and PROD release-line/source coverage. The manifest records the required behavior but no complete executable PL/pgSQL body. Neither source definition can be copied without dropping approved behavior from the other.

### `public.v_current_orders`

The manifest requires DEV canonical route naming plus PROD release-source evidence. It records the output and semantic contract but no complete executable `CREATE VIEW` definition.

### E5/E6 supporting architecture

The direct application list does not provide exact canonical object contracts for the complete Production Demand, demand mapping, Manufacturing Order, Routing/Process, lifecycle audit, revocation/reactivation and reconciliation dependency graph required by C2 fixtures.

### Snapshot fidelity

The captured metadata contains column data type names, defaults, constraints, indexes, functions, views, triggers and RLS. It does not contain sufficient PostgreSQL typmod/collation/grant detail to prove byte-for-byte exact reconstruction of all table contracts.

## Result

Static validation failed before any database write. The clean reset, migration application, post-apply reconciliation, fixtures and application-against-V2 checks were intentionally not started.

`DATABASE WRITES = 0`

`ORACLE WRITES = 0`

## C2.1A executable closure

- `public.ingest_sync_batch`: executable merged SQL at `canonical-sql/ingest_sync_batch.sql`.
- `public.v_current_orders`: executable merged SQL at `canonical-sql/v_current_orders.sql`.
- E5/E6 transitive support graph: `canonical-v2-support-objects.json` and `CANONICAL_V2_SUPPORT_OBJECTS.md`.
- Canonical support required: 87 objects.
- Platform objects: 5.
- Legacy unused: 29.
- Unresolved SQL references: 0.
- Semantically relevant typmod/collation/grant blockers: 0.

No database operation was performed and `001_canonical_baseline.sql` was not modified.

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

