CREATE OR REPLACE FUNCTION public.ingest_authoritative_release_lines(p_organization_id uuid, p_sync_batch_id uuid, p_lines jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare n integer;begin
 if not exists(select 1 from sync_batches where id=p_sync_batch_id and organization_id=p_organization_id and status='completed')then raise exception 'INVALID_COMPLETED_SYNC_BATCH';end if;
 delete from source_order_release_lines where organization_id=p_organization_id and source_system='ORACLE_WMS';
 insert into source_order_release_lines(organization_id,sync_batch_id,source_system,source_order_no,source_line_id,source_product_code,source_description,production_units,released,raw_release_value,source_line_status,quantity_processed,source_weight,stock_reserved_flag,source_updated_at)
 select p_organization_id,p_sync_batch_id,'ORACLE_WMS',x."orderNo",x."lineNumber"::text,x."productCode",x."sourceDescription",greatest(coalesce(x.quantity,0),0),case upper(trim(coalesce(x.released,'')))when'Y'then true when'N'then false else null end,upper(trim(coalesce(x.released,''))),x."sourceStatus",x."quantityProcessed",x.weight,x."stockReservedFlag",x."sourceUpdatedAt"
 from jsonb_to_recordset(p_lines)x("orderNo" text,"lineNumber" integer,"productCode" text,"sourceDescription" text,quantity numeric,weight numeric,released text,"sourceStatus" text,"quantityProcessed" numeric,"stockReservedFlag" text,"sourceUpdatedAt" timestamptz);
 get diagnostics n=row_count;return n;end$function$
;

