# Manual Validation Checkpoint

## Frozen checkpoint

| Item | Value |
|---|---|
| Branch | `feature/routing-phase-e` |
| Commit | `3f7e13362404728f64b68f80b55c0b7daf168e91` |
| Pre-routing baseline | `pre-routing-architecture-v1` / `221560026aec764e3e546bd4647affda9d28170f` |
| GitHub Actions | PASS - [run 34738890550](https://github.com/fsantoscb/tsd/actions/runs/34738890550) |
| Vercel Preview | **BLOCKED - no Preview Deployment exists for this branch/commit** |
| Production deployment | Not performed |
| Next architecture phase | Blocked until this checklist is completed or explicitly waived |

## Preview URL for manual testing

**No Preview URL is currently available.** GitHub has no Vercel deployment or Vercel check for this commit, and this checkout has no local Vercel project link. Do not use `https://tsd-production-control.vercel.app` to validate these architecture changes because that is the production URL and this checkpoint expressly prohibits a production deployment.

## Automated validation rerun

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | All workspaces |
| Typecheck | PASS | All workspaces |
| Unit tests | PASS | 130 tests across shared, web and Oracle sync |
| Integration without Docker: Oracle sync | PASS | `apps/oracle-sync/__tests__/sync.test.ts` |
| Integration without Docker: web | PASS | ingest, reconciliation and routing rule suites |
| Production build | PASS | 45 application routes generated; isolated non-production environment values |

The warning about the optional Next.js ESLint plugin remains non-blocking. No test in this checkpoint connected to Oracle, production Supabase or production Vercel.

## Changes since the pre-routing baseline

- Phase A: Product Families, Product Types, Product Master, Operations, Work Centers and Production Resources foundation.
- Phase B: Routing Master, immutable revisions, ordered Routing Operations and Product-to-Routing association.
- Phase C: Production Orders, Production Order Operations and immutable routing snapshots.
- Phase D: Source Operation Mapping, Oracle/WMS evidence ledger, deterministic actual-state resolver and routing exceptions.
- Phase E: Legacy-versus-canonical reconciliation ledger and migration-readiness gate.
- Admin interfaces added for Production Master and Routings.
- CI expanded to validate feature branches.
- Existing Flow, KPI, Planning, Capacity, DTG and UP pages have not been migrated to the new engine.
- Legacy production-stage rules remain in place.

## Database migration state

| Migration | Local Supabase | Production Supabase |
|---|---|---|
| `202609130006_routing_phase_a_master_data.sql` | Applied and tested | Not applied by this architecture work |
| `202609130007_routing_phase_b.sql` | Applied and tested | Not applied by this architecture work |
| `202609130008_routing_phase_c_execution.sql` | Applied and tested | Not applied by this architecture work |
| `202609130009_routing_phase_d_source_validation.sql` | Applied and tested | Not applied by this architecture work |
| `202609130010_routing_phase_e_reconciliation.sql` | Applied and tested | Not applied by this architecture work |

The local database was rebuilt through the complete migration chain ending at Phase E. No architecture migration was sent to production. The pre-existing production migration state was not changed or inferred during this checkpoint.

## How to record results

Select exactly one status per row after testing against a non-production Preview containing commit `3f7e133`.

## AUTH

| Test | Route/action | PASS | FAIL | NOT IMPLEMENTED | BLOCKED | Notes |
|---|---|---|---|---|---|---|
| Login | `/login` | [ ] | [ ] | [ ] | [ ] | |
| Logout | App-shell logout action | [ ] | [ ] | [ ] | [ ] | |
| Unauthorized route protection | Open protected route while signed out | [ ] | [ ] | [ ] | [ ] | |

## CORE ERP

| Test | Route | PASS | FAIL | NOT IMPLEMENTED | BLOCKED | Notes |
|---|---|---|---|---|---|---|
| Dashboard loads | `/` | [ ] | [ ] | [ ] | [ ] | |
| Flow loads | `/production/flow` | [ ] | [ ] | [ ] | [ ] | |
| KPI dashboard loads | `/kpis` | [ ] | [ ] | [ ] | [ ] | |
| ERP performance loads | `/production/performance` | [ ] | [ ] | [ ] | [ ] | |
| Planning loads | `/production/planning` | [ ] | [ ] | [ ] | [ ] | |
| Capacity loads | `/production/capacity` | [ ] | [ ] | [ ] | [ ] | |
| DTG workbank loads | `/production/dtg` | [ ] | [ ] | [ ] | [ ] | |
| UP workbank loads | `/production/up` | [ ] | [ ] | [ ] | [ ] | |
| Aged Orders loads | `/production/stages?aged=1` | [ ] | [ ] | [ ] | [ ] | |
| Ready To Lift loads | `/production/ready-to-lift` | [ ] | [ ] | [ ] | [ ] | |
| Hold Orders loads | `/production/hold-orders` | [ ] | [ ] | [ ] | [ ] | |
| Machine Load loads | `/production/machine-load` | [ ] | [ ] | [ ] | [ ] | |
| Order detail loads | `/production/orders/{orderNo}` | [ ] | [ ] | [ ] | [ ] | Use a valid order |

## FILTERS

| Test | Page | PASS | FAIL | NOT IMPLEMENTED | BLOCKED | Notes |
|---|---|---|---|---|---|---|
| Date filter | ERP performance | [ ] | [ ] | [ ] | [ ] | Confirm URL and totals change |
| Shift filter | ERP performance | [ ] | [ ] | [ ] | [ ] | Test all shifts |
| Process filter | ERP performance | [ ] | [ ] | [ ] | [ ] | DTG, UP, Screen Print, All |
| Search | DTG and UP workbanks | [ ] | [ ] | [ ] | [ ] | Order and client/ship-to |
| Pagination | Source data and workbanks where exposed | [ ] | [ ] | [ ] | [ ] | First, next and previous pages |
| Ready To Lift status | Ready To Lift | [ ] | [ ] | [ ] | [ ] | All, Ready, On Process |
| Aged-only filter | Production stages | [ ] | [ ] | [ ] | [ ] | Preserve selected stage |

## DATA CONSISTENCY

| Test | Comparison | PASS | FAIL | NOT IMPLEMENTED | BLOCKED | Notes/evidence |
|---|---|---|---|---|---|---|
| DTG totals | ERP versus current Oracle/PCP reference | [ ] | [ ] | [ ] | [ ] | Record source timestamp |
| UP totals | ERP versus current Oracle/PCP reference | [ ] | [ ] | [ ] | [ ] | Record source timestamp |
| SLA counts | Flow/Aged Orders versus order detail | [ ] | [ ] | [ ] | [ ] | Check Brisbane date boundary |
| Capacity values | Capacity versus approved resource/rate configuration | [ ] | [ ] | [ ] | [ ] | Do not compare to demand |
| Orders and priorities | Workbanks versus Oracle source | [ ] | [ ] | [ ] | [ ] | Sample at least five orders |
| Last Sync | Dashboard, Flow and Sync Status agree | [ ] | [ ] | [ ] | [ ] | Record displayed timestamps |
| Ship-to under Client label | Workbanks versus Oracle `ship_to_name` | [ ] | [ ] | [ ] | [ ] | Do not use customer account name |
| Ready To Lift quantities | Stock/Putwall versus ERP totals | [ ] | [ ] | [ ] | [ ] | Aggregate duplicate order lines |

## NEW ROUTING ARCHITECTURE FEATURES

| Test | Route/check | PASS | FAIL | NOT IMPLEMENTED | BLOCKED | Notes |
|---|---|---|---|---|---|---|
| Product Families | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Create/update permissions |
| Product Types | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Configuration, not hardcoded UI |
| Product Master | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | SKU uniqueness by organization |
| Operations | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Stable canonical codes |
| Work Centers | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Separate from Operations |
| Production Resources | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Work Center and optional asset link |
| Routing list | `/admin/routings` | [ ] | [ ] | [ ] | [ ] | Organization isolation |
| Routing creation | `/admin/routings` | [ ] | [ ] | [ ] | [ ] | Authorized role only |
| Routing revision | `/admin/routings` | [ ] | [ ] | [ ] | [ ] | Historical revision remains unchanged |
| Routing Operations | `/admin/routings` | [ ] | [ ] | [ ] | [ ] | Add, reorder and deactivate where allowed |
| Product-to-Routing association | `/admin/production-master` | [ ] | [ ] | [ ] | [ ] | Default routing assignment |
| Production Order execution UI | No dedicated Phase C UI | [ ] | [ ] | [ ] | [ ] | Expected to be NOT IMPLEMENTED until Phase F |
| Source Mapping admin UI | No dedicated Phase D UI | [ ] | [ ] | [ ] | [ ] | Expected to be NOT IMPLEMENTED until Phase F |
| Canonical reconciliation UI | Existing `/admin/reconciliation` still shows snapshot integrity | [ ] | [ ] | [ ] | [ ] | New Phase E gate UI expected to be NOT IMPLEMENTED until Phase F |

## Checkpoint decision

| Decision | Select one |
|---|---|
| Manual validation completed and accepted | [ ] |
| Manual validation completed with blocking failures | [ ] |
| Manual validation explicitly waived by authorized owner | [ ] |

Validated by: ____________________  
Date/time (Australia/Brisbane): ____________________  
Preview commit: ____________________  
Notes: ____________________

