CREATE OR REPLACE FUNCTION public.source_value_matches(p_actual text, p_match_type text, p_expected text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  select case p_match_type
    when 'EXACT' then upper(coalesce(p_actual,'')) = upper(p_expected)
    when 'PREFIX' then upper(coalesce(p_actual,'')) like upper(p_expected) || '%'
    when 'SUFFIX' then upper(coalesce(p_actual,'')) like '%' || upper(p_expected)
    when 'LIKE' then upper(coalesce(p_actual,'')) like upper(p_expected)
    else false
  end
$function$
;

