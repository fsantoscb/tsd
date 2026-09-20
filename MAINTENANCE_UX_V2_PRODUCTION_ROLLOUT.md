# Maintenance UX V2 - Controlled Production Rollout

## Result

**PASS**

## Release

- Branch: `codex/maintenance-ux-v2`
- Production SHA: `114b6d5a24bdc3f89e97c5e310c676bdef9b5473`
- Deployment: `dpl_6in2jJMgMBRbuNyGWbtwv6Q7n68t`
- Vercel project: `tsd-production-control-v2-preview` (`prj_zd7F18oWFWjcyOdK6p8NcZ221Cmc`)
- Production domain: `https://tsd-production-control.vercel.app`
- Supabase: Canonical V2 `saecycamkyvzzppxudzq`
- Migration 003: applied

## Validation

- Lint: PASS
- Typecheck: PASS
- Application tests: 208/208 PASS
- Production build: PASS
- Isolated deployment health, login and Maintenance: HTTP 200
- Authenticated production data: PASS
- Oracle source: CURRENT / READ ONLY
- Legacy source regression: none

## Controlled lifecycle smoke

- Standard work order: `WO-2026-000005` (`e0956811-3ffe-4645-96d6-324e47c5cad1`)
- Lifecycle: create -> start -> complete: PASS
- Resolution and status history: PASS
- Active timer stopped: PASS (`active_work_started_at` is null)
- Operator Fix: `WO-2026-000006` (`85eaf653-b67c-401b-93b4-a3bf1b1f66aa`)
- Operator Fix completion: PASS
- Existing four work orders were not modified.

## Integrity

The pre-rollout dataset was preserved. The only added records are the two explicitly labelled controlled smoke-test work orders and their lifecycle audit records. No schema, Oracle, Routing, Manufacturing Order, Production Demand or source-authority changes were made during this deployment-target correction.

## Final gate

- Writer: HEALTHY
- Scheduler: HEALTHY
- Freshness: CURRENT
- P0: 0
- P1: 0

**MAINTENANCE UX V2 IS NOW PRODUCTION**
