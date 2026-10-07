-- LOCAL CORRECTION ONLY. PostgreSQL execution is not certified by static tests.
-- Replacing this existing function preserves its owner/ACL; no access grants.
begin;

create or replace function public.labour_v3_validate_segments_v1(p_request jsonb,p_authority jsonb)
returns jsonb language plpgsql volatile set search_path = pg_catalog,public,pg_temp as $$
declare
  r jsonb; s jsonb; owner jsonb; win jsonb; points timestamptz[]; a timestamptz; b timestamptz;
  last_at timestamptz; raw_start timestamptz; raw_end timestamptz; op date; week date;
  i integer; n integer; hits integer; expected_paid numeric; expected_break numeric;
  allocated_paid numeric; allocated_break numeric; expected_regular numeric;
  day_key text; week_key text; day_used numeric; week_used numeric;
  days jsonb := '{}'; weeks jsonb := '{}'; eligible boolean; rules jsonb := p_authority->'rules';
  expected_count integer := 0; total_paid numeric := 0; total_productive numeric := 0;
  total_break numeric := 0; total_regular numeric := 0; total_ot numeric := 0;
  segment_rows jsonb := p_request->'segments'; distributions jsonb;
begin
  if p_request->>'authorityFingerprint' is distinct from p_authority->>'authorityFingerprint'
    or p_request->>'ruleFingerprint' is distinct from p_authority->>'ruleFingerprint'
    or p_request->'cohorts' is distinct from p_authority->'cohorts'
    or p_request->'raws' is distinct from p_authority->'raws' then raise exception 'STALE_OR_CHANGED_RAW_SET'; end if;
  if jsonb_typeof(p_request->'expectedTotals') is distinct from 'object'
    or exists(select 1 from unnest(array['paid','productive','paidBreak','regular','overtime']) f
      where p_request->'expectedTotals'->>f is null
       or jsonb_typeof(p_request->'expectedTotals'->f) is distinct from 'number'
       or lower(p_request->'expectedTotals'->>f) in ('nan','infinity','-infinity')
       or (p_request->'expectedTotals'->>f)::numeric<0)
    or p_request->>'expectedRawCount' is null or p_request->>'expectedSegmentCount' is null then
    raise exception 'INVALID_EXPECTED_TOTALS'; end if;
  if exists(select 1 from jsonb_array_elements(p_authority->'raws') AS raw_a(value),
      jsonb_array_elements(p_authority->'raws') AS raw_b(value) where raw_a.value->>'id'<raw_b.value->>'id'
      and raw_a.value->>'personKey'=raw_b.value->>'personKey' and (raw_a.value->>'startAt')::timestamptz<(raw_b.value->>'endAt')::timestamptz
      and (raw_b.value->>'startAt')::timestamptz<(raw_a.value->>'endAt')::timestamptz) then
    raise exception 'OVERLAP_DIAGNOSTIC_REQUIRES_REVIEW'; end if;
  if jsonb_typeof(segment_rows) is distinct from 'array' or jsonb_array_length(segment_rows)>20000 then
    raise exception 'INVALID_SEGMENTS'; end if;
  -- Reject unknown fields rather than silently discard injected identity/semantics.
  for s in select value from jsonb_array_elements(segment_rows) loop
    if s - array['organization_id','generation_id','source_timesheet_row_id','person_key','area_code',
      'segment_start','segment_end','calendar_date','hour_bucket','employee_shift_code',
      'employee_operational_date','window_shift_code','window_operational_date','scheduled_start_at',
      'scheduled_end_at','paid_hours','productive_hours','paid_break_hours','regular_hours',
      'overtime_hours','week_start','approval_status','allocation_method','calculation_version'] <> '{}'::jsonb
      or (select count(*) from jsonb_object_keys(s))<>24 then raise exception 'INVALID_SEGMENT_SHAPE'; end if;
    if exists(select 1 from unnest(array['paid_hours','productive_hours','paid_break_hours',
      'regular_hours','overtime_hours']) f where s->>f is null
      or jsonb_typeof(s->f) is distinct from 'number'
      or lower(s->>f) in ('nan','infinity','-infinity') or (s->>f)::numeric<0) then
      raise exception 'INVALID_NUMERIC'; end if;
    if (s->>'organization_id')::uuid is distinct from (p_authority->>'organizationId')::uuid
      or (s->>'generation_id')::uuid is distinct from (p_request->>'generationId')::uuid then
      raise exception 'CROSS_ORG_OR_GENERATION'; end if;
    if not exists(select 1 from jsonb_array_elements(p_authority->'raws') x
      where x->>'id'=s->>'source_timesheet_row_id') then raise exception 'UNEXPECTED_RAW'; end if;
  end loop;
  if exists(select 1 from jsonb_array_elements(segment_rows) x group by x->>'source_timesheet_row_id',
       (x->>'segment_start')::timestamptz having count(*)>1) then raise exception 'DUPLICATE_SEGMENT'; end if;
  for r in select value from jsonb_array_elements(p_authority->'raws')
       order by (value->>'startAt')::timestamptz,value->>'id' loop
    raw_start := (r->>'startAt')::timestamptz; raw_end := (r->>'endAt')::timestamptz;
    if (r->>'approval') not in ('APPROVED','PROVISIONAL') or nullif(r->>'personKey','') is null
       or (r->>'paidHours')::numeric not between 0 and 24
       or lower(r->>'paidHours') in ('nan','infinity','-infinity') then raise exception 'INVALID_RAW'; end if;
    owner := public.labour_v3_owner_v1(raw_start,rules); op := (owner->>'date')::date;
    week := date_trunc('week',op::timestamp)::date;
    day_key := jsonb_build_array(r->>'personKey',op)::text;
    week_key := jsonb_build_array(r->>'personKey',week)::text;
    allocated_paid := 0; allocated_break := 0;
    -- Reconstruct exact hour + all effective window cuts, independently of payload.
    select array_agg(t order by t) into points from (
      select raw_start t union select raw_end
      union select t from generate_series(date_trunc('hour',raw_start)+interval '1 hour',
                                          raw_end,interval '1 hour') t where t<raw_end
      union select w.starts from generate_series((raw_start at time zone 'Australia/Brisbane')::date-1,
        (raw_end at time zone 'Australia/Brisbane')::date,interval '1 day') d
        cross join lateral public.labour_v3_windows_v1(d::date,rules) w
        where w.starts>raw_start and w.starts<raw_end
      union select w.ends from generate_series((raw_start at time zone 'Australia/Brisbane')::date-1,
        (raw_end at time zone 'Australia/Brisbane')::date,interval '1 day') d
        cross join lateral public.labour_v3_windows_v1(d::date,rules) w
        where w.ends>raw_start and w.ends<raw_end
    ) cuts;
    n := array_length(points,1)-1;
    if (select count(*) from jsonb_array_elements(segment_rows) x
        where x->>'source_timesheet_row_id'=r->>'id')<>n then raise exception 'GAP_OR_EXTRA_SEGMENTS'; end if;
    for i in 1..n loop
      a := points[i]; b := points[i+1];
      select count(*) into hits from jsonb_array_elements(segment_rows) x
        where x->>'source_timesheet_row_id'=r->>'id' and (x->>'segment_start')::timestamptz=a
          and (x->>'segment_end')::timestamptz=b;
      if hits<>1 then raise exception 'INTERVAL_MISMATCH'; end if;
      select x into s from jsonb_array_elements(segment_rows) x
        where x->>'source_timesheet_row_id'=r->>'id' and (x->>'segment_start')::timestamptz=a;
      expected_paid := case when i=n then (r->>'paidHours')::numeric-allocated_paid
        else (r->>'paidHours')::numeric*extract(epoch from b-a)/extract(epoch from raw_end-raw_start) end;
      expected_break := case when i=n then (case when (r->>'paidHours')::numeric>=4 then 1::numeric/3 else 0 end)-allocated_break
        else (case when (r->>'paidHours')::numeric>=4 then 1::numeric/3 else 0 end)
          *extract(epoch from b-a)/extract(epoch from raw_end-raw_start) end;
      allocated_paid := allocated_paid+expected_paid; allocated_break := allocated_break+expected_break;
      day_used := coalesce((days->>day_key)::numeric,0); week_used := coalesce((weeks->>week_key)::numeric,0);
      eligible := owner->>'code'='OUT_OF_SHIFT' or (a>=(owner->>'start')::timestamptz and b<=(owner->>'end')::timestamptz);
      expected_regular := case when extract(isodow from op) in (6,7) or not eligible then 0
        else greatest(0,least(expected_paid,8-day_used,38-week_used)) end;
      days := days || jsonb_build_object(day_key,day_used+expected_regular);
      weeks := weeks || jsonb_build_object(week_key,week_used+expected_regular);
      win := public.labour_v3_owner_v1(a,rules);
      if public.labour_v3_owner_v1(b-interval '1 microsecond',rules)->>'code' is distinct from win->>'code'
         or public.labour_v3_owner_v1(b-interval '1 microsecond',rules)->>'date' is distinct from win->>'date'
         then raise exception 'WINDOW_BOUNDARY'; end if;
      if s->>'person_key' is distinct from r->>'personKey' or s->>'area_code' is distinct from r->>'area'
        or s->>'approval_status' is distinct from r->>'approval'
        or (s->>'employee_operational_date')::date is distinct from op
        or s->>'employee_shift_code' is distinct from owner->>'code'
        or (s->>'scheduled_start_at')::timestamptz is distinct from (owner->>'start')::timestamptz
        or (s->>'scheduled_end_at')::timestamptz is distinct from (owner->>'end')::timestamptz
        or (s->>'window_operational_date')::date is distinct from (win->>'date')::date
        or s->>'window_shift_code' is distinct from win->>'code'
        or (s->>'week_start')::date is distinct from week
        or (s->>'calendar_date')::date is distinct from (a at time zone 'Australia/Brisbane')::date
        or (s->>'hour_bucket')::integer is distinct from extract(hour from a at time zone 'Australia/Brisbane')::integer
        or s->>'allocation_method' is distinct from 'PRO_RATA_ELAPSED'
        or s->>'calculation_version' is distinct from p_request->>'algorithmVersion' then raise exception 'SEGMENT_IDENTITY_MISMATCH'; end if;
      if abs((s->>'paid_hours')::numeric-expected_paid)>1e-9
        or abs((s->>'paid_break_hours')::numeric-expected_break)>1e-9
        or abs((s->>'productive_hours')::numeric-(expected_paid-expected_break))>1e-9
        or abs((s->>'regular_hours')::numeric-expected_regular)>1e-9
        or abs((s->>'overtime_hours')::numeric-(expected_paid-expected_regular))>1e-9 then
        raise exception 'ALLOCATION_OR_CONSERVATION_MISMATCH'; end if;
      expected_count := expected_count+1; total_paid := total_paid+expected_paid;
      total_break := total_break+expected_break; total_productive := total_productive+expected_paid-expected_break;
      total_regular := total_regular+expected_regular; total_ot := total_ot+expected_paid-expected_regular;
    end loop;
  end loop;
  if expected_count<>jsonb_array_length(segment_rows)
    or expected_count<>(p_request->>'expectedSegmentCount')::integer
    or jsonb_array_length(p_authority->'raws')<>(p_request->>'expectedRawCount')::integer then raise exception 'COUNT_MISMATCH'; end if;
  if p_request->'expectedTotals' is distinct from null and (
    abs((p_request->'expectedTotals'->>'paid')::numeric-total_paid)>1e-9
    or abs((p_request->'expectedTotals'->>'productive')::numeric-total_productive)>1e-9
    or abs((p_request->'expectedTotals'->>'paidBreak')::numeric-total_break)>1e-9
    or abs((p_request->'expectedTotals'->>'regular')::numeric-total_regular)>1e-9
    or abs((p_request->'expectedTotals'->>'overtime')::numeric-total_ot)>1e-9) then raise exception 'TOTAL_MISMATCH'; end if;
  -- Complete fields were checked above; expose both distributions for independent diagnostics.
  select jsonb_object_agg(dimension,rows) into distributions from (
    select dimension,jsonb_agg(jsonb_build_object('date',op_date,'shift',shift_code,'area',area,
      'paid',paid,'productive',productive,'paidBreak',paid_break,'regular',regular,'overtime',ot,
      'headcount',people) order by op_date,shift_code,area) rows from (
      select dimension,
        case when dimension='employee' then x->>'employee_operational_date' else x->>'window_operational_date' end op_date,
        case when dimension='employee' then x->>'employee_shift_code' else x->>'window_shift_code' end shift_code,
        x->>'area_code' area,sum((x->>'paid_hours')::numeric) paid,sum((x->>'productive_hours')::numeric) productive,
        sum((x->>'paid_break_hours')::numeric) paid_break,sum((x->>'regular_hours')::numeric) regular,
        sum((x->>'overtime_hours')::numeric) ot,count(distinct x->>'person_key') people
        from jsonb_array_elements(segment_rows) x cross join (values('employee'),('window')) dim(dimension)
        group by 1,2,3,4
    ) grouped group by dimension
  ) dimensions;
  return jsonb_build_object('rawCount',jsonb_array_length(p_authority->'raws'),'segmentCount',expected_count,
    'distributions',distributions,
    'totals',jsonb_build_object('paid',total_paid,'productive',total_productive,
      'paidBreak',total_break,'regular',total_regular,'overtime',total_ot));
end $$;

commit;
