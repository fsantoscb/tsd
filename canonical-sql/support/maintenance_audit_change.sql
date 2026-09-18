CREATE OR REPLACE FUNCTION public.maintenance_audit_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$declare row_data jsonb;org uuid;eid uuid;begin row_data:=case when tg_op='DELETE'then to_jsonb(old)else to_jsonb(new)end;org:=(row_data->>'organization_id')::uuid;eid:=nullif(row_data->>'id','')::uuid;insert into maintenance_audit_log(organization_id,user_id,entity_type,entity_id,action,old_values,new_values)values(org,auth.uid(),tg_table_name,eid,tg_op,case when tg_op in('UPDATE','DELETE')then to_jsonb(old)end,case when tg_op in('INSERT','UPDATE')then to_jsonb(new)end);return case when tg_op='DELETE'then old else new end;end$function$
;

