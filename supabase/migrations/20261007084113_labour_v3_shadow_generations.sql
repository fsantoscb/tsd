-- Stage 2 LOCAL DRAFT ONLY. NOT EXECUTION-CERTIFIED. No authority switch/writer.
begin;

create table public.labour_segment_generations (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id),
  generation_version text not null,
  algorithm_version text not null,
  created_at timestamptz not null default now(),
  status text not null default 'BUILDING'
    check (status in ('BUILDING','READY','ACTIVE','SUPERSEDED','FAILED')),
  coverage_start date not null,
  coverage_end date not null,
  source_authority_fingerprint text not null,
  rule_fingerprint text not null,
  cohort_manifest jsonb not null,
  validation_complete boolean not null default false,
  diagnostics jsonb not null default '{}'::jsonb,
  unique (organization_id,id),
  check (coverage_start <= coverage_end),
  check (jsonb_typeof(cohort_manifest) = 'array' and jsonb_array_length(cohort_manifest) > 0),
  check (status not in ('READY','ACTIVE','SUPERSEDED') or validation_complete)
);

create table public.labour_segments_v3 (
  id uuid primary key,
  organization_id uuid not null references public.organizations(id),
  generation_id uuid not null,
  -- Intentionally no raw.id-only FK: tenant membership must be validated
  -- for ALL raws by future transactional writer before any segment insert.
  source_timesheet_row_id uuid not null,
  person_key text not null,
  area_code text not null,
  segment_start timestamptz not null,
  segment_end timestamptz not null,
  calendar_date date not null,
  hour_bucket smallint not null check (hour_bucket between 0 and 23),
  employee_shift_code text not null check (employee_shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT')),
  employee_operational_date date not null,
  window_shift_code text not null check (window_shift_code in ('SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT')),
  window_operational_date date not null,
  scheduled_start_at timestamptz,
  scheduled_end_at timestamptz,
  paid_hours numeric not null check (paid_hours >= 0),
  regular_hours numeric not null check (regular_hours >= 0),
  overtime_hours numeric not null check (overtime_hours >= 0),
  paid_break_hours numeric not null check (paid_break_hours >= 0),
  productive_hours numeric not null check (productive_hours >= 0),
  week_start date not null,
  approval_status text not null check (approval_status in ('APPROVED','PROVISIONAL')),
  allocation_method text not null check (allocation_method = 'PRO_RATA_ELAPSED'),
  calculation_version text not null,
  unique (generation_id,source_timesheet_row_id,segment_start),
  foreign key (organization_id,generation_id) references public.labour_segment_generations(organization_id,id),
  check (segment_start < segment_end),
  check (abs(regular_hours + overtime_hours - paid_hours) <= 0.000000001),
  check (abs(productive_hours + paid_break_hours - paid_hours) <= 0.000000001),
  check ((employee_shift_code = 'OUT_OF_SHIFT' and scheduled_start_at is null and scheduled_end_at is null)
    or (employee_shift_code <> 'OUT_OF_SHIFT' and scheduled_start_at is not null and scheduled_end_at is not null and scheduled_start_at < scheduled_end_at))
);

create index labour_v3_employee_cohort_idx on public.labour_segments_v3
  (organization_id,person_key,week_start,generation_id);
create index labour_v3_window_idx on public.labour_segments_v3
  (organization_id,window_operational_date,window_shift_code,generation_id);
alter table public.labour_segment_generations owner to postgres;
alter table public.labour_segments_v3 owner to postgres;
alter table public.labour_segment_generations enable row level security;
alter table public.labour_segments_v3 enable row level security;
-- Shadow is server-only; no browser role policy or access broadening.
revoke all on public.labour_segment_generations,public.labour_segments_v3 from public,anon,authenticated;
grant all on public.labour_segment_generations,public.labour_segments_v3 to service_role;

comment on table public.labour_segment_generations is
  'Inactive V3 shadow generations. Status/fingerprints alone never certify complete payroll cohorts. Future writer/selection must enforce complete cohort manifest, locked tenant validation and atomic persistence.';
comment on table public.labour_segments_v3 is
  'Inactive separate V3 storage; legacy Labour is unchanged. Raw membership is a mandatory future writer invariant, not certified by an id-only FK.';
commit;
