# System Audit Fix Plan

> Execution status: completed on 2026-09-13 for the identified production defects. Validation and residual governance actions are recorded in `docs/SYSTEM_AUDIT_COMPLETION.md`.

No phase should begin until the audit and exact deployed source are reviewed.

| Phase | Fix | Affected files/systems | Migration | Risk | Required tests | Blast radius |
|---|---|---|---|---|---|---|
| A | Recover exact production source and specifications; establish commit-based deploy | Vercel project, repository, all deployed modules | No | High operational, no data change | Reproducible clean build; route inventory | Entire ERP |
| A | Bind each ingest credential to organization and remove body authority | ingest API, agent config, credential store | Agent credential table | High | Cross-org negative tests, rotation/replay tests | Ingestion/security |
| A | Enforce batch/item organization consistency | all source tables and ingest RPC | Composite unique keys/FKs; validation constraints | High; profile existing data first | Migration preflight, FK and rollback tests | Source data |
| A | Replace optional email gate with RBAC and mandatory org context | auth, server repository, admin routes | Membership/role tables and RLS policies | High | Role matrix and RLS tests | All authenticated pages |
| B | Implement one canonical production-flow classifier | connector, SQL/domain layer, shared types | Mapping/config table or function | High | Positive/negative DTG, UP, Screen Print fixtures | All production metrics |
| B | Centralize production-unit policy and preserve source evidence | mapping, schemas, source tables | Mapping version, zone/client columns, checks | High | Stage-to-stage reconciliation and unit fixtures | Backlog/mix/productivity |
| B | Move audit watermark into committed database state | connector, ingest RPC, sync batches | Per-org source watermark | Medium | Retry, crash, duplicate and gap tests | Audit ingestion |
| B | Correct audit identity/deduplication | mapping and source_audit_events | New identity/hash version/index | High; collision analysis first | Duplicate and near-duplicate event tests | Actual/throughput |
| B | Make timezone conversion explicit | connector mapping/domain dates | Optional source timezone metadata | Medium | DST-neutral Brisbane boundaries, midnight shifts | Daily/shift KPIs |
| C | Create KPI registry and canonical query layer | new KPI definitions, SQL/functions/server domain | KPI views/functions | High | Cross-page equality for every KPI/filter | Dashboard through reports |
| C | Separate actual, target and capacity models | capacity/scenario/planning/performance | Capacity assumptions and targets tables | High | Golden scenario and effective-date tests | Planning decisions |
| C | Canonicalize age, SLA, risk and priority | orders/planning/aged reports | Planner priority and risk policy tables | High | Timestamp basis, override and risk determinism tests | Order prioritization |
| D | Replace monolithic sync with staged atomic chunks | connector/API/database | Staging tables and finalize RPC | Medium | Partial upload, retry, size and activation tests | Sync availability |
| D | Persist failed sync attempts reliably | sync APIs/batches | Lifecycle RPC changes | Low-medium | Forced error retains failed batch | Operations |
| D | Add source-health state model and retention policy | heartbeat/batches/admin | Health/retention functions | Medium | Stale combinations and cleanup safety tests | Monitoring/storage |
| E | Remove frontend business formulas; consume canonical outputs | all recovered React pages | No | Medium | Component contract and end-to-end filter tests | UI consistency |
| E | Standardize labels/status/date/filter behaviour | design system/pages | No | Low-medium | Accessibility and snapshot tests | ERP UI |
| F | Repair Oracle typings and payload-limit test | oracle-sync types, ingest test/constants | No | Low | Clean lint/test/typecheck/build | CI |
| F | Inventory and retire dead/legacy artifacts after usage proof | recovered pages/APIs/views/flags | Deprecation migrations later | Medium | Reference scan, telemetry, rollback | Maintainability |

## Release gates

1. No P0 remains open.
2. Clean lint, tests, typecheck and production build.
3. Database/RLS test suite passes against an isolated database.
4. Canonical KPI reconciliation passes for identical filters.
5. Oracle-to-Supabase batch reconciliation proves no gaps or double counting.
6. Business owner signs off flow, units, shifts, SLA and capacity assumptions.
