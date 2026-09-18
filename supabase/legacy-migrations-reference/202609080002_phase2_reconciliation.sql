create or replace view v_source_reconciliation with (security_invoker=true) as
select b.organization_id,b.id sync_batch_id,b.completed_at,
 b.orders_count batch_orders,(select count(*) from source_orders o where o.sync_batch_id=b.id) current_orders,
 b.workbank_count batch_workbank,(select count(*) from source_workbank_items w where w.sync_batch_id=b.id) current_workbank,
 b.stock_count batch_stock,(select count(*) from source_stock_items s where s.sync_batch_id=b.id) current_stock,
 b.audit_new_count
from v_latest_completed_batch b;
