# Maintenance UX V2 Discovery

## Current architecture and workflow
The existing Next.js/Supabase module already unifies assets, corrective and preventive work orders, operator requests, history, labour, downtime, attachments, parts inventory and QR access. PM generates and executes the same work-order model. Current normalized flow is `open -> in_progress -> waiting_parts/waiting_external -> in_progress -> completed`; legacy operator statuses remain required for compatibility.

## Problems found
The detail UI does not expose clear closure/cancellation controls. Completion actor and canonical cancellation metadata are absent. Reopen and controlled deletion do not exist. Security-definer lifecycle operations require database-level role enforcement, not only server-action checks.

## Compatible proposal
Migration `003_maintenance_ux_v2_lifecycle.sql` adds nullable metadata, enriches the existing history table, permits `scheduled`, and adds role-enforced complete/cancel/reopen/delete RPCs. No asset, parts, PM, timer or audit architecture is duplicated.

## Risk and compatibility
Existing rows need no backfill. Legacy operator statuses remain. Deletion is limited to open, unstarted, non-preventive orders with no activity beyond their creation event. All other records must be cancelled and retained.

## Final Canonical V2 architecture

Maintenance remains one domain spanning corrective, Operator Fix, scheduled corrective, Preventive Maintenance, assets, parts, labour, downtime, attachments and history. Lifecycle writes pass through server actions and service-only RPCs; authorization is derived from active `maintenance_members`, never privileged email lists. Active technician time pauses in `waiting_parts`, while elapsed downtime remains represented by the existing downtime-event architecture. QR navigation resolves directly to the existing Operator Terminal with the asset preselected.

Canonical production authorities are unaffected: Oracle Sales Order Lines remain release authority, Workbank remains current operational load, Screen Print remains Workbank-only, capacity remains configuration, and audit history remains authoritative history.
