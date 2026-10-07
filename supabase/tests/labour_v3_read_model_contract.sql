-- psql ONLY; prerequisites and the draft migration must already be installed
-- in an explicitly approved disposable database. Never use Production.
\set ON_ERROR_STOP on
\getenv approved TSD_V3_DISPOSABLE_APPROVED
\getenv expected_database TSD_V3_DISPOSABLE_DATABASE
select set_config('tsd.test_approval', :'approved', false);
select set_config('tsd.test_database', :'expected_database', false);
do $$ begin
  if current_setting('tsd.test_approval')<>'LABOUR_V3_PHASE3A_DISPOSABLE'
    or current_database()<>current_setting('tsd.test_database')
    or current_database() !~ '^tsd_v3_disposable_[a-z0-9_]+$'
    or coalesce(inet_server_addr()::text,'127.0.0.1') not in ('127.0.0.1','::1') then
    raise exception 'DISPOSABLE_DATABASE_REQUIRED';
  end if;
end $$;
begin;
do $$ declare fields text[]; begin
  if exists(select 1 from public.labour_v3_canonical_cohorts) then
    raise exception 'EMPTY_SELECTION_BASELINE_REQUIRED'; end if;
  select array_agg(a.attname::text order by a.attnum) into fields from pg_attribute a
    where a.attrelid='public.v_current_labour_employee_segments_v3'::regclass
      and a.attnum>0 and not a.attisdropped;
  if fields<>array['id','organization_id','generation_id','source_timesheet_row_id','person_key',
    'area_code','segment_start','segment_end','employee_shift_code','employee_operational_date',
    'paid_hours','paid_break_hours','productive_hours','regular_hours','overtime_hours','payroll_week',
    'approval_status','calculation_version','scheduled_start_at','scheduled_end_at','selection_version'] then
    raise exception 'EMPLOYEE_PROJECTION_CONTRACT'; end if;
  select array_agg(a.attname::text order by a.attnum) into fields from pg_attribute a
    where a.attrelid='public.v_current_labour_window_segments_v3'::regclass
      and a.attnum>0 and not a.attisdropped;
  if fields<>array['id','organization_id','generation_id','source_timesheet_row_id','person_key',
    'area_code','segment_start','segment_end','window_shift_code','window_operational_date',
    'employee_shift_code','employee_operational_date','employee_payroll_week','productive_hours',
    'paid_hours','paid_break_hours','employee_regular_hours','employee_overtime_hours',
    'approval_status','calculation_version','selection_version'] then
    raise exception 'WINDOW_PROJECTION_CONTRACT'; end if;
  if has_function_privilege('service_role','public.labour_v3_authority_snapshot_v1(uuid,jsonb)','EXECUTE')
    or has_function_privilege('service_role','public.persist_labour_v3_generation_v1(jsonb)','EXECUTE') then
    raise exception 'OLD_HELPER_ACL_CHANGED'; end if;
  if has_table_privilege('service_role','public.labour_v3_canonical_cohorts','INSERT')
    or has_table_privilege('service_role','public.labour_v3_canonical_cohorts','UPDATE')
    or has_table_privilege('service_role','public.labour_v3_canonical_cohorts','DELETE') then
    raise exception 'DIRECT_SELECTION_DML_ALLOWED'; end if;
  begin
    perform public.labour_v3_certify_window_v1(null,date '2026-09-28',date '2026-09-28');
    raise exception 'WEAK_ISOLATION_ACCEPTED';
  exception when sqlstate 'P0001' then
    if SQLERRM<>'CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED' then raise; end if;
  end;
end $$;
-- Synthetic source fixture, never copied from Production. Build the entire
-- 24-person manifest so full-generation validation cannot accidentally select
-- all people when one cohort is requested.
do $$
declare
  org uuid:=gen_random_uuid(); org_b uuid:=gen_random_uuid(); batch uuid:=gen_random_uuid();
  gid uuid:=gen_random_uuid(); manifest jsonb; authority jsonb; request jsonb; result jsonb;
  baseline_raw bigint; baseline_batch bigint; baseline_legacy bigint; baseline_v3 bigint;
  variant text; before_selection jsonb; rejected boolean;
begin
  insert into public.organizations(id,name) values(org,'DISPOSABLE PHASE3A'),(org_b,'DISPOSABLE FOREIGN');
  insert into public.deputy_import_batches(id,organization_id,filename,source_type,source_timezone,content_hash,status,
    snapshot_type,report_generated_at,coverage_start,coverage_end,certified_at,certified_by)
    values(batch,org,'synthetic.csv','CSV','Australia/Brisbane',batch::text,'COMPLETED',
      'FULL','2026-10-07T09:00:00+10:00','2026-09-20','2026-09-28',now(),'test-only');
  insert into public.shift_rules(organization_id,weekday,shift_code,display_name,start_time,end_time,cross_midnight,effective_from)
    select org,d,s.code,s.code,s.a::time,s.b::time,s.crosses,'2026-01-01' from generate_series(1,7) d
      cross join (values('SHIFT_1','06:00','14:30',false),('SHIFT_2','14:30','23:00',false),('SHIFT_3','23:00','06:00',true)) s(code,a,b,crosses);
  insert into public.deputy_raw_timesheets(id,organization_id,import_batch_id,source_row_key,person_key,display_name,
    timesheet_date,raw_area,normalized_area,start_at,end_at,total_hours,meal_break_hours,approval_status,row_status,raw_data)
    select gen_random_uuid(),org,batch,'row-'||n,'TEST-PERSON-'||lpad(n::text,2,'0'),'Synthetic-'||n,
      '2026-09-21','DTG','DTG_OPERATOR','2026-09-21T06:00:00+10:00','2026-09-21T10:00:00+10:00',
      4,0,'APPROVED','ACCEPTED','{}'::jsonb from generate_series(1,24) n;
  select jsonb_agg(jsonb_build_object('personKey',r.person_key,'weekStart','2026-09-21') order by r.person_key)
    into manifest from public.deputy_raw_timesheets r where r.organization_id=org;
  authority:=public.labour_v3_authority_snapshot_v1(org,manifest);
  insert into public.labour_segment_generations(id,organization_id,generation_version,algorithm_version,status,
    coverage_start,coverage_end,source_authority_fingerprint,rule_fingerprint,cohort_manifest,validation_complete)
    values(gid,org,'LABOUR_V3_SHADOW_V1','LABOUR_V3_STAGE2_V1','READY',
      (authority->>'coverageStart')::date,(authority->>'coverageEnd')::date,
      authority->>'authorityFingerprint',authority->>'ruleFingerprint',authority->'cohorts',true);
  insert into public.labour_segments_v3(id,organization_id,generation_id,source_timesheet_row_id,person_key,area_code,
    segment_start,segment_end,calendar_date,hour_bucket,employee_shift_code,employee_operational_date,
    window_shift_code,window_operational_date,scheduled_start_at,scheduled_end_at,paid_hours,regular_hours,
    overtime_hours,paid_break_hours,productive_hours,week_start,approval_status,allocation_method,calculation_version)
    select gen_random_uuid(),org,gid,r.id,r.person_key,'DTG_OPERATOR',
      r.start_at+make_interval(hours=>h),r.start_at+make_interval(hours=>h+1),'2026-09-21',6+h,
      'SHIFT_1','2026-09-21','SHIFT_1','2026-09-21','2026-09-21T06:00:00+10:00','2026-09-21T14:30:00+10:00',
      1,1,0,1::numeric/12,11::numeric/12,'2026-09-21','APPROVED','PRO_RATA_ELAPSED','LABOUR_V3_STAGE2_V1'
      from public.deputy_raw_timesheets r cross join generate_series(0,3) h where r.organization_id=org;
  select count(*) into baseline_raw from public.deputy_raw_timesheets;
  select count(*) into baseline_batch from public.deputy_import_batches;
  select count(*) into baseline_legacy from public.labour_segments;
  select count(*) into baseline_v3 from public.labour_segments_v3;
  request:=jsonb_build_object('organizationId',org,'personKey','TEST-PERSON-01','payrollWeek','2026-09-21',
    'generationId',gid,'expectedGenerationId',null,'expectedSelectionVersion',0,'enabled',true,
    'actor','synthetic-test','reason','contract');
  foreach variant in array array['wrong-org','FAILED','BUILDING','SUPERSEDED','ACTIVE','invalid-algorithm',
    'stale-fingerprint','invalid-prestate','incomplete-manifest','missing-segments','cross-org-segment','corrupt-productivity'] loop
    rejected:=false;
    begin
      case variant
        when 'wrong-org' then request:=jsonb_set(request,'{organizationId}',to_jsonb(org_b));
        when 'invalid-algorithm' then update public.labour_segment_generations g set algorithm_version='UNAPPROVED' where g.id=gid;
        when 'stale-fingerprint' then update public.labour_segment_generations g set source_authority_fingerprint=repeat('0',64) where g.id=gid;
        when 'invalid-prestate' then request:=jsonb_set(request,'{expectedSelectionVersion}','1');
        when 'incomplete-manifest' then update public.labour_segment_generations g
          set cohort_manifest=jsonb_build_array(jsonb_set(g.cohort_manifest->0,'{complete}','false')) where g.id=gid;
        when 'missing-segments' then delete from public.labour_segments_v3 s where s.generation_id=gid and s.person_key='TEST-PERSON-24';
        when 'cross-org-segment' then update public.labour_segments_v3 s set person_key='NOT-IN-MANIFEST'
          where s.generation_id=gid and s.person_key='TEST-PERSON-24';
        when 'corrupt-productivity' then update public.labour_segments_v3 s set paid_break_hours=0,productive_hours=paid_hours
          where s.generation_id=gid and s.person_key='TEST-PERSON-24';
        else update public.labour_segment_generations g set status=variant where g.id=gid;
      end case;
      perform public.labour_v3_select_cohort_v1(request);
    exception when sqlstate 'P0001' then rejected:=true;
    end;
    if not rejected or exists(select 1 from public.labour_v3_canonical_cohorts c where c.organization_id in (org,org_b)) then
      raise exception 'NEGATIVE_SELECTION_FAILED: %',variant; end if;
    request:=jsonb_set(jsonb_set(request,'{organizationId}',to_jsonb(org)),'{expectedSelectionVersion}','0');
    update public.labour_segment_generations g set status='READY',algorithm_version='LABOUR_V3_STAGE2_V1',
      source_authority_fingerprint=authority->>'authorityFingerprint' where g.id=gid;
  end loop;
  result:=public.labour_v3_select_cohort_v1(request);
  if result->>'selectionVersion'<>'1' or
    (select count(*) from public.labour_v3_canonical_cohorts c where c.organization_id=org)<>1 or
    (select count(*) from public.v_current_labour_employee_segments_v3 s where s.organization_id=org)<>4 or
    (select count(*) from public.v_current_labour_window_segments_v3 s where s.organization_id=org)<>4 then
    raise exception 'MULTIPERSON_SELECTION_LEAK'; end if;
  before_selection:=result;
  begin
    perform public.labour_v3_select_cohort_v1(request);
    raise exception 'STALE_CAS_ACCEPTED';
  exception when sqlstate 'P0001' then if SQLERRM<>'CAS_CONFLICT' then raise; end if; end;
  request:=request||jsonb_build_object('expectedGenerationId',gid,'expectedSelectionVersion',1,'enabled',false);
  result:=public.labour_v3_select_cohort_v1(request);
  if result->>'selectionVersion'<>'2' or exists(select 1 from public.v_current_labour_window_segments_v3 s where s.organization_id=org) then
    raise exception 'TOMBSTONE_FAILED'; end if;
  request:=request||jsonb_build_object('expectedSelectionVersion',2,'enabled',true);
  result:=public.labour_v3_select_cohort_v1(request);
  if result->>'selectionVersion'<>'3' then raise exception 'MONOTONIC_REENABLE_FAILED'; end if;
  if (select count(*) from public.deputy_raw_timesheets)<>baseline_raw or
    (select count(*) from public.deputy_import_batches)<>baseline_batch or
    (select count(*) from public.labour_segments)<>baseline_legacy or
    (select count(*) from public.labour_segments_v3)<>baseline_v3 then raise exception 'SOURCE_MUTATION'; end if;
end $$;
rollback;
begin isolation level repeatable read read only;
do $$ begin
  begin
    perform public.labour_v3_certify_window_v1(null,date '2026-10-02',date '2026-10-01');
    raise exception 'INVALID_PERIOD_ACCEPTED';
  exception when sqlstate 'P0001' then if SQLERRM<>'PERIOD_OUT_OF_BOUNDS' then raise; end if; end;
end $$;
rollback;
-- NOT EXECUTION-CERTIFIED until this script actually runs. Still does not
-- certify populated certificate/snapshot race cases; provision those separately.
