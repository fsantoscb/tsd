begin;
select plan(10);

insert into organizations(id,name) values('c4100000-0000-0000-0000-000000000001','C4.1 release fixture');

create or replace function pg_temp.c41_sync(lines jsonb) returns void language plpgsql as $$
begin
  perform ingest_sync_batch(jsonb_build_object(
    'organizationId','c4100000-0000-0000-0000-000000000001',
    'connectorVersion','c4.1-test','orders','[]'::jsonb,
    'releaseOrderLines',lines,'workbank','[]'::jsonb,'stock','[]'::jsonb,'auditEvents','[]'::jsonb));
end$$;

select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select released from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),true,'Y ingestion');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"N","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select released from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),false,'N ingestion');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select count(*)::integer from source_order_release_lines where source_order_no='130C41'),1,'repeated Y is idempotent');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"N","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"N","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select count(*)::integer from source_order_release_lines where source_order_no='130C41'),1,'repeated N is idempotent');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select released from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),true,'N to Y is observable');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"N","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select released from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),false,'Y to N is observable');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":null,"groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select ok((select released is null and raw_release_value is null from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),'NULL remains unresolved');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"X","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select ok((select released is null and raw_release_value='X' from source_order_release_lines where source_order_no='130C41' and source_line_id='1'),'invalid raw value remains visible');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null},{"orderNo":"130C41","lineNumber":"2","product":"SKU2","client":"TSD","qtyLcd":5,"origRef3":null,"released":"N","groupCode":null,"productName":"Product 2","sourceUpdatedAt":null}]');
select is((select count(*)::integer from source_order_release_lines where source_order_no='130C41'),2,'two lines of one order remain independent');
select pg_temp.c41_sync('[{"orderNo":"130C41","lineNumber":"1","product":"SKU","client":"TSD","qtyLcd":10,"origRef3":null,"released":"Y","groupCode":null,"productName":"Product","sourceUpdatedAt":null},{"orderNo":"130C41","lineNumber":"2","product":"SKU","client":"TSD","qtyLcd":5,"origRef3":null,"released":"N","groupCode":null,"productName":"Product","sourceUpdatedAt":null}]');
select is((select count(*)::integer from source_order_release_lines where source_order_no='130C41' and source_product_code='SKU'),2,'same product on different lines remains independent');

select * from finish();
rollback;
