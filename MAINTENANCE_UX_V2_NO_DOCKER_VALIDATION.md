# Maintenance UX V2 - No-Docker Validation

## Infrastructure Constraint - NO DOCKER

Docker, Docker Desktop, Docker Compose, and Docker-based Supabase local are not supported for this ERP environment.

Do not use Docker as a development, validation, migration, or recovery dependency unless Felipe explicitly re-authorizes it.

## Candidate

- Implementation candidate: `6319e8e0676740fc7fce4735f5ca5818b3d9a21f`
- Documentation baseline: `16c4361e30cf8a14f27695f685776495c7ad00a3`
- Branch: `codex/maintenance-ux-v2`
- Preview: `https://tsd-production-control-v2-preview-qfuhc99ut-tsd7.vercel.app`

## Non-Docker PostgreSQL method

The host had no native PostgreSQL binaries and no Windows PostgreSQL service. PostgreSQL 17.11 Windows binaries were obtained from the EDB binary archive linked by the official PostgreSQL Windows download page and extracted project-locally under `C:\Temp` without an installer or administrator-level system changes.

The validation cluster was initialized with trust authentication for loopback-only temporary use.

| Property | Value |
| --- | --- |
| Classification | `ISOLATED_NON_DOCKER_TEST_POSTGRES` |
| Host | `127.0.0.1` |
| Port | `55432` |
| Database | `tsd_maintenance_validation` |
| PostgreSQL | `17.11` |
| Docker | Not used |
| Remote Supabase refs | None |

The target was not Production V2 (`saecycamkyvzzppxudzq`), legacy rollback (`gdajktoqmajipivpdude`), or DEV (`tlflipdeahgwsueerkex`).

## Migration-chain result

The intended chain was:

```text
001_canonical_baseline.sql
002_access_control_hardening.sql
003_maintenance_ux_v2_lifecycle.sql
```

The official PostgreSQL archive did not bundle pgTAP. pgTAP 1.3.4 was added only to the portable PostgreSQL distribution from the official pgTAP release package. This resolved the first external extension prerequisite without changing repository migrations.

Migration `001` then failed reproducibly at line 1810:

```text
ERROR: schema "auth" does not exist
```

The transaction stopped before `001` committed. Migrations `002` and `003` were not executed.

## Root cause

`001_canonical_baseline.sql` is a Supabase-platform baseline, not a standalone PostgreSQL baseline. It depends on the Supabase-managed `auth` schema. Raw PostgreSQL does not provide Supabase Auth schemas, API services, JWT role handling, or equivalent runtime RLS context.

Creating a synthetic `auth` schema manually was rejected because:

- the migration chain itself must define the target architecture;
- hand-written stubs would not prove Supabase-equivalent Auth/RLS behaviour;
- browser lifecycle validation must not fake Supabase Auth;
- passing against a substitute could create false production confidence.

## Migration 003 structural review

Migration `003_maintenance_ux_v2_lifecycle.sql` is additive in intent. It extends Maintenance work-order lifecycle data for completion, cancellation, scheduling/assignment, active-work timing, and waiting-for-parts timing. It adds lifecycle validation and indexes, normalizes supported work-order states, and defines service-role-only lifecycle functions for completion, cancellation, reopening, controlled empty-order deletion, and state transitions.

The migration revokes lifecycle RPC execution from `PUBLIC`, `anon`, and `authenticated`, then grants execution to `service_role`. Application roles are checked inside the security-definer path. No Oracle, Workbank, Release Queue, Machine Load, Manufacturing Order, Routing, Production Demand, writer, scheduler, heartbeat, or locking object is intentionally modified.

The structural review does not replace executable Supabase RLS/runtime validation.

## Validation matrix

| Validation | Result | Evidence / blocker |
| --- | --- | --- |
| Docker not used | PASS | No Docker command or service was used |
| Isolated target identity | PASS | Loopback PostgreSQL on port 55432; no remote ref |
| PostgreSQL startup | PASS | Server accepted connections |
| Fresh chain `001 -> 002 -> 003` | BLOCKED | `001`: Supabase-managed `auth` schema absent |
| Fresh-chain reproducibility | BLOCKED | First chain cannot complete faithfully |
| Existing-data fixture migration | NOT RUN | Depends on completed chain |
| Maintenance lifecycle SQL | NOT RUN | Migration `003` not applied |
| Complete / Cancel / Delete / Reopen | NOT RUN | Migration `003` not applied |
| Waiting for Parts / Operator Fix / Scheduled | NOT RUN | Migration `003` not applied |
| Preventive regression | NOT RUN | Database target incomplete |
| Runtime RLS/security | BLOCKED | Raw PostgreSQL is not Supabase Auth/runtime |
| Destructive browser workflows | NOT RUN | Preview points to Production V2 |
| Canonical database regression | NOT RUN | Baseline did not complete |
| Production rollout risk gate | BLOCKED | Executable migration proof incomplete |

## Production risk and backward compatibility

Migration `003` appears expand-oriented and does not intentionally remove or rename fields required by the currently deployed application. However, production rollout cannot be classified as ready until it is applied to an isolated Supabase-compatible database and the existing-data, lifecycle, RLS, and backward-compatibility checks pass.

Application rollback alone would not remove schema changes from `003`. A controlled rollout still requires pre-migration Maintenance counts, a scoped Maintenance export/recovery artifact, migration verification, policy verification, and old-application compatibility proof.

## Environment protection

- Production V2: untouched
- Legacy rollback: untouched
- DEV: untouched
- Oracle: read-only and untouched
- Vercel production: untouched
- Existing Preview: non-destructive only

## Exact remaining blocker

There is no available isolated Supabase-compatible database target. PostgreSQL-only validation cannot faithfully supply the managed `auth` contract or prove Supabase runtime RLS. Supabase branches are unavailable and all existing project slots are protected.

The safe next action is to provision an isolated Supabase-compatible validation environment without pausing or replacing Production V2, legacy rollback, or DEV. Migration `003` and destructive tests must remain blocked until that target exists.

## Gate

```text
MAINTENANCE UX V2 — NO-DOCKER VALIDATION: BLOCKED
```

Reason: the clean baseline requires Supabase-managed Auth/RLS infrastructure that raw non-Docker PostgreSQL does not provide.
