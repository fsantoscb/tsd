# Canonical V2 C5.11.2A Authorization Decoupling

## Isolation

Security worktree: `C:\Projects\tsd-canonical-v2-security`

Branch: `canonical-v2-security`

Baseline: `b2669131a5e4a43134341b92d159608aea4e4206`

The original five uncommitted Maintenance UX V2 files remain in the original worktree and are excluded from this branch.

## ADMIN_EMAIL inventory

| File | Feature | Previous classification | Replacement |
| --- | --- | --- | --- |
| `planning.ts` | Planning/base context | RUNTIME_AUTHORIZATION | canonical membership + permission |
| `machine-load.ts` | Machine Load | RUNTIME_AUTHORIZATION | `MACHINE_LOAD_READ` |
| `release-queue.ts` | Release Queue | RUNTIME_AUTHORIZATION | `RELEASE_QUEUE_READ` |
| `operational-scan.ts` | Scanner read | RUNTIME_AUTHORIZATION | `PRODUCTION_READ` |
| `source-data.ts` | Source diagnostics | RUNTIME_AUTHORIZATION | `SYSTEM_ADMIN` |
| `auth.ts` | email helper | LEGACY_UNUSED after remediation | removed |

Runtime authorization now derives from active Supabase Auth identity plus active `maintenance_members` membership and its canonical role. Application Admin is not service-role; no application role receives `SOURCE_DATA_MUTATE` or `SYNC_CONTROL`.

## Approved validation identity

Approved email: `felipe.s@tankstreamdesign.com`.

Identity creation/membership and sequential Operator -> Supervisor -> Manager -> Admin runtime evidence remain remote actions. No password or credential is stored in source or documentation. The banned temporary Preview identity must remain disabled.

## Current gate

Authorization source remediation is prepared. Remote identity, membership, session refresh, role isolation, anonymous, disabled-user and service-path evidence remain required before PASS.
# Validation result

- Lint: PASS
- Typecheck: PASS
- Application tests: 198/198 PASS (shared 49, oracle-sync 16, web 133)
- Production build: PASS
- Runtime privileged-email guards: removed
- Source-data mutation and sync-control permissions: granted to no application role
- Original Maintenance UX V2 worktree: preserved and excluded from this change
- Supabase, Vercel, production and Oracle: untouched

# Remote role validation

- Preview: `https://tsd-production-control-v2-preview-d3v3eup7c-tsd7.vercel.app`
- V2 project: `saecycamkyvzzppxudzq`
- Preview service-role configuration: corrected and redeployed
- `felipe.s@tankstreamdesign.com`: Auth confirmed, membership active
- OPERATOR: PASS; effective role verified after fresh authentication
- SUPERVISOR: PASS; effective role verified after fresh authentication
- MANAGER: PASS; effective role verified after fresh authentication
- ADMIN: PASS; effective role verified after fresh authentication
- Direct authenticated write to service-only `source_orders`: DENIED (HTTP 403) for every role
- Final Felipe role: ADMIN
- Final Felipe account state: ACTIVE

# Master users

| Identity | Auth | Membership | Role | Application authorization | Service-only write |
| --- | --- | --- | --- | --- | --- |
| `fsantos_cb@hotmail.com` | ACTIVE | ACTIVE | ADMIN | ALLOW | DENY (HTTP 403) |
| `felipe.s@tankstreamdesign.com` | ACTIVE | ACTIVE | ADMIN | ALLOW | DENY (HTTP 403) |

Both identities obtain authorization exclusively from Auth identity, active `maintenance_members` membership, canonical role, permission matrix and RLS. Neither email is hardcoded as privileged.
