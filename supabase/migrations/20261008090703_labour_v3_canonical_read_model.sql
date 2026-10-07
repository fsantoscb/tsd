-- Phase 3A LOCAL DRAFT. No selection seed, ACTIVE transition or consumer cutover.
-- NOT EXECUTION-CERTIFIED until the guarded disposable SQL suites run.
begin;

create table public.labour_v3_canonical_cohorts (
  organization_id uuid not null references public.organizations(id),
  person_key text not null check (length(btrim(person_key)) between 1 and 512),
  payroll_week date not null check (extract(isodow from payroll_week)=1),
  generation_id uuid not null,
  selected_at timestamptz not null,
  selected_by text not null check (length(btrim(selected_by)) between 1 and 512),
  selection_version bigint not null check (selection_version>0),
  enabled boolean not null,
  reason text not null check (length(btrim(reason)) between 1 and 2000),
  primary key (organization_id,person_key,payroll_week),
  foreign key (organization_id,generation_id)
    references public.labour_segment_generations(organization_id,id)
);
alter table public.labour_v3_canonical_cohorts owner to postgres;
alter table public.labour_v3_canonical_cohorts enable row level security;
revoke all on public.labour_v3_canonical_cohorts from public,anon,authenticated,service_role;
grant select on public.labour_v3_canonical_cohorts to service_role;

-- Internal read-only revalidation. Exact full manifest and existing validator,
-- not a second snapshot-authority or Labour calculation implementation.
create function public.labour_v3_check_generation_v1(p_org uuid,p_generation uuid)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp as $$
declare
  g public.labour_segment_generations%rowtype;
  authority jsonb; segments jsonb; totals jsonb; request jsonb; checked jsonb;
begin
  select x.* into g from public.labour_segment_generations x
    where x.id=p_generation and x.organization_id=p_org;
  if not found then raise exception 'GENERATION_ORGANIZATION_MISMATCH'; end if;
  if g.status<>'READY' or not g.validation_complete
    or g.generation_version<>'LABOUR_V3_SHADOW_V1'
    or g.algorithm_version<>'LABOUR_V3_STAGE2_V1' then
    raise exception 'INELIGIBLE_GENERATION';
  end if;
  authority := public.labour_v3_authority_snapshot_v1(p_org,g.cohort_manifest);
  if authority->>'authorityFingerprint' is distinct from g.source_authority_fingerprint
    or authority->>'ruleFingerprint' is distinct from g.rule_fingerprint
    or authority->'cohorts' is distinct from g.cohort_manifest
    or (authority->>'coverageStart')::date is distinct from g.coverage_start
    or (authority->>'coverageEnd')::date is distinct from g.coverage_end then
    raise exception 'STALE_GENERATION';
  end if;
  select coalesce(jsonb_agg(to_jsonb(s)-'id' order by s.segment_start,s.source_timesheet_row_id),'[]'::jsonb),
    jsonb_build_object('paid',coalesce(sum(s.paid_hours),0),'paidBreak',coalesce(sum(s.paid_break_hours),0),
      'productive',coalesce(sum(s.productive_hours),0),'regular',coalesce(sum(s.regular_hours),0),
      'overtime',coalesce(sum(s.overtime_hours),0))
    into segments,totals from public.labour_segments_v3 s where s.generation_id=g.id;
  if jsonb_array_length(segments)=0 then raise exception 'MISSING_GENERATION_SEGMENTS'; end if;
  if exists(select 1 from public.labour_segments_v3 s where s.generation_id=g.id
    and (s.organization_id<>p_org or not exists(select 1 from jsonb_array_elements(g.cohort_manifest) m(value)
      where m.value->>'personKey'=s.person_key and (m.value->>'weekStart')::date=s.week_start))) then
    raise exception 'SEGMENT_OUTSIDE_MANIFEST';
  end if;
  request := authority || jsonb_build_object('generationId',g.id,'algorithmVersion',g.algorithm_version,
    'segments',segments,'expectedTotals',totals,'expectedRawCount',jsonb_array_length(authority->'raws'),
    'expectedSegmentCount',jsonb_array_length(segments));
  checked := public.labour_v3_validate_segments_v1(request,authority);
  return jsonb_build_object('generationId',g.id,'authorityFingerprint',g.source_authority_fingerprint,
    'ruleFingerprint',g.rule_fingerprint,'rawCount',checked->'rawCount','segmentCount',checked->'segmentCount');
end $$;
alter function public.labour_v3_check_generation_v1(uuid,uuid) owner to postgres;
revoke all on function public.labour_v3_check_generation_v1(uuid,uuid) from public,anon,authenticated,service_role;

create function public.labour_v3_select_cohort_v1(p_request jsonb)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp set lock_timeout = '1s' as $$
declare
  org uuid; person text; week_date date; target_generation uuid; expected_generation uuid;
  expected_version bigint; enable_selection boolean; actor text; reason_text text;
  previous public.labour_v3_canonical_cohorts%rowtype;
  target public.labour_segment_generations%rowtype;
  had_previous boolean; next_version bigint; at_time timestamptz;
begin
  if jsonb_typeof(p_request) is distinct from 'object' or length(p_request::text)>10000
    or p_request-array['organizationId','personKey','payrollWeek','generationId','expectedGenerationId',
      'expectedSelectionVersion','enabled','actor','reason']<>'{}'::jsonb
    or not p_request ?& array['organizationId','personKey','payrollWeek','generationId','expectedGenerationId',
      'expectedSelectionVersion','enabled','actor','reason']
    or jsonb_typeof(p_request->'enabled') is distinct from 'boolean'
    or jsonb_typeof(p_request->'expectedSelectionVersion') is distinct from 'number'
    or p_request->>'expectedSelectionVersion' !~ '^(0|[1-9][0-9]*)$'
    or jsonb_typeof(p_request->'personKey') is distinct from 'string'
    or jsonb_typeof(p_request->'actor') is distinct from 'string'
    or jsonb_typeof(p_request->'reason') is distinct from 'string' then
    raise exception 'INVALID_SELECTION_REQUEST';
  end if;
  org := (p_request->>'organizationId')::uuid;
  person := p_request->>'personKey'; week_date := (p_request->>'payrollWeek')::date;
  target_generation := (p_request->>'generationId')::uuid;
  expected_generation := (p_request->>'expectedGenerationId')::uuid;
  expected_version := (p_request->>'expectedSelectionVersion')::bigint;
  enable_selection := (p_request->>'enabled')::boolean;
  actor := p_request->>'actor'; reason_text := p_request->>'reason';
  if org is null or target_generation is null or week_date is null
    or extract(isodow from week_date)<>1
    or length(btrim(person)) not between 1 and 512
    or length(btrim(actor)) not between 1 and 512
    or length(btrim(reason_text)) not between 1 and 2000 then raise exception 'INVALID_SELECTION_REQUEST'; end if;
  -- Locks guarantee current-authority validation only with fresh statement snapshots.
  if current_setting('transaction_isolation')<>'read committed' then raise exception 'SELECTOR_READ_COMMITTED_REQUIRED'; end if;
  perform pg_advisory_xact_lock(hashtextextended(jsonb_build_array('labour-v3-selection',org,person,week_date)::text,0));
  select c.* into previous from public.labour_v3_canonical_cohorts c
    where c.organization_id=org and c.person_key=person and c.payroll_week=week_date for update;
  had_previous := found;
  if had_previous then
    if previous.generation_id IS DISTINCT FROM expected_generation
      or previous.selection_version IS DISTINCT FROM expected_version then raise exception 'CAS_CONFLICT'; end if;
    if previous.selection_version=9223372036854775807 then raise exception 'SELECTION_VERSION_EXHAUSTED'; end if;
    next_version := previous.selection_version+1;
  else
    if expected_generation is not null or expected_version<>0 or not enable_selection then
      raise exception 'CAS_CONFLICT';
    end if;
    next_version := 1;
  end if;
  if enable_selection then
    lock table public.deputy_import_batches,public.deputy_raw_timesheets,public.shift_rules in share mode;
    select g.* into target from public.labour_segment_generations g
      where g.id=target_generation and g.organization_id=org for share;
    if not found then raise exception 'GENERATION_ORGANIZATION_MISMATCH'; end if;
    perform public.labour_v3_check_generation_v1(org,target_generation);
    if not exists(select 1 from jsonb_array_elements(target.cohort_manifest) m(value)
      where m.value->>'personKey'=person and (m.value->>'weekStart')::date=week_date
        and m.value->'complete'='true'::jsonb) then raise exception 'COHORT_NOT_IN_CERTIFIED_MANIFEST'; end if;
  elsif target_generation IS DISTINCT FROM previous.generation_id then
    raise exception 'DISABLE_CANNOT_REPLACE_GENERATION';
  end if;
  at_time := clock_timestamp();
  if had_previous then
    update public.labour_v3_canonical_cohorts c set generation_id=target_generation,selected_at=at_time,
      selected_by=actor,selection_version=next_version,enabled=enable_selection,reason=reason_text
      where c.organization_id=org and c.person_key=person and c.payroll_week=week_date
        and c.generation_id=expected_generation and c.selection_version=expected_version;
    if not found then raise exception 'CAS_CONFLICT'; end if;
  else
    insert into public.labour_v3_canonical_cohorts
      (organization_id,person_key,payroll_week,generation_id,selected_at,selected_by,selection_version,enabled,reason)
      values(org,person,week_date,target_generation,at_time,actor,next_version,enable_selection,reason_text);
  end if;
  return jsonb_build_object('organizationId',org,'personKey',person,'payrollWeek',week_date,
    'generationId',target_generation,'selectionVersion',next_version,'enabled',enable_selection,'selectedAt',at_time);
end $$;
alter function public.labour_v3_select_cohort_v1(jsonb) owner to postgres;
revoke all on function public.labour_v3_select_cohort_v1(jsonb) from public,anon,authenticated,service_role;
grant execute on function public.labour_v3_select_cohort_v1(jsonb) to service_role;

create view public.v_canonical_labour_segments_v3 as
  select s.*,c.selection_version from public.labour_v3_canonical_cohorts c
  join public.labour_segment_generations g on g.organization_id=c.organization_id and g.id=c.generation_id
  join public.labour_segments_v3 s on s.organization_id=c.organization_id and s.generation_id=c.generation_id
    and s.person_key=c.person_key and s.week_start=c.payroll_week
  where c.enabled and g.status='READY' and g.validation_complete;

create view public.v_current_labour_employee_segments_v3 as
  select id,organization_id,generation_id,source_timesheet_row_id,person_key,area_code,segment_start,segment_end,
    employee_shift_code,employee_operational_date,paid_hours,paid_break_hours,productive_hours,
    regular_hours,overtime_hours,week_start as payroll_week,approval_status,calculation_version,
    scheduled_start_at,scheduled_end_at,selection_version
  from public.v_canonical_labour_segments_v3;

create view public.v_current_labour_window_segments_v3 as
  select id,organization_id,generation_id,source_timesheet_row_id,person_key,area_code,segment_start,segment_end,
    window_shift_code,window_operational_date,employee_shift_code,employee_operational_date,
    week_start as employee_payroll_week,productive_hours,paid_hours,paid_break_hours,
    regular_hours as employee_regular_hours,overtime_hours as employee_overtime_hours,
    approval_status,calculation_version,selection_version
  from public.v_canonical_labour_segments_v3;

alter view public.v_canonical_labour_segments_v3 owner to postgres;
alter view public.v_current_labour_employee_segments_v3 owner to postgres;
alter view public.v_current_labour_window_segments_v3 owner to postgres;
revoke all on public.v_canonical_labour_segments_v3,public.v_current_labour_employee_segments_v3,
  public.v_current_labour_window_segments_v3 from public,anon,authenticated,service_role;
grant select on public.v_current_labour_employee_segments_v3,public.v_current_labour_window_segments_v3 to service_role;
comment on view public.v_current_labour_employee_segments_v3 is 'Selected persisted Employee ownership; not a freshness certificate. Legacy remains active.';
comment on view public.v_current_labour_window_segments_v3 is 'Same canonical segments projected through physical Window, including adjacent Employee cohorts. OT fields are Employee payroll traceability. Not a coverage certificate.';

-- Certification is deliberately NOT an ordinary PostgREST transaction contract.
-- A caller must establish REPEATABLE READ/SERIALIZABLE READ ONLY externally.
create function public.labour_v3_window_domain_v1(p_org uuid,p_from date,p_to date)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp as $$
declare
  definition text; prefix text; tail text; marker integer; latest_pos integer;
  lo date; hi date; coverage jsonb; candidates jsonb; rules jsonb; required jsonb := '[]';
  r jsonb; owner jsonb; cohort jsonb; week_date date; points timestamptz[];
  raw_start timestamptz; raw_end timestamptz; i integer; relevant boolean;
begin
  if p_org is null or p_from is null or p_to is null or p_to<p_from or p_to-p_from>30 then
    raise exception 'PERIOD_OUT_OF_BOUNDS';
  end if;
  if not exists(select 1 from public.organizations o where o.id=p_org) then
    raise exception 'UNKNOWN_ORGANIZATION';
  end if;
  lo := date_trunc('week',(p_from-1)::timestamp)::date-1;
  hi := date_trunc('week',(p_to+1)::timestamp)::date+7;
  if (hi-lo)/7+1>8 then raise exception 'PERIOD_OUT_OF_BOUNDS'; end if;
  definition := pg_get_viewdef('public.v_current_labour_segments'::regclass,true);
  if encode(sha256(convert_to(definition,'UTF8')),'hex')<>'8b74e481be4daddaf915d46fdbb252f7f162b3d975d4e5f7da091696d35a5d0e' then
    raise exception 'AUTHORITY_DEFINITION_CHANGED';
  end if;
  marker := strpos(definition,E'\n SELECT s.id,');
  latest_pos := strpos(definition,'latest_generation AS (');
  if marker=0 or latest_pos=0 or strpos(definition,'canonical_raw AS (')=0 then
    raise exception 'AUTHORITY_DEFINITION_CHANGED';
  end if;
  prefix := substring(definition from 1 for marker-1);
  tail := substring(prefix from latest_pos);
  -- Existing authority CTEs, not a rewritten latest-FULL algorithm. The same
  -- bounded driving dates cover absence as well as observed source rows.
  prefix := 'WITH source_dates AS (SELECT $1::uuid organization_id,d::date timesheet_date
    FROM generate_series($2::date,$3::date,interval ''1 day'') d), ' || tail;
  execute prefix || ' SELECT jsonb_agg(jsonb_build_object(''date'',d.timesheet_date,''count'',
    (SELECT count(*) FROM latest_batches b WHERE b.organization_id=d.organization_id
      AND b.timesheet_date=d.timesheet_date)) ORDER BY d.timesheet_date) FROM source_dates d'
    into coverage using p_org,lo,hi;
  execute prefix || ' SELECT coalesce(jsonb_agg(jsonb_build_object(
    ''id'',r.id,''personKey'',r.person_key,''sourceDate'',r.timesheet_date,
    ''startAt'',r.start_at,''endAt'',r.end_at) ORDER BY r.start_at,r.id),''[]''::jsonb)
    FROM canonical_raw c JOIN public.deputy_raw_timesheets r ON r.id=c.id AND c.rn=1
    WHERE r.organization_id=$1 AND r.timesheet_date BETWEEN $4 AND $5'
    into candidates using p_org,lo,hi,p_from-1,p_to+1;
  select coalesce(jsonb_agg(jsonb_build_object('weekday',s.weekday,'code',s.shift_code,
    'start',to_char(s.start_time,'HH24:MI'),'end',to_char(s.end_time,'HH24:MI'),
    'crossMidnight',s.cross_midnight,'effectiveFrom',s.effective_from,'effectiveTo',s.effective_to)
    order by s.weekday,s.shift_code,s.effective_from,s.id),'[]'::jsonb) into rules
    from public.shift_rules s where s.organization_id=p_org and s.active
      and s.effective_from<=hi+1 and (s.effective_to is null or s.effective_to>=lo-1);
  if jsonb_array_length(rules)=0 or exists(select 1 from public.shift_rules s
    where s.organization_id=p_org and s.active and s.effective_from<=hi+1
      and (s.effective_to is null or s.effective_to>=lo-1)
      and (extract(second from s.start_time)<>0 or extract(second from s.end_time)<>0)) then
    raise exception 'INVALID_RULE_PRECISION';
  end if;
  for r in select value from jsonb_array_elements(candidates) loop
    raw_start := (r->>'startAt')::timestamptz; raw_end := (r->>'endAt')::timestamptz;
    if raw_start is null or raw_end is null or raw_end<=raw_start
      or raw_end-raw_start>interval '24 hours' or nullif(r->>'personKey','') is null
      or (r->>'sourceDate')::date is distinct from (raw_start at time zone 'Australia/Brisbane')::date then
      raise exception 'INVALID_SOURCE_ENVELOPE';
    end if;
    owner := public.labour_v3_owner_v1(raw_start,rules);
    week_date := date_trunc('week',(owner->>'date')::date::timestamp)::date;
    -- Cut only for domain membership, never recalculate persisted metrics.
    -- Midnight cuts also cover OUT_OF_SHIFT calendar ownership.
    select array_agg(distinct x.at_time order by x.at_time) into points from (
      select raw_start at_time union all select raw_end
      union all select w.starts from generate_series(p_from-2,p_to+2,interval '1 day') d
        cross join lateral public.labour_v3_windows_v1(d::date,rules) w
        where w.starts>raw_start and w.starts<raw_end
      union all select w.ends from generate_series(p_from-2,p_to+2,interval '1 day') d
        cross join lateral public.labour_v3_windows_v1(d::date,rules) w
        where w.ends>raw_start and w.ends<raw_end
      union all select d::date::timestamp at time zone 'Australia/Brisbane'
        from generate_series(p_from-2,p_to+2,interval '1 day') d
        where (d::date::timestamp at time zone 'Australia/Brisbane')>raw_start
          and (d::date::timestamp at time zone 'Australia/Brisbane')<raw_end
    ) x;
    relevant := false;
    for i in 1..array_length(points,1)-1 loop
      owner := public.labour_v3_owner_v1(points[i],rules);
      if (owner->>'date')::date between p_from and p_to then relevant:=true; end if;
    end loop;
    if relevant then
      cohort := jsonb_build_object('personKey',r->>'personKey','weekStart',week_date);
      if not required @> jsonb_build_array(cohort) then required:=required||jsonb_build_array(cohort); end if;
    end if;
  end loop;
  select coalesce(jsonb_agg(x.value order by x.value->>'weekStart',x.value->>'personKey'),'[]'::jsonb)
    into required from jsonb_array_elements(required) x(value);
  return jsonb_build_object('requiredCohorts',required,'sourceCoverage',coverage,
    'coverageStart',lo,'coverageEnd',hi,'viewFingerprint',encode(sha256(convert_to(definition,'UTF8')),'hex'));
end $$;
alter function public.labour_v3_window_domain_v1(uuid,date,date) owner to postgres;
revoke all on function public.labour_v3_window_domain_v1(uuid,date,date) from public,anon,authenticated,service_role;

create function public.labour_v3_certify_window_v1(p_org uuid,p_from date,p_to date)
returns jsonb language plpgsql volatile security definer
set search_path = pg_catalog,public,pg_temp as $$
declare
  domain jsonb; cohort jsonb; evidence jsonb; checked jsonb; checks jsonb := '[]';
  vector jsonb := '[]'; statuses text[] := '{}'; cause text; message text;
  selection public.labour_v3_canonical_cohorts%rowtype;
  checked_ids uuid[] := '{}'; first_week date; last_week date; week_date date;
  blocking boolean; at_time timestamptz;
begin
  if current_setting('transaction_isolation') not in ('repeatable read','serializable')
    or current_setting('transaction_read_only')<>'on' then
    raise exception 'CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED';
  end if;
  at_time := clock_timestamp();
  begin
    domain := public.labour_v3_window_domain_v1(p_org,p_from,p_to);
  exception when sqlstate 'P0001' then
    get stacked diagnostics message = message_text;
    if message<>'AMBIGUOUS_RULES' then raise; end if;
    return jsonb_build_object('contractVersion','LABOUR_V3_WINDOW_CERTIFICATE_V1','organizationId',p_org,
      'from',p_from,'to',p_to,'checkedAt',at_time,'statuses',jsonb_build_array('AUTHORITY_AMBIGUOUS'),
      'blocking',true,'certifiedComplete',false,'requiredCohorts','[]'::jsonb,
      'selectionVector','[]'::jsonb,'generationChecks','[]'::jsonb);
  end;
  first_week := date_trunc('week',p_from::timestamp)::date;
  last_week := date_trunc('week',p_to::timestamp)::date;
  for evidence in select value from jsonb_array_elements(domain->'sourceCoverage') loop
    if (evidence->>'count')::integer>1 then cause:='AUTHORITY_AMBIGUOUS';
    elsif (evidence->>'count')::integer=0 then
      if (evidence->>'date')::date<first_week then cause:='PARTIAL_PREVIOUS_COHORT';
      elsif (evidence->>'date')::date>last_week+6 then cause:='PARTIAL_NEXT_COHORT';
      else cause:='MISSING_COHORT'; end if;
    else continue; end if;
    if not cause=any(statuses) then statuses:=array_append(statuses,cause); end if;
  end loop;
  -- Authority discovers missing/new contributors. Existing observed selections
  -- supplement that domain so removal from authority cannot certify stale data.
  for cohort in
    select jsonb_build_object('personKey',x.person_key,'weekStart',x.week_date)
    from (
      select d.value->>'personKey' person_key,(d.value->>'weekStart')::date week_date
        from jsonb_array_elements(domain->'requiredCohorts') d(value)
      union
      select s.person_key,s.employee_payroll_week from public.v_current_labour_window_segments_v3 s
        where s.organization_id=p_org and s.window_operational_date between p_from and p_to
    ) x order by x.week_date,x.person_key
  loop
    week_date := (cohort->>'weekStart')::date;
    select c.* into selection from public.labour_v3_canonical_cohorts c
      where c.organization_id=p_org and c.person_key=cohort->>'personKey'
        and c.payroll_week=week_date and c.enabled;
    if not found then
      cause := case when week_date<first_week then 'PARTIAL_PREVIOUS_COHORT'
        when week_date>last_week then 'PARTIAL_NEXT_COHORT' else 'MISSING_COHORT' end;
      if not cause=any(statuses) then statuses:=array_append(statuses,cause); end if;
      continue;
    end if;
    vector := vector || jsonb_build_array(jsonb_build_object('personKey',selection.person_key,
      'weekStart',selection.payroll_week,'generationId',selection.generation_id,
      'selectionVersion',selection.selection_version));
    if not selection.generation_id=any(checked_ids) then
      begin
        checked := public.labour_v3_check_generation_v1(p_org,selection.generation_id);
        checks := checks||jsonb_build_array(checked||jsonb_build_object('valid',true));
      exception when sqlstate 'P0001' then
        get stacked diagnostics message = message_text;
        -- Only known recertification failures are reported. Unexpected SQL
        -- failures (including ambiguity SQLSTATE 42702) propagate fail-closed.
        if message='AMBIGUOUS_RULES' then cause:='AUTHORITY_AMBIGUOUS';
        elsif message='INCOMPLETE_OR_AMBIGUOUS_ENVELOPE' then
          if 'AUTHORITY_AMBIGUOUS'=any(statuses) then cause:='AUTHORITY_AMBIGUOUS';
          else cause:='STALE_GENERATION'; end if;
        elsif message in ('STALE_GENERATION','INELIGIBLE_GENERATION','MISSING_GENERATION_SEGMENTS',
          'GENERATION_ORGANIZATION_MISMATCH','EMPTY_COHORT_NOT_CERTIFIED') then cause:='STALE_GENERATION';
        else raise; end if;
        if not cause=any(statuses) then statuses:=array_append(statuses,cause); end if;
        checks := checks||jsonb_build_array(jsonb_build_object('generationId',selection.generation_id,
          'valid',false,'failure',message));
      end;
      checked_ids:=array_append(checked_ids,selection.generation_id);
    end if;
  end loop;
  blocking := 'STALE_GENERATION'=any(statuses) or 'AUTHORITY_AMBIGUOUS'=any(statuses);
  if cardinality(statuses)=0 then statuses:=array['CERTIFIED_COMPLETE'];
  else select array_agg(x.status order by x.status) into statuses from unnest(statuses) x(status); end if;
  return jsonb_build_object('contractVersion','LABOUR_V3_WINDOW_CERTIFICATE_V1','organizationId',p_org,
    'from',p_from,'to',p_to,'checkedAt',at_time,'statuses',to_jsonb(statuses),'blocking',blocking,
    'certifiedComplete',statuses=array['CERTIFIED_COMPLETE'],'requiredCohorts',domain->'requiredCohorts',
    'selectionVector',vector,'generationChecks',checks);
end $$;
alter function public.labour_v3_certify_window_v1(uuid,date,date) owner to postgres;
revoke all on function public.labour_v3_certify_window_v1(uuid,date,date) from public,anon,authenticated,service_role;
grant execute on function public.labour_v3_certify_window_v1(uuid,date,date) to service_role;

commit;
