begin;
select plan(14);

insert into organizations(id,name) values
  ('d0000000-0000-0000-0000-000000000001','Phase D Org A'),
  ('d0000000-0000-0000-0000-000000000002','Phase D Org B');

insert into operations(id,organization_id,code,name) values
  ('d1000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','PICKING','Picking'),
  ('d1000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000001','DTG_PRINT','DTG Print'),
  ('d1000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000001','PUTWALL','Putwall'),
  ('d1000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000001','DISPATCH','Dispatch'),
  ('d1000000-0000-0000-0000-000000000005','d0000000-0000-0000-0000-000000000001','UNDERPRINT','Underprint');

select is(seed_source_operation_mappings('d0000000-0000-0000-0000-000000000001'),12,'canonical source mappings are seeded');
select is(seed_source_operation_mappings('d0000000-0000-0000-0000-000000000001'),0,'source mapping seed is idempotent');
select ok(source_value_matches('PCOR','EXACT','pcor'),'exact matching is case insensitive');
select ok(source_value_matches('STATIONUP','SUFFIX','UP'),'suffix matching is deterministic');
select ok(not source_value_matches('UPSTA','SUFFIX','UP'),'suffix matching rejects broad contains');

insert into production_orders(id,organization_id,order_no,source_order_no,production_status)
values('d2000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','PO-D-1','130000001','UNROUTED');
insert into production_order_operations(id,organization_id,production_order_id,source_operation_id,sequence,operation_code_snapshot,operation_name_snapshot,status)
values
 ('d3000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001',10,'PICKING','Picking','PENDING'),
 ('d3000000-0000-0000-0000-000000000002','d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002',20,'DTG_PRINT','DTG Print','PENDING'),
 ('d3000000-0000-0000-0000-000000000003','d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003',30,'PUTWALL','Putwall','PENDING'),
 ('d3000000-0000-0000-0000-000000000004','d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000004',40,'DISPATCH','Dispatch','PENDING');

insert into source_audit_events(organization_id,source_audit_id,order_no,from_zone,to_zone,to_location,production_units,event_at,raw_hash,queue)
values
 ('d0000000-0000-0000-0000-000000000001','D-AUD-1','130000001','SP11','PCOR','PCOR',10,now()-interval '2 hours','D-HASH-1','SP11'),
 ('d0000000-0000-0000-0000-000000000001','D-AUD-2','130000001','PCOR','PWL1','PWL1-01A',10,now()-interval '1 hour','D-HASH-2','PCOR');

select lives_ok($$select * from resolve_production_order_actual_state('d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001')$$,'resolver processes Oracle evidence');
select is((select status from production_order_operations where id='d3000000-0000-0000-0000-000000000001'),'IN_PROGRESS','SP11 reaches Picking');
select is((select status from production_order_operations where id='d3000000-0000-0000-0000-000000000002'),'IN_PROGRESS','PCOR reaches DTG Print');
select is((select status from production_order_operations where id='d3000000-0000-0000-0000-000000000003'),'IN_PROGRESS','PWL1 reaches Putwall');
select is((select count(*)::integer from production_order_operation_evidence where production_order_id='d2000000-0000-0000-0000-000000000001'),3,'one best mapping per source field is recorded');
select is((select count(*)::integer from production_routing_exceptions where production_order_id='d2000000-0000-0000-0000-000000000001'),0,'normal ordered evidence creates no deviation');

insert into source_audit_events(organization_id,source_audit_id,order_no,to_location,production_units,event_at,raw_hash)
values('d0000000-0000-0000-0000-000000000001','D-AUD-3','130000001','DTGMOVE',10,now(),'D-HASH-3');
select lives_ok($$select * from resolve_production_order_actual_state('d0000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001')$$,'resolver processes a routing jump');
select is((select count(*)::integer from production_routing_exceptions where production_order_id='d2000000-0000-0000-0000-000000000001' and exception_type='SKIPPED_OPERATION'),0,'observed Putwall prevents a false skipped-operation exception');
select is((select count(*)::integer from source_operation_mappings where organization_id='d0000000-0000-0000-0000-000000000002'),0,'mappings remain organization isolated');

select * from finish();
rollback;
