// Supplemental source/security contracts. NOT PostgreSQL execution/concurrency proof.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
const directory = new URL('../../supabase/migrations/', import.meta.url);
const files = readdirSync(directory).filter(x => /^\d{14}_labour_v3_canonical_read_model\.sql$/.test(x));
const sql = files.length === 1 ? readFileSync(new URL(files[0], directory), 'utf8') : '';
const body = name => sql.match(new RegExp(`create function public\\.${name}\\([\\s\\S]*?\\$\\$;`, 'i'))?.[0] ?? '';

test('one new version creates selection without replacing existing objects', () => {
  assert.equal(files.length, 1, 'canonical read-model migration absent');
  assert.ok(files[0].slice(0,14) > '20261007215155');
  assert.match(sql, /create table public\.labour_v3_canonical_cohorts/i);
  assert.doesNotMatch(sql, /create or replace|drop\s+(?:table|view|function)|alter table public\.(?:deputy_|labour_segments\b|labour_segments_v3\b|labour_segment_generations\b)/i);
  assert.doesNotMatch(sql, /update public\.labour_segment_generations|insert into public\.labour_segments_v3/i);
});

test('selection key and generation relationship isolate organization person and week', () => {
  assert.match(sql, /primary key\s*\(organization_id,person_key,payroll_week\)/i);
  assert.match(sql, /foreign key\s*\(organization_id,generation_id\)/i);
  assert.match(sql, /selection_version bigint not null/);
  assert.match(sql, /enabled boolean not null/);
});

test('CAS serializes first insert and preserves tombstone version', () => {
  const fn = body('labour_v3_select_cohort_v1');
  assert.match(fn, /pg_advisory_xact_lock/);
  assert.match(fn, /for update/i);
  assert.match(fn, /IS DISTINCT FROM expected_generation/i);
  assert.match(fn, /IS DISTINCT FROM expected_version/i);
  assert.match(fn, /previous\.selection_version\+1/);
  assert.match(fn, /CAS_CONFLICT/);
  assert.doesNotMatch(fn, /delete from|on conflict.*do update/is);
});

test('enable validates full manifest under bounded source lock and disable does not require freshness', () => {
  const fn = body('labour_v3_select_cohort_v1');
  assert.match(fn, /set lock_timeout = '1s'/i);
  assert.match(fn, /lock table public\.deputy_import_batches,public\.deputy_raw_timesheets,public\.shift_rules in share mode/i);
  assert.match(fn, /if enable_selection then/i);
  assert.match(fn, /labour_v3_check_generation_v1\(org,target_generation\)/);
  const check = body('labour_v3_check_generation_v1');
  assert.match(check, /labour_v3_authority_snapshot_v1\(p_org,g\.cohort_manifest\)/);
  assert.match(check, /labour_v3_validate_segments_v1/);
  assert.match(check, /LABOUR_V3_STAGE2_V1/);
});

test('shared set joins person and payroll week not just generation', () => {
  const view = sql.match(/create view public\.v_canonical_labour_segments_v3[\s\S]*?;/i)?.[0] ?? '';
  assert.match(view, /s\.person_key=c\.person_key/);
  assert.match(view, /s\.week_start=c\.payroll_week/);
  assert.match(view, /s\.organization_id=c\.organization_id/);
  assert.match(view, /g\.status='READY'/);
  assert.doesNotMatch(view, /union|distinct|max\(|helper|snapshot_v1/i);
});

test('Employee and Window views consume identical shared set without authority calls', () => {
  for (const dimension of ['employee','window']) {
    const view = sql.match(new RegExp(`create view public\\.v_current_labour_${dimension}_segments_v3[\\s\\S]*?;`, 'i'))?.[0] ?? '';
    assert.match(view, /from public\.v_canonical_labour_segments_v3/);
    assert.doesNotMatch(view, /where|join|snapshot_v1|certify|calculate|date_trunc/i);
  }
});

test('new mutation paths have explicit internal access and existing helper ACL is untouched', () => {
  assert.match(sql, /enable row level security/i);
  assert.match(sql, /revoke all on public\.labour_v3_canonical_cohorts from public,anon,authenticated,service_role/i);
  assert.match(sql, /grant select on public\.labour_v3_canonical_cohorts to service_role/i);
  assert.match(sql, /grant execute on function public\.labour_v3_select_cohort_v1\(jsonb\) to service_role/i);
  assert.doesNotMatch(sql, /(?:grant|revoke)[^;]*labour_v3_authority_snapshot_v1/i);
  assert.doesNotMatch(sql, /(?:grant|revoke)[^;]*persist_labour_v3_generation_v1/i);
});

test('previous migration bodies remain byte-identical', () => {
  const hashes = {
    '20261007084113_labour_v3_shadow_generations.sql':'895C4FBA929F9BCCDF4252E4F98218BD8B0B8597B983509E8C8FE4D8F64CC56F',
    '20261007105839_labour_v3_shadow_writer_v1.sql':'8007AB9308EE31463146D5F25D3F767E75E1FE9F169161F6BB368EC4D0ECA3CD',
    '20261007215155_labour_v3_shadow_writer_v2.sql':'30C091EBF2ACFCABAD54948196FE3BA95FE8A26ABBD92589BC6B0D31E7ABD926'
  };
  for (const [name,hash] of Object.entries(hashes)) assert.equal(createHash('sha256').update(readFileSync(new URL(name,directory))).digest('hex').toUpperCase(),hash);
});

test('certificate rejects weak isolation and cannot mutate data', () => {
  const fn = body('labour_v3_certify_window_v1');
  assert.match(fn, /transaction_isolation/);
  assert.match(fn, /repeatable read/);
  assert.match(fn, /serializable/);
  assert.match(fn, /transaction_read_only/);
  assert.match(fn, /CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED/);
  assert.doesNotMatch(fn, /\b(?:insert into|update public|delete from|grant|revoke|lock table|persist_labour_v3_generation_v1|set transaction)\b/i);
});

test('contributor discovery uses the existing authority definition not selection-only population', () => {
  const fn = body('labour_v3_window_domain_v1');
  assert.match(fn, /pg_get_viewdef\('public\.v_current_labour_segments'/);
  assert.match(fn, /substring\(prefix from latest_pos\)/);
  assert.match(fn, /canonical_raw c JOIN public\.deputy_raw_timesheets r/);
  assert.match(fn, /labour_v3_owner_v1/);
  assert.doesNotMatch(fn, /labour_v3_canonical_cohorts/);
  assert.match(fn, /PERIOD_OUT_OF_BOUNDS/);
});

test('certificate checks discovered cohorts before selection and preserves blocking precedence', () => {
  const fn = body('labour_v3_certify_window_v1');
  assert.match(fn, /domain->'requiredCohorts'/);
  for (const status of ['STALE_GENERATION','AUTHORITY_AMBIGUOUS','MISSING_COHORT','PARTIAL_PREVIOUS_COHORT','PARTIAL_NEXT_COHORT','CERTIFIED_COMPLETE']) assert.ok(fn.includes(status));
  assert.match(fn, /blocking.*STALE_GENERATION/s);
  assert.match(fn, /blocking.*AUTHORITY_AMBIGUOUS/s);
  assert.match(fn, /labour_v3_check_generation_v1/);
  assert.match(fn, /selectionVersion/);
});

test('removed authoritative contributors cannot leave observed selections unchecked',()=>{
  const fn=body('labour_v3_certify_window_v1');
  assert.match(fn,/union\s+select s\.person_key,s\.employee_payroll_week/i);
  assert.match(fn,/v_current_labour_window_segments_v3 s/);
  assert.match(fn,/s\.window_operational_date between p_from and p_to/);
});

test('domain validates source durations and cuts with the existing windows, not a new engine',()=>{
  const fn=body('labour_v3_window_domain_v1');
  assert.match(fn,/raw_end-raw_start>interval '24 hours'/);
  assert.match(fn,/labour_v3_windows_v1/);
  assert.match(fn,/sourceCoverage/);
  assert.match(fn,/AUTHORITY_DEFINITION_CHANGED/);
  assert.doesNotMatch(fn,/calculateKpis|productive_hours|paid_hours|overtime_hours/);
});

test('unexpected SQL errors propagate rather than become a complete response',()=>{
  const fn=body('labour_v3_certify_window_v1');
  assert.doesNotMatch(fn,/when others/i);
  assert.match(fn,/else raise; end if/);
  assert.match(fn,/cardinality\(statuses\)=0/);
});
