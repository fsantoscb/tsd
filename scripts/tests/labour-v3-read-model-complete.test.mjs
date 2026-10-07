// Disconnected specification oracle. NOT PostgreSQL execution proof.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {resolveProductionShift,DEFAULT_SHIFT_RULES} from '../../packages/shared/src/shift-resolver.ts';
const modulePath=new URL('./fixtures/labour-v3-read-model-oracle.mjs',import.meta.url);
const model=existsSync(modulePath)?await import(modulePath):{};
const full=JSON.parse(readFileSync(new URL('./fixtures/labour-v3-full-segments.json',import.meta.url),'utf8'));
const certificates=JSON.parse(readFileSync(new URL('./fixtures/labour-v3-certificates.json',import.meta.url),'utf8'));
for(const fixture of certificates.cases)test(`certificate contract: ${fixture.name}`,()=>{
  assert.equal(typeof model.certificate,'function');
  const got=model.certificate(fixture.input);
  assert.deepEqual(got,fixture.expected);
  if(got.certifiedComplete)assert.deepEqual(got.statuses,['CERTIFIED_COMPLETE']);
});
test('snapshot contract rejects weak or writable sessions without changing global settings',()=>{
  assert.equal(typeof model.certificate,'function');
  const input=certificates.cases[0].input;
  for(const isolation of ['read committed','read uncommitted'])assert.throws(()=>model.certificate({...input,isolation}),/CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED/);
  assert.throws(()=>model.certificate({...input,readOnly:false}),/CONSISTENT_READ_ONLY_TRANSACTION_REQUIRED/);
  assert.deepEqual(model.certificate({...input,isolation:'serializable'}),certificates.cases[0].expected);
});

test('full 1883 persisted segments project exactly once without changing stored values',()=>{
  assert.equal(typeof model.project,'function');
  const selections=full.generations.flatMap(g=>g.cohorts.map(c=>({...c,generation_id:g.id,selection_version:'1',enabled:true})));
  const result=model.project(full.segments,selections,full.generations);
  assert.equal(full.segments.length,1883);
  for(const rows of [result.shared,result.employee,result.window]){
    assert.equal(rows.length,1883);assert.equal(new Set(rows.map(s=>s.id)).size,1883);
    const byId=new Map(rows.map(s=>[s.id,s]));
    for(const s of full.segments){
      const projected=byId.get(s.id);
      for(const field of ['organization_id','generation_id','source_timesheet_row_id','person_key','area_code','segment_start','segment_end','paid_hours','paid_break_hours','productive_hours','employee_shift_code','employee_operational_date'])assert.equal(projected[field],s[field]);
      if(rows===result.employee){
        assert.equal(projected.payroll_week,s.week_start);assert.equal(projected.regular_hours,s.regular_hours);assert.equal(projected.overtime_hours,s.overtime_hours);
      }else if(rows===result.window){
        assert.equal(projected.employee_payroll_week,s.week_start);assert.equal(projected.employee_regular_hours,s.regular_hours);assert.equal(projected.employee_overtime_hours,s.overtime_hours);
        assert.equal(projected.window_shift_code,s.window_shift_code);assert.equal(projected.window_operational_date,s.window_operational_date);
      }else assert.deepEqual(projected,{...s,selection_version:'1'});
    }
  }
});
test('G1 physical spillover is retained on 28 Sep and is absent from G2 raw membership',()=>{
  assert.equal(typeof model.project,'function');
  const selections=full.generations.flatMap(g=>g.cohorts.map(c=>({...c,generation_id:g.id,selection_version:'1',enabled:true})));
  const rows=model.project(full.segments,selections,full.generations).window;
  const g1='960e2d30-9b65-4c09-9cb4-d79202b0ee13',g2='9d07cf2f-5285-4569-b6e0-6df993a37c83';
  for(const [area,want] of [['INDIRECT',7.215686274509803],['SCREEN_PRINT_CREW',8.210526315789474]]){
    const spill=rows.filter(s=>s.generation_id===g1&&s.window_operational_date==='2026-09-28'&&s.area_code===area);
    assert.ok(spill.length>0);assert.ok(Math.abs(spill.reduce((n,s)=>n+Number(s.productive_hours),0)-want)<1e-9);
    const g2Raws=new Set(rows.filter(s=>s.generation_id===g2).map(s=>s.source_timesheet_row_id));
    assert.ok(spill.every(s=>s.employee_payroll_week==='2026-09-21'&&!g2Raws.has(s.source_timesheet_row_id)));
  }
});
test('28 Sep DTG persisted boundary intervals split at 14:30 and conserve A+B',()=>{
  const rows=full.segments.filter(s=>s.area_code==='DTG_OPERATOR'&&s.window_operational_date==='2026-09-28');
  const sum=code=>rows.filter(s=>s.window_shift_code===code).reduce((n,s)=>n+Number(s.productive_hours),0);
  assert.ok(Math.abs(sum('SHIFT_1')-15.458333333333332)<1e-9);
  assert.ok(Math.abs(sum('SHIFT_2')-16.708333333333332)<1e-9);
  assert.ok(Math.abs(sum('SHIFT_1')+sum('SHIFT_2')-32.166666666666664)<1e-9);
  const boundary=rows.filter(s=>s.source_timesheet_row_id==='b628bdfc-ad79-4ed0-a06e-81bf906d88b3');
  assert.ok(boundary.some(s=>Date.parse(s.segment_start)===Date.parse('2026-09-28T14:00:00+10:00')&&Date.parse(s.segment_end)===Date.parse('2026-09-28T14:30:00+10:00')&&s.window_shift_code==='SHIFT_1'));
  assert.ok(boundary.some(s=>Date.parse(s.segment_start)===Date.parse('2026-09-28T14:30:00+10:00')&&Date.parse(s.segment_end)===Date.parse('2026-09-28T15:00:00+10:00')&&s.window_shift_code==='SHIFT_2'));
});
test('21 Sep observed SCREEN_ROOM A remains diagnostic without manufacturing the missing raw',()=>{
  const rows=full.segments.filter(s=>s.area_code==='SCREEN_ROOM'&&s.window_operational_date==='2026-09-21'&&s.window_shift_code==='SHIFT_1');
  assert.ok(Math.abs(rows.reduce((n,s)=>n+Number(s.productive_hours),0)-7.666666666666666)<1e-9);
  assert.ok(!full.segments.some(s=>s.source_timesheet_row_id==='b62995ef-648d-4ee1-9223-0a3874719ed2'));
});
test('existing calendar resolver preserves cross-midnight C ownership without tolerance',()=>{
  const got=resolveProductionShift(new Date('2026-09-24T02:00:00+10:00'),DEFAULT_SHIFT_RULES,{applyEarlyTolerance:false});
  assert.equal(got.shift,'SHIFT_3');assert.equal(got.operationalDate,'2026-09-23');
  assert.equal(got.usedEarlyTolerance,false);
  assert.ok(full.segments.some(s=>s.employee_shift_code==='SHIFT_3'&&s.calendar_date!==s.employee_operational_date));
});
test('existing Friday calendar boundaries are exact and persisted noon transitions agree',()=>{
  for(const [time,want]of [['06:00','SHIFT_1'],['11:59','SHIFT_1'],['12:00','SHIFT_2'],['17:59','SHIFT_2'],['18:00','SHIFT_3'],['22:59','SHIFT_3'],['23:00','OUT_OF_SHIFT']]){
    assert.equal(resolveProductionShift(new Date(`2026-09-25T${time}:00+10:00`),DEFAULT_SHIFT_RULES,{applyEarlyTolerance:false}).shift,want);
  }
  const noon=full.segments.filter(s=>Date.parse(s.segment_start)===Date.parse('2026-09-25T12:00:00+10:00'));
  assert.ok(noon.length>0);assert.ok(noon.every(s=>s.window_shift_code==='SHIFT_2'));
});
test('Employee headcount is ownership-based, not increased by a physical B spill',()=>{
  const boundary=full.segments.filter(s=>s.source_timesheet_row_id==='b628bdfc-ad79-4ed0-a06e-81bf906d88b3');
  assert.ok(boundary.some(s=>s.window_shift_code==='SHIFT_2'));
  assert.equal(new Set(boundary.filter(s=>s.employee_shift_code==='SHIFT_1').map(s=>s.person_key)).size,1);
  assert.equal(new Set(boundary.filter(s=>s.employee_shift_code==='SHIFT_2').map(s=>s.person_key)).size,0);
});
test('one selection from 24-person manifest does not select the other 23 people',()=>{
  assert.equal(typeof model.project,'function');
  const g=full.generations.find(g=>g.cohorts.length===24),c=g.cohorts.find(c=>c.person_key==='PERSON-007');
  const selection={...c,generation_id:g.id,selection_version:'1',enabled:true};
  const out=model.project(full.segments,[selection],full.generations);
  const expected=full.segments.filter(s=>s.generation_id===g.id&&s.person_key===c.person_key&&s.week_start===c.payroll_week);
  assert.ok(expected.length>0);assert.equal(out.employee.length,expected.length);
  assert.equal(out.window.length,expected.length);assert.ok(out.employee.every(s=>s.person_key===c.person_key));
  assert.deepEqual([...new Set(out.employee.map(s=>s.area_code))].sort(),['SHARED_DISPATCH','UP_OPERATOR']);
  assert.equal(new Set(out.employee.map(s=>s.person_key)).size,1);
});
test('synthetic competing READY cannot be unioned into fully selected G1/G2',()=>{
  const selections=full.generations.flatMap(g=>g.cohorts.map(c=>({...c,generation_id:g.id,selection_version:'1',enabled:true})));
  const competing=full.segments.slice(0,20).map(s=>({...s,id:'ALT-'+s.id,generation_id:'SYNTHETIC-COMPETING-READY'}));
  const out=model.project([...full.segments,...competing],selections,[...full.generations,{id:'SYNTHETIC-COMPETING-READY',status:'READY',validation_complete:true}]);
  assert.equal(out.employee.length,1883);assert.equal(out.window.length,1883);
  assert.ok(out.shared.every(s=>!s.id.startsWith('ALT-')));
});
test('CAS state machine supports create/reselect/tombstone/replace but never wildcard or overflow',()=>{
  assert.equal(typeof model.cas,'function');
  const first=model.cas(null,{generation:'G1',expectedGeneration:null,expectedVersion:'0',enabled:true});
  assert.deepEqual(first,{generation:'G1',version:'1',enabled:true});
  assert.throws(()=>model.cas(first,{generation:'G2',expectedGeneration:null,expectedVersion:'1',enabled:true}),/CAS_CONFLICT/);
  assert.throws(()=>model.cas(first,{generation:'G2',expectedGeneration:'G0',expectedVersion:'1',enabled:true}),/CAS_CONFLICT/);
  assert.throws(()=>model.cas(first,{generation:'G2',expectedGeneration:'G1',expectedVersion:'0',enabled:true}),/CAS_CONFLICT/);
  const same=model.cas(first,{generation:'G1',expectedGeneration:'G1',expectedVersion:'1',enabled:true});
  assert.equal(same.version,'2');
  const tomb=model.cas(same,{generation:'G1',expectedGeneration:'G1',expectedVersion:'2',enabled:false});
  assert.deepEqual(tomb,{generation:'G1',version:'3',enabled:false});
  const restored=model.cas(tomb,{generation:'G2',expectedGeneration:'G1',expectedVersion:'3',enabled:true});
  assert.deepEqual(restored,{generation:'G2',version:'4',enabled:true});
  assert.throws(()=>model.cas({...first,version:'9223372036854775807'},{generation:'G1',expectedGeneration:'G1',expectedVersion:'9223372036854775807',enabled:true}),/SELECTION_VERSION_EXHAUSTED/);
  const winner=model.cas(null,{generation:'G1',expectedGeneration:null,expectedVersion:'0',enabled:true});
  assert.throws(()=>model.cas(winner,{generation:'G2',expectedGeneration:null,expectedVersion:'0',enabled:true}),/CAS_CONFLICT/);
});
