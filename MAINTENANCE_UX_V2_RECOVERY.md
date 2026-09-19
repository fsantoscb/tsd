# Maintenance UX V2 Recovery

## Original Maintenance baseline

The preserved Maintenance work originated at `b266913` on branch `canonical-v2`, before the final Canonical V2 security and production cutover sequence.

## Preserved changes

The original uncommitted state contained two modified application files and three new artifacts: lifecycle server actions, work-order detail controls, migration `003`, discovery documentation, and an interim result. It was preserved in commit `c13132b` and branch `backup/maintenance-ux-v2-preserved` before integration.

## Current production baseline

The clean integration branch `codex/maintenance-ux-v2` was created from stabilization commit `b63fe91`. Production implementation remains `33571de`; no production deployment, database, scheduler, Oracle, Workbank, Release Queue, or legacy rollback configuration was changed.

## Integration method

The preserved commit was cherry-picked into a clean worktree at `C:\Projects\tsd-maintenance-ux-v2`. Canonical V2 production security and runtime configuration remain authoritative.

## Expected conflicts and resolution

The preserved lifecycle RPCs predated final security hardening and revoked execution only from `anon`. Integration revokes `PUBLIC`, `anon`, and `authenticated`, then grants only `service_role`. Server actions continue to enforce membership roles before calling the RPCs.

## Migration impact

Migration `003_maintenance_ux_v2_lifecycle.sql` is incremental. It adds nullable completion, cancellation, scheduling, assignment and timer metadata; enriches existing status history; extends the existing status constraint; and creates lifecycle RPCs. It does not recreate or truncate Maintenance tables and does not modify production-source architecture.

## Security impact

Authorization uses `maintenance_members` plus the current Canonical V2 authenticated identity. No email-based privilege, anonymous write path, global RLS weakening, or service-role equivalence is introduced.

## Recovery guarantee

All preserved Maintenance changes recoverable: **YES**.
