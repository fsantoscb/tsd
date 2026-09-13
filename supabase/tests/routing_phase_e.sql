begin;
select plan(10);

insert into organizations(id,name) values
 ('e0000000-0000-0000-0000-000000000001','Phase E Org A'),
 ('e0000000-0000-0000-0000-000000000002','Phase E Org B');
insert into sync_batches(id,organization_id,status,completed_at,orders_count,workbank_count,stock_count)
values('e1000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','completed',now(),2,81,0);
insert into source_orders(organization_id,sync_batch_id,order_no,date_released)
values
 ('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','130E00001',now()),
 ('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','130E00002',now());
insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,from_zone,production_units,queue)
select 'e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','E-'||g,'130E00001','DTGS',1,'PCOR'
from generate_series(1,80) g;
insert into source_workbank_items(organization_id,sync_batch_id,source_row_id,order_no,from_zone,production_units,queue)
values('e0000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','E-LEGACY-ONLY','130E00002','DTGS',1,'PCOR');

insert into routings(id,organization_id,code,name,revision,status,active)
values('e1500000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','DTG_E_TEST','DTG E Test',1,'ACTIVE',true);
set local session_replication_role=replica;
insert into production_orders(id,organization_id,order_no,source_order_no,source_routing_id,routing_code_snapshot,routing_name_snapshot,routing_revision_snapshot,production_status,planned_quantity,actual_quantity)
values
 ('e2000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','PO-E-1','130E00001','e1500000-0000-0000-0000-000000000001','DTG_E_TEST','DTG E Test',1,'IN_PROGRESS',100,20),
 ('e2000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000001','PO-E-2','130E00003','e1500000-0000-0000-0000-000000000001','DTG_E_TEST','DTG E Test',1,'IN_PROGRESS',50,0);
insert into production_order_operations(id,organization_id,production_order_id,sequence,operation_code_snapshot,operation_name_snapshot,status,planned_quantity,actual_quantity)
values
 ('e3000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001',20,'DTG_PRINT','DTG Print','IN_PROGRESS',100,20),
 ('e3000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000002',20,'DTG_PRINT','DTG Print','IN_PROGRESS',50,0);
set local session_replication_role=origin;

create temporary table phase_e_result as select run_production_reconciliation('e0000000-0000-0000-0000-000000000001',1) id;
select ok((select id is not null from phase_e_result),'reconciliation returns a run id');
select is((select status from production_reconciliation_runs where id=(select id from phase_e_result)),'COMPLETED','run completes');
select is((select total_orders from production_reconciliation_runs where id=(select id from phase_e_result)),3,'three distinct comparison rows are recorded');
select is((select matched_orders from production_reconciliation_runs where id=(select id from phase_e_result)),1,'matching operation and remaining quantity reconcile');
select is((select missing_canonical_orders from production_reconciliation_runs where id=(select id from phase_e_result)),1,'legacy-only order is visible');
select is((select missing_legacy_orders from production_reconciliation_runs where id=(select id from phase_e_result)),1,'canonical-only order is visible');
select is((select quantity_variance from production_reconciliation_items where reconciliation_run_id=(select id from phase_e_result) and order_no='130E00001'),0::numeric,'remaining quantity variance is zero');
select is((select migration_gate from v_production_reconciliation_gate where organization_id='e0000000-0000-0000-0000-000000000001'),'BLOCKED_MISSING_CANONICAL','missing canonical data blocks UI migration');
select is((select count(*)::integer from v_latest_production_reconciliation_items where organization_id='e0000000-0000-0000-0000-000000000001'),3,'latest item view exposes the complete run');
select is((select count(*)::integer from production_reconciliation_runs where organization_id='e0000000-0000-0000-0000-000000000002'),0,'runs remain organization isolated');
select * from finish();
rollback;
