-- LOCAL ONLY. NOT EXECUTION-CERTIFIED. No legacy mutation or authority cutover.
begin;

-- Classification helpers validate current rules, not Deputy snapshot authority.
create function public.labour_v3_windows_v1(p_date date, p_rules jsonb)
returns table(code text, operational_date date, starts timestamptz, ends timestamptz)
language plpgsql immutable set search_path = pg_catalog,public,pg_temp as $$
declare r jsonb; a timestamptz; b timestamptz;
begin
  for r in select value from jsonb_array_elements(p_rules) loop
    if r->>'start' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or r->>'end' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       or r->>'code' not in ('SHIFT_1','SHIFT_2','SHIFT_3') then
      raise exception 'INVALID_RULE';
    end if;
    if (r->>'weekday')::integer = extract(isodow from p_date)
       and (r->>'effectiveFrom')::date <= p_date
       and ((r->>'effectiveTo') is null or (r->>'effectiveTo')::date >= p_date) then
      a := (p_date + (r->>'start')::time) at time zone 'Australia/Brisbane';
      b := (p_date + case when (r->>'crossMidnight')::boolean then 1 else 0 end
            + (r->>'end')::time) at time zone 'Australia/Brisbane';
      if b <= a then raise exception 'INVALID_RULE_WINDOW'; end if;
      code := r->>'code'; operational_date := p_date; starts := a; ends := b;
      return next;
    end if;
  end loop;
end $$;

create function public.labour_v3_owner_v1(p_at timestamptz, p_rules jsonb)
returns jsonb language plpgsql immutable set search_path = pg_catalog,public,pg_temp as $$
declare d date := (p_at at time zone 'Australia/Brisbane')::date; matches jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb) into matches from (
    select * from public.labour_v3_windows_v1(d-1,p_rules)
    union all select * from public.labour_v3_windows_v1(d,p_rules)
  ) w where p_at >= w.starts and p_at < w.ends;
  if jsonb_array_length(matches)>1 then raise exception 'AMBIGUOUS_RULES'; end if;
  if jsonb_array_length(matches)=0 then
    return jsonb_build_object('code','OUT_OF_SHIFT','date',d,'start',null,'end',null);
  end if;
  return jsonb_build_object('code',matches->0->>'code','date',matches->0->>'operational_date',
                           'start',matches->0->>'starts','end',matches->0->>'ends');
end $$;

create function public.labour_v3_authority_snapshot_v1(p_organization_id uuid, p_cohorts jsonb)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp as $$
declare
  definition text; prefix text; tail text; marker integer; latest_pos integer;
  view_hash text; lo date; hi date; manifest jsonb; coverage jsonb; candidates jsonb;
  raws jsonb := '[]'; rules jsonb; snapshots jsonb; evidence jsonb := '[]';
  c jsonb; r jsonb; o jsonb; person_raws jsonb; rule_hash text; authority_hash text;
begin
  if p_organization_id is null or not exists(select 1 from public.organizations where id=p_organization_id)
     or jsonb_typeof(p_cohorts) is distinct from 'array'
     or jsonb_array_length(p_cohorts) not between 1 and 64 then raise exception 'INVALID_COHORTS'; end if;
  if exists(select 1 from jsonb_array_elements(p_cohorts) x where nullif(x->>'personKey','') is null
     or extract(isodow from (x->>'weekStart')::date)<>1)
     or (select count(*) from jsonb_array_elements(p_cohorts)) <>
        (select count(distinct (x->>'personKey',x->>'weekStart')) from jsonb_array_elements(p_cohorts) x)
     then raise exception 'INVALID_COHORTS'; end if;
  select jsonb_agg(jsonb_build_object('personKey',x->>'personKey','weekStart',x->>'weekStart')
                   order by x->>'personKey',x->>'weekStart'),
         min((x->>'weekStart')::date)-1, max((x->>'weekStart')::date)+7
    into manifest,lo,hi from jsonb_array_elements(p_cohorts) x;
  -- One bounded payroll week per call. Multiple people/all areas are required context.
  if hi-lo<>8 then raise exception 'ONE_WEEK_ONLY'; end if;
  definition := pg_get_viewdef('public.v_current_labour_segments'::regclass,true);
  view_hash := encode(sha256(convert_to(definition,'UTF8')),'hex');
  if view_hash <> '8b74e481be4daddaf915d46fdbb252f7f162b3d975d4e5f7da091696d35a5d0e' then
    raise exception 'AUTHORITY_DEFINITION_CHANGED';
  end if;
  marker := strpos(definition,E'\n SELECT s.id,');
  latest_pos := strpos(definition,'latest_generation AS (');
  if marker=0 or latest_pos=0 or strpos(definition,'canonical_raw AS (')=0 then
    raise exception 'AUTHORITY_DEFINITION_CHANGED';
  end if;
  prefix := substring(definition from 1 for marker-1);
  tail := substring(prefix from latest_pos);
  -- SAME latest_generation/latest_batches/certified_authority CTEs. Only the
  -- driving source-date domain extends to empty dates for completeness evidence.
  execute 'WITH source_dates AS (SELECT $1::uuid organization_id, d::date timesheet_date
    FROM generate_series($2::date,$3::date,interval ''1 day'') d), ' || tail || '
    SELECT jsonb_agg(jsonb_build_object(''date'',d.timesheet_date,''count'',
      (SELECT count(*) FROM latest_batches b WHERE b.organization_id=d.organization_id
       AND b.timesheet_date=d.timesheet_date),''batchId'',
      (SELECT min(b.import_batch_id::text) FROM certified_authority b
       WHERE b.organization_id=d.organization_id AND b.timesheet_date=d.timesheet_date))
       ORDER BY d.timesheet_date) FROM source_dates d'
    into coverage using p_organization_id,lo,hi;
  if exists(select 1 from jsonb_array_elements(coverage) x where (x->>'count')::integer<>1) then
    raise exception 'INCOMPLETE_OR_AMBIGUOUS_ENVELOPE';
  end if;
  -- No second raw-authority implementation and NO dependency on legacy segments.
  execute prefix || '
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      ''id'',r.id,''organizationId'',r.organization_id,''personKey'',r.person_key,
      ''area'',r.normalized_area,''startAt'',r.start_at,''endAt'',r.end_at,
      ''paidHours'',r.total_hours,''approval'',r.approval_status,
      ''sourceDate'',r.timesheet_date,''importBatchId'',r.import_batch_id,
      ''sourceIdentity'',jsonb_build_object(''sourceTimesheetId'',r.source_timesheet_id,
       ''employeeId'',r.employee_id,''displayName'',r.display_name,''rawArea'',r.raw_area,
       ''mealBreakHours'',r.meal_break_hours,''rowStatus'',r.row_status))
      ORDER BY r.start_at,r.id),''[]''::jsonb)
    FROM canonical_raw c JOIN public.deputy_raw_timesheets r ON r.id=c.id AND c.rn=1
    WHERE r.organization_id=$1 AND r.timesheet_date BETWEEN $2 AND $3'
    into candidates using p_organization_id,lo,hi;
  select coalesce(jsonb_agg(jsonb_build_object('weekday',s.weekday,'code',s.shift_code,
     'start',to_char(s.start_time,'HH24:MI'),'end',to_char(s.end_time,'HH24:MI'),
     'crossMidnight',s.cross_midnight,'effectiveFrom',s.effective_from,'effectiveTo',s.effective_to)
     order by s.weekday,s.shift_code,s.effective_from,s.id),'[]'::jsonb)
    into rules from public.shift_rules s where s.organization_id=p_organization_id and s.active
      and s.effective_from<=hi+1 and (s.effective_to is null or s.effective_to>=lo-1);
  if jsonb_array_length(rules)=0 or exists(select 1 from public.shift_rules s
      where s.organization_id=p_organization_id and s.active and s.effective_from<=hi+1
      and (s.effective_to is null or s.effective_to>=lo-1)
      and (extract(second from s.start_time)<>0 or extract(second from s.end_time)<>0)) then
    raise exception 'INVALID_RULE_PRECISION';
  end if;
  for r in select value from jsonb_array_elements(candidates) loop
    if r->>'startAt' is null or r->>'endAt' is null or r->>'paidHours' is null
       or nullif(r->>'personKey','') is null or nullif(r->>'area','') is null
       or lower(r->>'paidHours') in ('nan','infinity','-infinity')
       or (r->>'paidHours')::numeric not between 0 and 24
       or (r->>'sourceDate')::date is distinct from ((r->>'startAt')::timestamptz at time zone 'Australia/Brisbane')::date
       or (r->>'endAt')::timestamptz <= (r->>'startAt')::timestamptz
       or (r->>'endAt')::timestamptz-(r->>'startAt')::timestamptz>interval '24 hours' then
      raise exception 'INVALID_SOURCE_ENVELOPE';
    end if;
    o := public.labour_v3_owner_v1((r->>'startAt')::timestamptz,rules);
    if exists(select 1 from jsonb_array_elements(manifest) x where x->>'personKey'=r->>'personKey'
      and (x->>'weekStart')::date=date_trunc('week',(o->>'date')::date::timestamp)::date) then
      raws := raws || jsonb_build_array(r);
    end if;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'snapshotType',b.snapshot_type,
      'reportGeneratedAt',b.report_generated_at,'coverageStart',b.coverage_start,
      'coverageEnd',b.coverage_end,'certifiedAt',b.certified_at,'certifiedBy',b.certified_by)
      order by b.id),'[]'::jsonb) into snapshots from public.deputy_import_batches b
    where b.organization_id=p_organization_id and b.status='COMPLETED' and b.snapshot_type='FULL'
      and b.coverage_start<=hi and b.coverage_end>=lo;
  rule_hash := encode(sha256(convert_to(rules::text,'UTF8')),'hex');
  for c in select value from jsonb_array_elements(manifest) loop
    select coalesce(jsonb_agg(x order by x->>'startAt',x->>'id'),'[]'::jsonb) into person_raws
      from jsonb_array_elements(raws) x where x->>'personKey'=c->>'personKey';
    if jsonb_array_length(person_raws)=0 then raise exception 'EMPTY_COHORT_NOT_CERTIFIED'; end if;
    evidence := evidence || jsonb_build_array(c || jsonb_build_object('complete',true,
      'authorityFingerprint',encode(sha256(convert_to(jsonb_build_object('raws',person_raws,
       'snapshots',snapshots,'coverage',coverage,'view',view_hash,'cohort',c)::text,'UTF8')),'hex'),
      'ruleFingerprint',rule_hash));
  end loop;
  authority_hash := encode(sha256(convert_to(jsonb_build_object('raws',raws,'snapshots',snapshots,
       'coverage',coverage,'view',view_hash,'manifest',evidence)::text,'UTF8')),'hex');
  return jsonb_build_object('contractVersion','LABOUR_V3_SHADOW_V1','organizationId',p_organization_id,
    'coverageStart',lo,'coverageEnd',hi,'cohorts',evidence,'raws',raws,'rules',rules,
    'authorityFingerprint',authority_hash,'ruleFingerprint',rule_hash,'viewFingerprint',view_hash);
end $$;

create function public.labour_v3_validate_segments_v1(p_request jsonb,p_authority jsonb)
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
  if exists(select 1 from jsonb_array_elements(p_authority->'raws') a,
      jsonb_array_elements(p_authority->'raws') b where a->>'id'<b->>'id'
      and a->>'personKey'=b->>'personKey' and (a->>'startAt')::timestamptz<(b->>'endAt')::timestamptz
      and (b->>'startAt')::timestamptz<(a->>'endAt')::timestamptz) then
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

create function public.persist_labour_v3_generation_v1(p_request jsonb)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp set lock_timeout = '1s' as $$
declare
  gid uuid; org uuid; g public.labour_segment_generations%rowtype;
  authority jsonb; checked jsonb; readback jsonb; c jsonb; r jsonb; cohort_key text;
  lock_started timestamptz; failure_state text;
begin
  if current_setting('transaction_isolation')<>'read committed' then raise exception 'READ_COMMITTED_REQUIRED'; end if;
  if p_request->>'contractVersion' is distinct from 'LABOUR_V3_SHADOW_V1'
    or p_request->>'generationVersion' is distinct from 'LABOUR_V3_SHADOW_V1'
    or nullif(p_request->>'algorithmVersion','') is null
    or jsonb_typeof(p_request->'cohorts') is distinct from 'array'
    or jsonb_array_length(p_request->'cohorts') not between 1 and 64
    or p_request->>'authorityFingerprint' is null or p_request->>'ruleFingerprint' is null
    or p_request->>'authorityFingerprint' !~ '^[a-f0-9]{64}$'
    or p_request->>'ruleFingerprint' !~ '^[a-f0-9]{64}$'
    or jsonb_typeof(p_request->'raws') is distinct from 'array'
    or jsonb_array_length(p_request->'raws') not between 1 and 2048
    or jsonb_typeof(p_request->'segments') is distinct from 'array'
    or jsonb_array_length(p_request->'segments') not between 1 and 20000
    or length(p_request::text)>8000000 then raise exception 'INVALID_REQUEST'; end if;
  gid := (p_request->>'generationId')::uuid; org := (p_request->>'organizationId')::uuid;
  if gid is null or org is null or not exists(select 1 from public.organizations where id=org) then raise exception 'INVALID_ORGANIZATION'; end if;
  -- Fail-fast for the same UUID before any insert or row wait; no automatic retry.
  if not pg_try_advisory_xact_lock(hashtextextended('labour-v3-id|'||gid::text,0)) then
    return jsonb_build_object('generationId',gid,'status','REJECTED','diagnostics',jsonb_build_array('PRESTATE_BUSY')); end if;
  insert into public.labour_segment_generations(id,organization_id,generation_version,algorithm_version,
    coverage_start,coverage_end,source_authority_fingerprint,rule_fingerprint,cohort_manifest)
    values(gid,org,p_request->>'generationVersion',p_request->>'algorithmVersion',
      (p_request->>'coverageStart')::date,(p_request->>'coverageEnd')::date,
      p_request->>'authorityFingerprint',p_request->>'ruleFingerprint',p_request->'cohorts') on conflict(id) do nothing;
  select * into g from public.labour_segment_generations where id=gid for update;
  if g.status<>'BUILDING' or g.organization_id<>org or g.validation_complete
    or g.generation_version<>p_request->>'generationVersion' or g.algorithm_version<>p_request->>'algorithmVersion'
    or g.source_authority_fingerprint<>p_request->>'authorityFingerprint'
    or g.rule_fingerprint<>p_request->>'ruleFingerprint' or g.cohort_manifest<>p_request->'cohorts'
    or g.coverage_start<>(p_request->>'coverageStart')::date or g.coverage_end<>(p_request->>'coverageEnd')::date
    or exists(select 1 from public.labour_segments_v3 where generation_id=gid) then
    return jsonb_build_object('generationId',gid,'status','REJECTED','diagnostics',jsonb_build_array('PRESTATE_MISMATCH')); end if;
  begin
    for cohort_key in select distinct org::text||'|'||(x->>'personKey')||'|'||(x->>'weekStart')
      from jsonb_array_elements(p_request->'cohorts') x order by 1 loop
      if not pg_try_advisory_xact_lock(hashtextextended('labour-v3-cohort|'||cohort_key,0)) then raise exception 'COHORT_BUSY'; end if;
    end loop;
    lock_started := clock_timestamp();
    -- Minimum critical section: all calculation/preparation occurred in TypeScript before this call.
    lock table public.deputy_import_batches,public.deputy_raw_timesheets,public.shift_rules IN SHARE MODE;
    authority := public.labour_v3_authority_snapshot_v1(org,p_request->'cohorts');
    if (authority->>'coverageStart')::date<>g.coverage_start or (authority->>'coverageEnd')::date<>g.coverage_end then raise exception 'COVERAGE_MISMATCH'; end if;
    for c in select value from jsonb_array_elements(authority->'cohorts') loop
      if exists(select 1 from public.labour_segment_generations other,
         lateral jsonb_array_elements(other.cohort_manifest) oc
         where other.organization_id=org and other.id<>gid and other.status='READY'
         and other.algorithm_version=g.algorithm_version and oc @> c) then raise exception 'DUPLICATE_READY_COHORT'; end if;
    end loop;
    -- Tenant/source prevalidation for ALL referenced IDs before any segment insertion.
    for r in select value from jsonb_array_elements(p_request->'raws') loop
      if not exists(select 1 from public.deputy_raw_timesheets source
        where source.id=(r->>'id')::uuid and source.organization_id=org) then raise exception 'CROSS_ORG_OR_MISSING_RAW'; end if;
    end loop;
    checked := public.labour_v3_validate_segments_v1(p_request,authority);
    insert into public.labour_segments_v3
      select gen_random_uuid(), org, gid, x.source_timesheet_row_id,x.person_key,x.area_code,
        x.segment_start,x.segment_end,x.calendar_date,x.hour_bucket,x.employee_shift_code,
        x.employee_operational_date,x.window_shift_code,x.window_operational_date,x.scheduled_start_at,
        x.scheduled_end_at,x.paid_hours,x.regular_hours,x.overtime_hours,x.paid_break_hours,
        x.productive_hours,x.week_start,x.approval_status,x.allocation_method,x.calculation_version
      from jsonb_populate_recordset(null::public.labour_segments_v3,p_request->'segments') x;
    select coalesce(jsonb_agg(to_jsonb(s)-'id' order by s.segment_start,s.source_timesheet_row_id),'[]'::jsonb)
      into readback from public.labour_segments_v3 s where s.generation_id=gid;
    perform public.labour_v3_validate_segments_v1(p_request||jsonb_build_object('segments',readback),authority);
    update public.labour_segment_generations set status='READY',validation_complete=true,
      diagnostics=checked||jsonb_build_object('criticalSectionMs',extract(epoch from clock_timestamp()-lock_started)*1000)
      where id=gid and status='BUILDING';
    return checked||jsonb_build_object('generationId',gid,'status','READY','diagnostics','[]'::jsonb,
      'authorityFingerprint',authority->>'authorityFingerprint','ruleFingerprint',authority->>'ruleFingerprint');
  exception when others then
    -- Subtransaction rolls back ALL segment rows/READY changes before this handler.
    get stacked diagnostics failure_state = returned_sqlstate;
    update public.labour_segment_generations set status='FAILED',validation_complete=false,
      diagnostics=jsonb_build_object('code',case when sqlstate='P0001' then sqlerrm else 'WRITER_VALIDATION_FAILED' end,'sqlstate',failure_state)
      where id=gid and status='BUILDING';
    return jsonb_build_object('generationId',gid,'status','FAILED','segmentCount',0,
      'diagnostics',jsonb_build_array(case when sqlstate='P0001' then sqlerrm else 'WRITER_VALIDATION_FAILED' end),'sqlstate',failure_state);
  end;
end $$;

alter function public.labour_v3_windows_v1(date,jsonb) owner to postgres;
alter function public.labour_v3_owner_v1(timestamptz,jsonb) owner to postgres;
alter function public.labour_v3_authority_snapshot_v1(uuid,jsonb) owner to postgres;
alter function public.labour_v3_validate_segments_v1(jsonb,jsonb) owner to postgres;
alter function public.persist_labour_v3_generation_v1(jsonb) owner to postgres;
revoke all on function public.labour_v3_windows_v1(date,jsonb),public.labour_v3_owner_v1(timestamptz,jsonb),
  public.labour_v3_validate_segments_v1(jsonb,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.labour_v3_authority_snapshot_v1(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.persist_labour_v3_generation_v1(jsonb) from public,anon,authenticated;
grant execute on function public.labour_v3_authority_snapshot_v1(uuid,jsonb) to service_role;
grant execute on function public.persist_labour_v3_generation_v1(jsonb) to service_role;
revoke insert,update,delete,truncate,references,trigger on public.labour_segment_generations,public.labour_segments_v3 from service_role;
grant select on public.labour_segment_generations,public.labour_segments_v3 to service_role;
commit;
