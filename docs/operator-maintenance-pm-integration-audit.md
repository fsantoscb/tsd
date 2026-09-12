# Operator Maintenance / PM Integration Audit

The existing Preventive Maintenance module remains the source of truth. The Operator Terminal is an execution adapter; no parallel PM plan, scheduler, checklist, history, compliance or recurrence model was created.

## Canonical model reused
- Plans: `maintenance_preventive_plans`.
- Task definitions: `maintenance_preventive_plan_tasks`.
- Execution: `maintenance_work_orders` with `work_order_type='preventive'` and `preventive_plan_id`.
- Frozen checklist: `maintenance_work_order_checklist`.
- Due generation: `maintenance_generate_due_pm`; `maintenance_one_open_pm` prevents duplicate active work.
- Next due and overdue: `next_due_at` in the existing plan.
- History: `maintenance_work_order_history`.
- Parts and stock: `maintenance_post_inventory` and `maintenance_inventory_transactions`.
- Authorization: `maintenance_members`, `mc` and `mm`.
- Administration: `/maintenance/preventive` remains the planning/configuration interface.

## Minimal extensions
`requires_downtime` was added to the existing plan. No-parts confirmation, source-PM reference and operator problem classification were added to the generic work order. `maintenance_operator_pm_action` updates the existing work order/checklist and advances the existing plan on completion.

PM downtime is planned, counts as downtime only when required, and never counts as failure. Inventory can only be deducted by the shared inventory transaction function. Existing IDs, plans, due dates, completed services and history are preserved.
