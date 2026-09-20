# Maintenance UX V2 - Controlled Production Rollout

## Result

**BLOCKED**

## Release candidate

- Branch: `codex/maintenance-ux-v2`
- Candidate SHA: `1a2eb8d4e8d0a38d997ea8ee6ebd95da9e5be44a`
- Attempted deployment: `dpl_BWXUyNJWL3txZp3Jo9Kp2MFYVmqA`
- Attempted deployment timestamp: 2026-09-20 10:42 AEST

## Migration 003

- Target: Supabase V2 `saecycamkyvzzppxudzq`
- SHA256: `BF1973F2BFCCF1A8A52EAE7A134CEA0BAB393D17DCFBE69BE4704FDC2AB2B58A`
- Result: **APPLIED**
- Migration history: **PRESENT**
- Application rollback did not roll back the compatible expand-first migration.

## Maintenance reconciliation

| Metric | Before | After |
| --- | ---: | ---: |
| Assets | 31 | 31 |
| Work orders | 4 | 4 |
| History | 6 | 6 |
| Comments | 4 | 4 |
| Downtime events | 3 | 3 |
| Orphan assets | 0 | 0 |
| Invalid statuses | 0 | 0 |
| Rollout test rows | 0 | 0 |

Unexpected data loss: **0**.

## Security

The non-destructive transactional security check passed **8/8**:

- anon write denied
- operator direct write denied by RLS
- authenticated lifecycle RPC denied
- service-role lifecycle RPC allowed
- operator, supervisor, manager and admin role resolution passed
- canonical source authenticated write remained denied

## Deployment defect

The candidate was deployed to the legacy Vercel project `tsd-production-control`. Its production environment variables pointed to the legacy Supabase source. The first production smoke showed:

- UI/API state: `AGENT_OFFLINE`
- legacy agent: `factory-1`
- stale last success: 2026-09-19

This was a canonical-source regression and blocked rollout before any controlled work order was created.

## Application recovery

1. The attempted deployment was rolled back.
2. The generic rollback initially selected the preceding deployment in the legacy project.
3. The production domain was then restored explicitly to Canonical V2 deployment `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m`.
4. Cache-bypassed production verification returned:
   - freshness: `CURRENT`
   - agent: `tsd-v2-production-FELIPE-LT`
   - heartbeat: online
   - last run: `SUCCESS`
   - Oracle: read-only

## Smoke and lifecycle

- HTTP health: PASS
- Login page: PASS
- Existing Maintenance with migration 003: PASS
- New candidate lifecycle smoke: NOT RUN because the canonical-source gate failed
- Controlled test records created: 0

## Defect gate

- P0 encountered during attempted deployment: 1 canonical-source regression
- P0 current after recovery: 0
- P1 validation: stopped before lifecycle data creation

## Current production state

- Application: restored to Canonical V2 deployment `dpl_Cn2f2NoLaVRXRWnEmy3zefZHVa4m`
- Migration 003: applied
- Maintenance data: preserved
- Writer: healthy
- Scheduler/automatic sync: healthy
- Freshness: current
- Oracle: read-only

The Maintenance UX V2 application candidate is **not live**. A future deployment must target the Canonical V2 Vercel project/environment rather than the legacy Vercel project.