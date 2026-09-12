# Full System Audit

> Post-audit update: the exact production source was recovered from Vercel and remediation phases A-F were executed. See `docs/SYSTEM_AUDIT_COMPLETION.md` for current status. Findings below preserve the original diagnostic baseline for traceability.

## Executive Summary

The linked repository is not the complete source of the deployed TSD Production Control ERP. It contains a phase 0-2 ingestion/reconciliation application with 3 migrations and 4 admin pages, while the live site exposes later Production, KPI, Planning and Maintenance modules that are absent locally. Consequently, a complete formula-by-formula cross-page audit cannot honestly be certified.

Within the available source, the audit found **24 issues: 3 P0, 10 P1, 8 P2 and 3 P3**. The highest risks are unreproducible production deployments, an ingest credential that can nominate any organization, optional admin authorization combined with unscoped service-role reads, and organization IDs that can disagree with their batch IDs. No destructive or functional fixes were applied.

## Findings

| ID | Severity | Area | Issue | Files/Pages | Current behaviour | Expected behaviour | Root cause | Recommended fix |
|---|---|---|---|---|---|---|---|---|
| AUD-001 | P0 CRITICAL | Release governance | Deployed ERP source is absent locally | IMPLEMENTATION_PLAN, local routes vs live routes | Vercel serves modules not reproducible from linked repo | Production deploy maps to complete reviewed commit | Workspace/deploy drift | Recover exact deployment source and lock CI deploys to repository commits |
| AUD-002 | P0 CRITICAL | Ingestion security | Bearer holder chooses arbitrary organization ID | ingest route, shared payload, RPC | Valid secret can write a payload for any existing org | Agent identity is bound server-side to one org | Organization trusted from request body | Map hashed agent credential to organization and ignore payload org |
| AUD-003 | P0 CRITICAL | Tenant integrity | Row organization can differ from sync batch organization | phase1 migration | Independent FKs permit cross-org batch rows; service reads are unscoped | Composite integrity and organization isolation | Missing composite FK/constraint and query predicates | Add composite keys/FKs and mandatory org-scoped data access |
| AUD-004 | P1 HIGH | Authorization | Any authenticated user becomes admin if ADMIN_EMAIL is absent | `lib/source-data.ts` | Guard checks role only when optional env exists | Explicit roles required in every environment | Fail-open configuration | Fail closed; use membership and role tables |
| AUD-005 | P1 HIGH | Oracle flow | Approved DTG PWL1/DTGMOVE and UP UPMOVE stages are not extracted explicitly | `source-reader.ts` | Queries cover SP11/PCOR and a broad UP heuristic | All approved stages classified exactly | Phase-1 legacy filters | Canonical stage classifier and source contract |
| AUD-006 | P1 HIGH | KPI volume | Production-unit rules conflict by source | `mapping.ts`, DECISIONS | Same physical load may be qty in workbank and weight in stock/audit | One approved physical-unit formula | Duplicated provisional formulas | Version and centralize units policy; reconcile across stages |
| AUD-007 | P1 HIGH | Audit integrity | Raw hash omits fields that distinguish events | `mapping.ts`, migration unique raw_hash | Distinct quantity/product/user/zone events can dedupe | Unique immutable source event identity | Partial hash input | Include all identity fields or rely on authoritative audit ID |
| AUD-008 | P1 HIGH | Sync cursor | Audit watermark is a fixed environment value | `sync-once.ps1`, env, source-reader | Every run re-reads an ever-growing range; manual edits risk gaps | Durable per-org committed watermark | Cursor is not database-owned | Persist watermark transactionally after accepted batch |
| AUD-009 | P1 HIGH | Failed batches | Failed status update is rolled back with RPC exception | phase1 RPC | Exception rethrows, rolling back inserted/updated failed batch | Failure history remains observable | Error logging is inside same transaction | Separate batch lifecycle calls or non-transactional failure logging |
| AUD-010 | P1 HIGH | Timezone | `SYNC_TIMEZONE` is unused when Oracle dates are converted | env/mapping | Offset-free values depend on driver/host interpretation | Oracle wall time interpreted as Australia/Brisbane then stored UTC | Generic JS Date parsing | Explicit source-zone conversion and boundary tests |
| AUD-011 | P1 HIGH | Data quality | Zero/negative production units are accepted | shared schemas/database | Finite values of any sign pass | Physical volume must obey approved nonnegative/positive constraints | Missing schema and DB checks | Add quarantine rules plus CHECK constraints after profiling |
| AUD-012 | P1 HIGH | Multi-source integrity | Stock persists neither zone nor client | source query/schema/table | PWL1/client filters cannot be audited after ingestion | Preserve source evidence used for classification | Normalization discarded source columns | Persist source zone/client and mapping version |
| AUD-013 | P1 HIGH | Build | Production workspace build fails | oracle-sync TS imports | TypeScript cannot type `oracledb` | Clean production build | Driver typings unresolved | Use supported driver typings or a precise declaration adapter |
| AUD-014 | P1 HIGH | KPI governance | Mandatory KPI definitions and deployed implementations are missing | docs/routes | Cross-page equality cannot be established | One canonical definition/test per KPI | Incomplete repository | Recover sources, then create KPI registry and reconciliation tests |
| AUD-015 | P2 MEDIUM | Testing | Ingest payload-limit test contradicts implementation | ingest test/lib | Test expects 11 MB rejection; implementation allows 25 MB | One configured/documented limit | Threshold changed without test | Central constant and boundary tests for declared/compressed/decoded sizes |
| AUD-016 | P2 MEDIUM | Testing | No DB, RLS, integration or cross-page reconciliation tests | test suite | Only 18 small unit tests, one failing | Database and KPI invariants tested | Early-phase coverage | Add pgTAP/integration fixtures and query-level KPI equality tests |
| AUD-017 | P2 MEDIUM | Source accuracy | Audit PCOR predicate uses broad OR logic | `source-reader.ts` | Queue PCOR or task PCOR is accepted | Exact event rule with precedence | Legacy convenience predicate | Canonical classifier with positive and negative fixtures |
| AUD-018 | P2 MEDIUM | Availability | Entire snapshot payload is buffered/compressed in memory | sync/web ingest | Large Oracle snapshots can exceed 25 MB or memory limits | Chunked/streamed atomic batch protocol | Monolithic payload | Staged chunk upload finalized atomically |
| AUD-019 | P2 MEDIUM | Security | Ingest endpoint has no replay nonce, rate limit or credential rotation model | API routes | Static bearer can be replayed indefinitely | Rotatable scoped credentials and replay controls | Single shared secret | Agent credentials, hash storage, rotation and rate limiting |
| AUD-020 | P2 MEDIUM | Source truth | Production status enum is not connected to DB/source mappings | shared production schema | Enum exists but raw source status remains independent | One canonical status map | Dead/unfinished domain layer | Mapping table/function with generated types |
| AUD-021 | P2 MEDIUM | Operations | Freshness is only a hard-coded five-minute batch age | reconciliation/freshness badge | Health ignores heartbeat and source event recency | Transparent source-health state | Simplistic UI helper | Combine batch, heartbeat, reconciliation and source watermark |
| AUD-022 | P2 MEDIUM | Query isolation | Server service-role reads omit organization filters | `source-data.ts` | All rows/views are queried globally | Every request scoped to authorized org | Single-org assumption | Repository layer requiring organization context |
| AUD-023 | P3 LOW | Maintainability | Business/source SQL is embedded in a TypeScript string | source-reader | Mapping changes bypass DB review tooling | Versioned query/mapping artifacts | Early implementation | Move source contracts to reviewed modules with fixtures |
| AUD-024 | P3 LOW | UX/diagnostics | Login hides actionable auth category and admin guard redirects as login failure | login/guard | Configuration, authorization and credential failures look similar | Safe but distinguishable operator diagnostics | Generic error handling | Correlation ID and safe reason categories |

## Static and dynamic checks

| Check | Result | Detail |
|---|---|---|
| Lint | PASS | All three packages passed |
| Unit tests | FAIL | 17 passed, 1 failed: 11 MB payload test conflicts with 25 MB implementation |
| Typecheck | FAIL | Oracle driver has no resolved declarations in two files |
| Production build | FAIL | Stops at the same Oracle driver type errors |
| Database/RLS tests | NOT AVAILABLE | No database test harness or local credentials/schema runner supplied |
| Cross-page reconciliation | NOT POSSIBLE | Deployed page source and canonical KPI queries are absent |
| Live HTTP health | PASS at audit start | Root, login, machine-load and health endpoint returned HTTP 200; this does not validate KPI correctness |

## Ten most important findings

1. The production site cannot be reproduced from the linked source.
2. The ingest secret is not bound to an organization.
3. Organization and batch ownership can conflict at database level.
4. Admin authorization fails open when `ADMIN_EMAIL` is missing.
5. Approved DTG/UP flow stages are missing or represented by broad heuristics.
6. Production volume is calculated differently across source types.
7. Audit deduplication can suppress distinct physical events.
8. Audit ingestion uses a fixed, manually managed watermark.
9. Timezone configuration is declared but not applied at ingestion.
10. The checked-out source fails tests, typecheck and production build.

## KPI values that can disagree

The deployed formulas are unavailable, so numeric equality cannot be certified. Structural causes capable of producing disagreement are: qty-versus-weight unit selection; stage predicates that differ between workbank and audit; PWL1 evidence discarded after extraction; fixed audit watermark; unscoped organization reads; timezone conversion at date boundaries; and potential hash deduplication collisions. These affect backlog, actual production, throughput, productivity, mix, capacity load, SLA/age and ready-to-lift counts.

## Production-flow inconsistencies

- DTG extraction covers SP11 and PCOR, but not an explicit PWL1 or DTGMOVE event path.
- UP extraction treats leaving UNDERPRINT as output, rather than separately identifying Name+UP printing and UPMOVE dispatch.
- Screen Print manual flow is absent.
- Raw records have no persisted canonical stage or mapping version.

## Security and data-integrity risks

- Caller-controlled organization identity at ingestion.
- Optional/fail-open admin gate.
- Service-role reads without tenant predicates.
- Missing same-organization batch/item constraints.
- Incomplete event hash and no durable source watermark.
- Missing quantity checks and database-level domain constraints.

## Audit limitations

Required specification files such as `SPEC.md`, `PRODUCTION_FLOW_KPI_SPEC.md`, `docs/KPI_DEFINITIONS.md`, and the source for deployed ERP modules are absent. Live production data was not modified or queried with privileged credentials. Findings about unavailable pages are explicitly classified as unknown/unverifiable rather than guessed.

## Files created

- `docs/SYSTEM_RULE_MAP.md`
- `docs/BUSINESS_RULE_DUPLICATION.md`
- `docs/DATA_CONSISTENCY_MATRIX.md`
- `docs/FULL_SYSTEM_AUDIT.md`
- `docs/SYSTEM_AUDIT_FIX_PLAN.md`

## Recommended remediation order

1. Recover and freeze the exact deployed source and specifications.
2. Close ingestion/tenant authorization and integrity risks.
3. Canonicalize stage, unit, date and status rules.
4. Build canonical KPI queries and cross-page reconciliation tests.
5. Repair build/test pipeline before functional changes.
6. Consolidate UI/backend logic and only then retire legacy code.

## Change safety statement

No destructive fixes, migrations, refactors, production-data changes or KPI formula changes were applied during this audit.
