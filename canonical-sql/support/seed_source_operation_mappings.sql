CREATE OR REPLACE FUNCTION public.seed_source_operation_mappings(p_organization_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare affected integer;
begin
  insert into source_operation_mappings(organization_id,source_dataset,source_field,match_type,match_value,operation_id,completion_semantics,priority)
  select p_organization_id, x.dataset, x.field_name, x.match_type, x.match_value, o.id, x.semantics, x.priority
  from (values
    ('WORKBANK','queue','EXACT','SP11','PICKING','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','SP11','PICKING','ENTERED_OPERATION',10),
    ('WORKBANK','queue','EXACT','PCOR','DTG_PRINT','CURRENT_LOCATION',10),
    ('AUDIT','queue','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',10),
    ('AUDIT','task','EXACT','PCOR','DTG_PRINT','ENTERED_OPERATION',20),
    ('AUDIT','to_zone','EXACT','PWL1','PUTWALL','ENTERED_OPERATION',10),
    ('AUDIT','from_zone','EXACT','PWL1','PUTWALL','COMPLETED_OPERATION',10),
    ('STOCK','source_zone','EXACT','PWL1','PUTWALL','CURRENT_LOCATION',10),
    ('AUDIT','to_location','EXACT','DTGMOVE','DISPATCH','MOVED_TO_OPERATION',10),
    ('STOCK','location','LIKE','%UNDERPRINT%','UNDERPRINT','CURRENT_LOCATION',10),
    ('WORKBANK','from_location','SUFFIX','UP','UNDERPRINT','CURRENT_LOCATION',20),
    ('AUDIT','to_location','EXACT','UPMOVE','DISPATCH','MOVED_TO_OPERATION',20)
  ) x(dataset,field_name,match_type,match_value,operation_code,semantics,priority)
  join operations o on o.organization_id=p_organization_id and o.code=x.operation_code
  on conflict do nothing;
  get diagnostics affected=row_count;
  return affected;
end $function$
;

