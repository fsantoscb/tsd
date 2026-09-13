begin;
select plan(17);
insert into organizations(id,name)values('f1000000-0000-0000-0000-000000000001','MO Group Test');
insert into operations(id,organization_id,code,name)values
('f1100000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','MO_PICK','Pick'),
('f1100000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000001','MO_PRINT','Print');
insert into routings(id,organization_id,code,name,revision,status)values
('f1200000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','MO_DTG','DTG',1,'DRAFT'),
('f1200000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000001','MO_SCREEN','Screen',1,'DRAFT'),
('f1200000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000001','MO_UV','UV',1,'DRAFT');
insert into routing_operations(organization_id,routing_id,sequence,operation_id)values
('f1000000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001',10,'f1100000-0000-0000-0000-000000000001'),
('f1000000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001',20,'f1100000-0000-0000-0000-000000000002'),
('f1000000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000002',10,'f1100000-0000-0000-0000-000000000001'),
('f1000000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000003',10,'f1100000-0000-0000-0000-000000000001');
update routings set status='ACTIVE'where organization_id='f1000000-0000-0000-0000-000000000001';
insert into products(id,organization_id,sku,default_routing_id)values
('f1300000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','ADULT','f1200000-0000-0000-0000-000000000001'),
('f1300000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000001','KIDS','f1200000-0000-0000-0000-000000000001'),
('f1300000-0000-0000-0000-000000000003','f1000000-0000-0000-0000-000000000001','SCREEN','f1200000-0000-0000-0000-000000000002'),
('f1300000-0000-0000-0000-000000000004','f1000000-0000-0000-0000-000000000001','UV','f1200000-0000-0000-0000-000000000003');
insert into production_demand_lines(organization_id,source_system,source_order_no,source_order_line_id,product_id,routing_id,routing_revision_id,quantity)values
('f1000000-0000-0000-0000-000000000001','TEST','SO1001','1','f1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001',500),
('f1000000-0000-0000-0000-000000000001','TEST','SO1001','2','f1300000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001',200),
('f1000000-0000-0000-0000-000000000001','TEST','SO1001','3','f1300000-0000-0000-0000-000000000003','f1200000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000002',300),
('f1000000-0000-0000-0000-000000000001','TEST','SO1001','4','f1300000-0000-0000-0000-000000000004','f1200000-0000-0000-0000-000000000003','f1200000-0000-0000-0000-000000000003',600),
('f1000000-0000-0000-0000-000000000001','TEST','SO1002','1','f1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001',400);
select lives_ok($$select * from create_manufacturing_orders('f1000000-0000-0000-0000-000000000001','TEST')$$,'groups demand into MOs');
select is((select count(*)::int from production_orders where source_system='TEST'),4,'same SO different routings and different SO same routing create four MOs');
select is((select count(*)::int from production_orders where source_system='TEST'and source_order_no='SO1001'),3,'one SO may own multiple MOs');
select is((select count(*)::int from production_orders where source_system='TEST'and source_routing_id='f1200000-0000-0000-0000-000000000001'),2,'different SOs never merge on routing alone');
select is((select planned_quantity from production_orders where source_system='TEST'and source_order_no='SO1001'and source_routing_id='f1200000-0000-0000-0000-000000000001'),700::numeric,'same SO and routing quantities sum');
select is((select count(*)::int from manufacturing_order_lines l join production_orders p on p.id=l.manufacturing_order_id where p.source_order_no='SO1001'and p.source_routing_id='f1200000-0000-0000-0000-000000000001'),2,'product detail is retained');
select lives_ok($$select * from create_manufacturing_orders('f1000000-0000-0000-0000-000000000001','TEST')$$,'repeated grouping is safe');
select is((select count(*)::int from production_orders where source_system='TEST'),4,'grouping is idempotent');
select is((select count(*)::int from production_order_operations poo join production_orders po on po.id=poo.production_order_id where po.source_system='TEST'and po.source_order_no='SO1001'and po.source_routing_id='f1200000-0000-0000-0000-000000000001'),2,'routing operations are snapshotted');
update routings set status='INACTIVE'where id='f1200000-0000-0000-0000-000000000001';
select is((select routing_revision_snapshot from production_orders where source_system='TEST'and source_order_no='SO1001'and source_routing_id='f1200000-0000-0000-0000-000000000001'),1,'MO routing revision snapshot remains unchanged');
select is(update_manufacturing_order_line_quantity('f1000000-0000-0000-0000-000000000001','TEST','SO1001','1',550),'MO_UPDATED','pending quantity changes update MO safely');
select is((select planned_quantity from production_orders where source_system='TEST'and source_order_no='SO1001'and source_routing_id='f1200000-0000-0000-0000-000000000001'),750::numeric,'MO total follows line sum');
update production_orders set production_status='IN_PROGRESS'where source_system='TEST'and source_order_no='SO1002';
select is(update_manufacturing_order_line_quantity('f1000000-0000-0000-0000-000000000001','TEST','SO1002','1',450),'EXCEPTION_CREATED','in-progress quantity changes create exception');
select is((select planned_quantity from production_orders where source_system='TEST'and source_order_no='SO1002'),400::numeric,'in-progress MO history is not overwritten');
select is((select count(*)::int from production_routing_exceptions where exception_type='SOURCE_QUANTITY_CHANGE'),1,'quantity exception is recorded');
select throws_ok($$insert into manufacturing_order_lines(organization_id,manufacturing_order_id,source_order_no,source_order_line_id,routing_revision_id,planned_quantity)select organization_id,id,'SO1002','CROSS-SO',source_routing_id,1 from production_orders where source_system='TEST'and source_order_no='SO1001'limit 1$$,'MO line Sales Order must equal parent Sales Order','cross-SO line ownership is rejected');
select is((select count(*)::int from v_mo_grouping_reconciliation where source_order_no in('SO1001','SO1002')and mo_difference=0),2,'reconciliation confirms expected MO counts');
select * from finish();
rollback;

